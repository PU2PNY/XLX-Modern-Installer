#include "adapter.hpp"
#include "helix_pcm_client.hpp"

#include <arpa/inet.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
#include <vector>

#include "mbelib.h"
#include "ambe.h"
#include "p25p2_vf.h"
#include "imbe_vocoder/imbe_vocoder.h"
#include "ambe_encoder.h"
#include "software_imbe_decoder.h"
#include <cmath>
#include <cstdlib>
#include <string>

namespace {

constexpr uint8_t CODEC_DSTAR = 1;
constexpr uint8_t CODEC_AMBE2 = 2;

constexpr uint16_t CONTROL_PORT = 10100;
constexpr uint16_t STREAM_FIRST = 10101;
constexpr uint16_t STREAM_LAST  = 10199;
constexpr size_t MAX_STREAMS = 4;
constexpr int NSAMP = 160;

using xuv::XlxVoice9;
using xuv::Bits72;
using xuv::Dibits36;

enum class HelixMode {
    Off,
    Shadow,
    Process,
};

HelixMode helix_mode_from_env() {
    const char* value = std::getenv("XLX_HELIX_MODE");
    if (!value || !*value || std::strcmp(value, "off") == 0)
        return HelixMode::Off;
    if (std::strcmp(value, "shadow") == 0)
        return HelixMode::Shadow;
    if (std::strcmp(value, "process") == 0)
        return HelixMode::Process;
    return HelixMode::Off;
}

const char* helix_mode_name(HelixMode mode) {
    switch (mode) {
        case HelixMode::Shadow: return "shadow";
        case HelixMode::Process: return "process";
        default: return "off";
    }
}

std::string helix_socket_from_env() {
    const char* value = std::getenv("XLX_HELIX_SOCKET");
    if (value && *value)
        return value;
    return "/run/helix-voice/pcm.sock";
}

std::string helix_observe_socket_from_env() {
    const char* value = std::getenv("XLX_HELIX_OBSERVE_SOCKET");
    if (value && *value)
        return value;
    return "/run/helix-voice/observe.sock";
}

int helix_timeout_from_env() {
    const char* value = std::getenv("XLX_HELIX_TIMEOUT_MS");
    if (!value || !*value)
        return 10;
    const int parsed = std::atoi(value);
    if (parsed < 1) return 1;
    if (parsed > 10) return 10;
    return parsed;
}

xuv::HelixPcmClient* shared_helix_client() {
    static std::unique_ptr<xuv::HelixPcmClient> client;
    static bool initialized = false;
    if (!initialized) {
        initialized = true;
        if (helix_mode_from_env() == HelixMode::Process) {
            client = std::make_unique<xuv::HelixPcmClient>(
                helix_socket_from_env(), helix_timeout_from_env());
            (void)client->prime();
        }
    }
    return client.get();
}

xuv::HelixPcmObserver* shared_helix_observer() {
    static std::unique_ptr<xuv::HelixPcmObserver> observer;
    static bool initialized = false;
    if (!initialized) {
        initialized = true;
        if (helix_mode_from_env() == HelixMode::Shadow) {
            observer = std::make_unique<xuv::HelixPcmObserver>(
                helix_observe_socket_from_env());
        }
    }
    return observer.get();
}

uint16_t read_le16(const uint8_t* p) {
    return static_cast<uint16_t>(p[0]) |
           (static_cast<uint16_t>(p[1]) << 8);
}

void write_le16(uint8_t* p, uint16_t v) {
    p[0] = static_cast<uint8_t>(v & 0xff);
    p[1] = static_cast<uint8_t>((v >> 8) & 0xff);
}

int bind_loopback(uint16_t port) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return -1;

    sockaddr_in sa{};
    sa.sin_family = AF_INET;
    sa.sin_port = htons(port);
    inet_pton(AF_INET, "127.0.0.1", &sa.sin_addr);

