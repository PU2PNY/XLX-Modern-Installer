#include "adapter.hpp"
#include <stdexcept>

namespace xuv {

Bits72 dstar_bytes_to_bits(const XlxVoice9& in) {
    Bits72 out{};
    std::size_t k = 0;
    for (std::uint8_t byte : in) {
        for (int shift = 7; shift >= 0; --shift)
            out[k++] = (byte >> shift) & 0x01;
    }
    return out;
}

XlxVoice9 dstar_bits_to_bytes(const Bits72& in) {
    XlxVoice9 out{};
    std::size_t k = 0;
    for (std::size_t b = 0; b < out.size(); ++b) {
        std::uint8_t v = 0;
        for (int shift = 7; shift >= 0; --shift) {
            if (in[k] > 1) throw std::runtime_error("bit D-STAR inválido");
            v |= static_cast<std::uint8_t>(in[k++] << shift);
        }
        out[b] = v;
    }
    return out;
}

Dibits36 ambe2_bytes_to_dibits(const XlxVoice9& in) {
    Dibits36 out{};
    std::size_t k = 0;
    for (std::uint8_t byte : in) {
        out[k++] = (byte >> 6) & 0x03;
        out[k++] = (byte >> 4) & 0x03;
        out[k++] = (byte >> 2) & 0x03;
        out[k++] = byte & 0x03;
    }
    return out;
}

XlxVoice9 ambe2_dibits_to_bytes(const Dibits36& in) {
    XlxVoice9 out{};
    std::size_t k = 0;
    for (std::size_t b = 0; b < out.size(); ++b) {
        for (int part = 0; part < 4; ++part) {
            if (in[k] > 3) throw std::runtime_error("dibit AMBE+2 inválido");
            out[b] |= static_cast<std::uint8_t>(in[k++] << (6 - part * 2));
        }
    }
    return out;
}

} // namespace xuv
