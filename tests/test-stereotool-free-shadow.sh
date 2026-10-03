#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'set +e; [[ -n "${ROUTER_PID:-}" ]] && kill "$ROUTER_PID" 2>/dev/null; [[ -n "${WORKER_PID:-}" ]] && kill "$WORKER_PID" 2>/dev/null; [[ -n "${SINK_PID:-}" ]] && kill "$SINK_PID" 2>/dev/null; rm -rf "$TMP"' EXIT

python3 -m py_compile "$ROOT/experimental/stereotool/shadow_router.py" "$ROOT/experimental/stereotool/free_shadow_worker.py"

gcc -shared -fPIC -x c -o "$TMP/libStereoTool_mock.so" - <<'C'
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
typedef struct { int x; } gStereoTool;
void stereoTool_EnableInternalSoundCard(bool enabled) { (void)enabled; }
int stereoTool_GetSoftwareVersion(void) { return 11050; }
int stereoTool_GetApiVersion(void) { return 256; }
gStereoTool* stereoTool_Create3(bool gui, const char* key, const char* name, const char* home, bool load) {
  (void)gui; (void)key; (void)name; (void)home; (void)load; return calloc(1,sizeof(gStereoTool));
}
void stereoTool_Delete(gStereoTool* s) { free(s); }
bool stereoTool_SetStsValue(gStereoTool* s, int idx, int sub, const char* value) {
  (void)s; (void)idx; (void)sub; (void)value; return true;
}
void stereoTool_Process(gStereoTool* s, float* x, int32_t n, int32_t c, int32_t sr) {
  (void)s; (void)c; (void)sr; for (int32_t i=0;i<n;i++) x[i] *= 0.5f;
}
bool stereoTool_GetUnlicensedUsedFeatures(gStereoTool* s, char* text, int maxlen) {
  (void)s; if (maxlen>0) text[0]='\0'; return true;
}
bool stereoTool_CheckLicenseValid(gStereoTool* s) { (void)s; return true; }
int stereoTool_GetLatency2(gStereoTool* s, int32_t sr, bool silence) { (void)s; (void)sr; (void)silence; return 4096; }
C
SHA="$(sha256sum "$TMP/libStereoTool_mock.so" | awk '{print $1}')"

cat >"$TMP/sink.py" <<'PY'
import pathlib,socket,sys
p=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2])
try:p.unlink()
except FileNotFoundError:pass
s=socket.socket(socket.AF_UNIX,socket.SOCK_DGRAM);s.bind(str(p))
with out.open('wb') as f:
    for _ in range(2):
        d=s.recv(4096); f.write(len(d).to_bytes(4,'little')); f.write(d); f.flush()
PY
python3 "$TMP/sink.py" "$TMP/helix.sock" "$TMP/helix.bin" & SINK_PID=$!

python3 "$ROOT/experimental/stereotool/free_shadow_worker.py" \
  --socket "$TMP/st.sock" --lib "$TMP/libStereoTool_mock.so" --sha256 "$SHA" \
  --max-contexts 1 --stats-interval 10 >"$TMP/worker.log" 2>&1 & WORKER_PID=$!

python3 "$ROOT/experimental/stereotool/shadow_router.py" \
  --input "$TMP/input.sock" --target "$TMP/helix.sock" --target "$TMP/st.sock" \
  --stats-interval 10 >"$TMP/router.log" 2>&1 & ROUTER_PID=$!

for _ in $(seq 1 100); do
  [[ -S "$TMP/input.sock" && -S "$TMP/st.sock" && -S "$TMP/helix.sock" ]] && break
  sleep 0.02
done
[[ -S "$TMP/input.sock" && -S "$TMP/st.sock" && -S "$TMP/helix.sock" ]]

python3 - "$TMP/input.sock" <<'PY'
import socket,struct,sys,time
p=sys.argv[1]
def pkt(stream,reset,amp):
    n=160; flags=0x01|(0x02 if reset else 0)
    h=b'HXP1'+bytes([1,flags])+struct.pack('<HIIQ',n,stream,8000,0)
    pcm=struct.pack('<160h',*([amp]*160))
    return h+pcm
s=socket.socket(socket.AF_UNIX,socket.SOCK_DGRAM)
s.sendto(pkt(7,True,1200),p)
time.sleep(.2)
PY

for _ in $(seq 1 100); do
  grep -q '"event": "free_gate_pass"' "$TMP/worker.log" && break
  sleep 0.02
done
grep -q '"event": "free_gate_pass"' "$TMP/worker.log"

# Native DSP observer can disappear and Helix forwarding must still work.
kill "$WORKER_PID"; wait "$WORKER_PID" 2>/dev/null || true; WORKER_PID=""
python3 - "$TMP/input.sock" <<'PY'
import socket,struct,sys
p=sys.argv[1];n=160
h=b'HXP1'+bytes([1,1])+struct.pack('<HIIQ',n,7,8000,160)
pcm=struct.pack('<160h',*([900]*160))
s=socket.socket(socket.AF_UNIX,socket.SOCK_DGRAM);s.sendto(h+pcm,p)
PY

wait "$SINK_PID"; SINK_PID=""
python3 - "$TMP/helix.bin" <<'PY'
import pathlib,sys
b=pathlib.Path(sys.argv[1]).read_bytes();off=0;count=0
while off<len(b):
    n=int.from_bytes(b[off:off+4],'little');off+=4
    d=b[off:off+n];off+=n
    assert d[:4]==b'HXP1' and len(d)==344
    count+=1
assert count==2,count
print('helix_forwarded_packets=2')
PY

echo "stereotool_free_shadow_fail_open=PASS"