    if (bind(fd, reinterpret_cast<sockaddr*>(&sa), sizeof(sa)) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

struct DecodeState {
    p25p2_vf interleaver;
    software_imbe_decoder decoder;
    mbe_parms cur{}, prev{}, enh{};
    mbe_errs errs{};

    // XUV Unified Voice V3 — telemetria AMBE+2 / PLC
    uint64_t ambe2_frames = 0;
    uint64_t ambe2_bad_frames = 0;
    uint64_t ambe2_concealed = 0;
    uint64_t ambe2_muted = 0;
    uint64_t ambe2_fec_error_sum = 0;
    size_t ambe2_fec_error_max = 0;
    double ambe2_er_max = 0.0;
    int ambe2_repeat_count = 0;

    DecodeState() {
        mbe_initMbeParms(&cur, &prev, &enh);
        mbe_initErrParms(&errs);
    }

    std::array<int16_t, NSAMP> synth() {
        int K = 12;
        if (cur.L <= 36)
            K = static_cast<int>((static_cast<float>(cur.L) + 2.0f) / 3.0f);

        decoder.decode_tap(cur.L, K, cur.w0, &cur.Vl[1], &cur.Ml[1]);
        audio_samples* samples = decoder.audio();

        std::array<int16_t, NSAMP> pcm{};
        for (int i=0; i<NSAMP; ++i) {
            if (samples && !samples->empty()) {
                pcm[i] = static_cast<int16_t>(samples->front());
                samples->pop_front();
            }
        }
        if (samples) samples->clear();

        mbe_moveMbeParms(&cur, &prev);
        mbe_moveMbeParms(&cur, &enh);
        return pcm;
    }

    bool dstar(const XlxVoice9& raw, std::array<int16_t,NSAMP>& pcm) {
        Bits72 bits = xuv::dstar_bytes_to_bits(raw);
        std::array<uint8_t,72> cw{};
        std::copy(bits.begin(), bits.end(), cw.begin());

        int b[9]{};
        interleaver.decode_dstar(cw.data(), b, true);
        if (b[0] >= 120) return false;
        if (mbe_dequantizeAmbe2400Parms(&cur, &prev, &errs, b) != 0)
            return false;

        pcm = synth();
        return true;
    }

    bool ambe2(const XlxVoice9& raw, std::array<int16_t,NSAMP>& pcm) {
        Dibits36 d = xuv::ambe2_bytes_to_dibits(raw);
        int b[9]{};
        int u[4]{};

        const size_t fec_errors =
            interleaver.process_vcw(&errs, d.data(), b, u);

        ++ambe2_frames;
        ambe2_fec_error_sum += static_cast<uint64_t>(fec_errors);
        ambe2_fec_error_max = std::max(ambe2_fec_error_max, fec_errors);
        ambe2_er_max = std::max(ambe2_er_max, errs.ER);

        // Decodifica os parâmetros, mas NÃO deixa um frame ruim
        // contaminar diretamente a síntese.
        const int rc =
            mbe_dequantizeAmbe2250Parms(&cur, &prev, &errs, b);

        // mbelib usa mais de 3 erros como limite prático de frame ruim.
        // OP25 também impede síntese quando ER > 0.096.
        const bool bad =
            (rc != 0) ||
            (fec_errors > 4) ||
            (errs.ER > 0.096);

        if (bad) {
            ++ambe2_bad_frames;

            // PLC: reaproveita o último conjunto de parâmetros BOM por,
            // no máximo, três frames consecutivos (60 ms).
            if (++ambe2_repeat_count <= 3) {
                mbe_useLastMbeParms(&cur, &prev);
                ++ambe2_concealed;
                pcm = synth();
                return true;
            }

            // Depois de três repetições, silêncio é preferível a ruído
            // de modem / voz destruída.
            ++ambe2_muted;
            pcm.fill(0);
            return true;
        }

        ambe2_repeat_count = 0;
        pcm = synth();
        return true;
    }
};

struct Stream {
    uint16_t id;
    uint16_t port;
    uint8_t in_codec;
    uint8_t out_codec;
    char module;
    int fd;
    DecodeState dec;
    ambe_encoder enc;
    uint64_t packets = 0;
    uint64_t failures = 0;

    HelixMode helix_mode = helix_mode_from_env();
    xuv::HelixPcmClient* helix = nullptr;
    xuv::HelixPcmObserver* helix_observer = nullptr;
    bool helix_reset = true;
    uint64_t helix_timestamp = 0;
    uint64_t helix_ok = 0;
    uint64_t helix_fallback = 0;\n    bool helix_disabled_for_stream = false;

    // Estado do filtro DMR -> D-STAR (8 kHz)
    double hp_x1 = 0.0;
    double hp_y1 = 0.0;
    double lp_y1 = 0.0;

    Stream(uint16_t sid, uint16_t sport, uint8_t in, uint8_t out, int sock, char mod)
        : id(sid), port(sport), in_codec(in), out_codec(out), module(mod), fd(sock) {
        if (helix_mode == HelixMode::Shadow) {
            helix_observer = shared_helix_observer();
        } else if (helix_mode == HelixMode::Process) {
            helix = shared_helix_client();
        }
        if (out_codec == CODEC_DSTAR) {
            enc.set_dstar_mode();
            enc.set_alt_dstar_interleave(true);

            // OP25 d2460 usa 7 dB de atenuação interna no encoder D-STAR.
            // No C usamos a calibração do próprio encoder em vez de
            // destruir nível PCM antes da análise de pitch/harmônicos.
            if (module == 'C') {
                enc.set_gain_adjust(1.0f);
            }
        }
    }

    ~Stream() {
        if (fd >= 0) close(fd);
    }

    bool process(const uint8_t in9[9], uint8_t out9[9]) {
        XlxVoice9 raw{};
        std::copy(in9, in9+9, raw.begin());

        std::array<int16_t,NSAMP> pcm{};
        bool ok = false;

        if (in_codec == CODEC_DSTAR && out_codec == CODEC_AMBE2)
            ok = dec.dstar(raw, pcm);
        else if (in_codec == CODEC_AMBE2 && out_codec == CODEC_DSTAR)
            ok = dec.ambe2(raw, pcm);
        else
            return false;

        if (!ok) {
            ++failures;
            pcm.fill(0);
        }

        // Helix V1 integration.
        // Shadow is one-way/non-blocking and can never replace legacy PCM.
        // Process is request/reply and commits only after a complete response.
        bool helix_attempted = false;
        bool helix_success = false;
        if (helix_observer) {
            helix_attempted = true;
            helix_success = helix_observer->observe(
                id,
                8000,
                helix_timestamp,
                pcm.data(),
                pcm.size(),
                helix_reset,
                true
            );
        } else if (helix && !helix_disabled_for_stream) {
            helix_attempted = true;
            helix_success = helix->process(
                id,
                8000,
                helix_timestamp,
                pcm.data(),
                pcm.size(),
                helix_reset,
                true,
                true
            );
        }

        if (helix_attempted) {
            helix_timestamp += pcm.size();
            if (helix_success) {
                ++helix_ok;
                helix_reset = false;
            } else {
                ++helix_fallback;
                helix_reset = true;
                if (helix_mode == HelixMode::Process)
                    helix_disabled_for_stream = true;
            }
        }

        // XLX026_C_DMR_TO_DSTAR_PREEMPH_V4
        // Somente DMR/YSF (AMBE2) para saída D-STAR no módulo C.
        // Ganho PCM moderado (+~4 dB) e pré-ênfase suave para dar clareza,
        // sem alterar D-STAR -> DMR/YSF e sem tocar no gate.
        if (module == 'C' &&
            in_codec == CODEC_AMBE2 &&
            out_codec == CODEC_DSTAR) {
            // V3: voz mais clara para D-STAR.
            // Corte reforçado do médio-grave e maior presença de agudos.
            // V4: presença reforçada para DMR/YSF chegando ao D-STAR.
            // Reduz médio-grave e privilegia consoantes/agudos.
            constexpr double HP_ALPHA = 0.68;
            constexpr double BASE_GAIN = 1.00;
            constexpr double TREBLE_MIX = 1.80;
            constexpr double LOW_MID_CUT = 0.65;

            for (auto& sample : pcm) {
                const double x = static_cast<double>(sample);
                const double hi = HP_ALPHA * (hp_y1 + x - hp_x1);
                hp_x1 = x;
                hp_y1 = hi;

                const double low_mid = x - hi;
                double y = BASE_GAIN * (x - (LOW_MID_CUT * low_mid))
                         + (TREBLE_MIX * hi);
                if (y > 32767.0) y = 32767.0;
                if (y < -32768.0) y = -32768.0;
                sample = static_cast<int16_t>(y);
            }
        }

        // XLX Unified Voice - limpeza DMR -> D-STAR V4
        // No módulo C experimental este filtro fica DESATIVADO.
        // A e demais módulos preservam exatamente o comportamento anterior.
        if (module != 'C' &&
            in_codec == CODEC_AMBE2 &&
            out_codec == CODEC_DSTAR) {
            constexpr double HP_ALPHA = 0.8093; // ~300 Hz @ 8 kHz
            constexpr double LP_ALPHA = 0.7020; // ~3000 Hz @ 8 kHz

            for (auto& sample : pcm) {
                const double x = static_cast<double>(sample);
                const double hp = HP_ALPHA * (hp_y1 + x - hp_x1);
                hp_x1 = x;
                hp_y1 = hp;

                const double lp = lp_y1 + LP_ALPHA * (hp - lp_y1);
                lp_y1 = lp;

                double y = lp;
                if (y > 32767.0) y = 32767.0;
                if (y < -32768.0) y = -32768.0;
                sample = static_cast<int16_t>(y);
            }

            int64_t sumsq_clean = 0;
            for (const auto sample : pcm) {
                const int32_t v = static_cast<int32_t>(sample);
                sumsq_clean += static_cast<int64_t>(v) * static_cast<int64_t>(v);
            }

            const double rms_clean = std::sqrt(
                static_cast<double>(sumsq_clean) /
                static_cast<double>(pcm.size())
            );

            double expander_gain = 1.0;
            if (rms_clean < 50.0) {
                expander_gain = 0.40;
            } else if (rms_clean < 200.0) {
                expander_gain = 0.40 +
                    ((rms_clean - 50.0) / 150.0) * 0.60;
            }

            if (expander_gain < 1.0) {
                for (auto& sample : pcm) {
                    sample = static_cast<int16_t>(
                        static_cast<double>(sample) * expander_gain
                    );
                }
            }
        }

        // XLX Unified Voice - audio assimetrico V2
        // D-STAR -> DMR    : /64 = 1.5625% (~ -36.12 dB)
        // DMR    -> D-STAR : /32 = 3.125%  (~ -30.10 dB)
        // Aplicado depois do decode PCM e antes do encoder.
        int divisor_pcm = 64;

        // Módulo C experimental: não entregar voz a -30/-36 dBFS
        // ao encoder de destino. /8 mantém margem sem esmagar inteligibilidade.
        if (module == 'C' && out_codec == CODEC_DSTAR) {
            // Sem atenuação PCM externa.
            // O encoder D-STAR já recebeu set_gain_adjust(7.0f).
            divisor_pcm = 8;
        } else if (module == 'C') {
            // Sentido D-STAR -> DMR/YSF permanece exatamente como na V3.
            divisor_pcm = 8;
        } else if (in_codec == CODEC_AMBE2 && out_codec == CODEC_DSTAR) {
            divisor_pcm = 32;
        }

        double lp_dstar = 0.0;
        for (auto& sample : pcm) {
            int32_t scaled = static_cast<int32_t>(sample) / divisor_pcm;
            if (module == 'C' &&
                in_codec == CODEC_DSTAR &&
                out_codec == CODEC_AMBE2) {
                // Filtro Passa-Baixa: corta agudos e chiados
                // Ganho reduzido para 1.2 (evita clipping)
                double x = static_cast<double>(scaled) * 1.0;
                lp_dstar = lp_dstar + 0.45 * (x - lp_dstar);
                scaled = static_cast<int32_t>(lp_dstar);
            }
            if (scaled > 32767) scaled = 32767;
            if (scaled < -32768) scaled = -32768;
            sample = static_cast<int16_t>(scaled);
        }

        if (out_codec == CODEC_DSTAR) {
            std::array<uint8_t,72> bits{};
            enc.encode(pcm.data(), bits.data());

            Bits72 b{};
            std::copy(bits.begin(), bits.end(), b.begin());
            auto packed = xuv::dstar_bits_to_bytes(b);
            std::copy(packed.begin(), packed.end(), out9);
        } else {
            std::array<uint8_t,72> rawdibits{};
            enc.encode(pcm.data(), rawdibits.data());

            Dibits36 d{};
            for (size_t i=0; i<36; ++i) d[i] = rawdibits[i];

            auto packed = xuv::ambe2_dibits_to_bytes(d);
            std::copy(packed.begin(), packed.end(), out9);
        }

        ++packets;
        return true;
    }
};

std::map<uint16_t,std::unique_ptr<Stream>> streams;
uint16_t next_id = 1;

uint16_t alloc_port() {
    for (uint16_t p=STREAM_FIRST; p<=STREAM_LAST; ++p) {
        bool used=false;
        for (const auto& kv: streams)
            if (kv.second->port == p) used=true;
        if (used) continue;

        int fd = bind_loopback(p);
        if (fd >= 0) {
            close(fd);
            return p;
        }
    }
    return 0;
}

void send_busy(int fd, const sockaddr_in& peer, socklen_t len) {
    static const uint8_t busy[] =
        {'A','M','B','E','D','B','U','S','Y'};
    sendto(fd, busy, sizeof(busy), 0,
           reinterpret_cast<const sockaddr*>(&peer), len);
}

} // namespace

int main() {
    int ctl = bind_loopback(CONTROL_PORT);
    if (ctl < 0) {
        std::cerr << "[ERRO] bind 127.0.0.1:10100: "
                  << strerror(errno) << "\n";
        return 2;
    }

    std::cout.setf(std::ios::unitbuf);
    std::cout << "[OK] XLX Unified Voice 127.0.0.1:10100\n";
    std::cout << "[OK] limite de streams: " << MAX_STREAMS << "\n";

    for (;;) {
        std::vector<pollfd> pfds;
        std::vector<uint16_t> ids;

        pfds.push_back({ctl,POLLIN,0});
        ids.push_back(0);

        for (const auto& kv: streams) {
            pfds.push_back({kv.second->fd,POLLIN,0});
            ids.push_back(kv.first);
        }

        int pr = poll(pfds.data(), pfds.size(), 1000);
        if (pr < 0) {
            if (errno == EINTR) continue;
            return 3;
        }
        if (pr == 0) continue;

        for (size_t i=0; i<pfds.size(); ++i) {
            if (!(pfds[i].revents & POLLIN)) continue;

            if (ids[i] == 0) {
                uint8_t buf[256]{};
                sockaddr_in peer{};
                socklen_t len=sizeof(peer);
                ssize_t n=recvfrom(ctl,buf,sizeof(buf),0,
                                   reinterpret_cast<sockaddr*>(&peer),&len);
                if (n <= 0) continue;

                if (n >= 9 && memcmp(buf,"AMBEDPING",9)==0) {
                    static const uint8_t pong[] =
                        {'A','M','B','E','D','P','O','N','G'};
                    sendto(ctl,pong,sizeof(pong),0,
                           reinterpret_cast<sockaddr*>(&peer),len);
                    continue;
                }

                if ((n == 17 || n == 18) && memcmp(buf,"AMBEDOS",7)==0) {
                    uint8_t in=buf[15], out=buf[16];
                    char module = (n == 18) ? static_cast<char>(buf[17]) : '?';

                    bool valid =
                        (in==CODEC_DSTAR && out==CODEC_AMBE2) ||
                        (in==CODEC_AMBE2 && out==CODEC_DSTAR);

                    if (!valid || streams.size() >= MAX_STREAMS) {
                        send_busy(ctl,peer,len);
                        continue;
                    }

                    uint16_t port=alloc_port();
                    if (!port) {
                        send_busy(ctl,peer,len);
                        continue;
                    }

                    int sfd=bind_loopback(port);
                    if (sfd < 0) {
                        send_busy(ctl,peer,len);
                        continue;
                    }

                    uint16_t id=next_id++;
                    if (next_id==0) next_id=1;

                    auto s=std::make_unique<Stream>(id,port,in,out,sfd,module);

                    uint8_t resp[14]={
                        'A','M','B','E','D','S','T','D',
                        0,0,0,0,0,0
                    };
                    write_le16(&resp[8],id);
                    write_le16(&resp[10],port);
                    resp[12]=in;
                    resp[13]=out;

                    streams[id]=std::move(s);

                    sendto(ctl,resp,sizeof(resp),0,
                           reinterpret_cast<sockaddr*>(&peer),len);

                    std::cout << "[OK] OPEN stream=" << id
                              << " port=" << port
                              << " codec=" << unsigned(in)
                              << "->" << unsigned(out)
                              << " module=" << module
                              << " cleanC=" << ((module == 'C') ? "ON" : "OFF")
                              << " helix=" << helix_mode_name(streams[id]->helix_mode)
                              << "\n";
                    continue;
                }

                if (n == 9 && memcmp(buf,"AMBEDCS",7)==0) {
                    uint16_t id=read_le16(&buf[7]);
                    auto it=streams.find(id);
                    if (it != streams.end()) {
                        std::cout << "[OK] CLOSE stream=" << id
                                  << " frames=" << it->second->packets
                                  << " failures=" << it->second->failures
                                  << " module=" << it->second->module
                                  << " ambe2_frames=" << it->second->dec.ambe2_frames
                                  << " bad=" << it->second->dec.ambe2_bad_frames
                                  << " concealed=" << it->second->dec.ambe2_concealed
                                  << " muted=" << it->second->dec.ambe2_muted
                                  << " fec_sum=" << it->second->dec.ambe2_fec_error_sum
                                  << " fec_max=" << it->second->dec.ambe2_fec_error_max
                                  << " er_max=" << it->second->dec.ambe2_er_max
                                  << " helix=" << helix_mode_name(it->second->helix_mode)
                                  << " helix_ok=" << it->second->helix_ok
                                  << " helix_fallback=" << it->second->helix_fallback
                                  << " helix_stream_disabled=" << (it->second->helix_disabled_for_stream ? 1 : 0)
                                  << "\n";
                        streams.erase(it);
                    }
                    continue;
                }
            } else {
                auto it=streams.find(ids[i]);
                if (it == streams.end()) continue;

                Stream& s=*it->second;

                uint8_t buf[64]{};
                sockaddr_in peer{};
                socklen_t len=sizeof(peer);

                ssize_t n=recvfrom(s.fd,buf,sizeof(buf),0,
                                   reinterpret_cast<sockaddr*>(&peer),&len);
                if (n != 11 || buf[0] != s.in_codec)
                    continue;

                uint8_t out[11]{};
                out[0]=s.out_codec;
                out[1]=buf[1];

                if (!s.process(&buf[2],&out[2]))
                    continue;

                sendto(s.fd,out,sizeof(out),0,
                       reinterpret_cast<sockaddr*>(&peer),len);
            }
        }
    }
}
