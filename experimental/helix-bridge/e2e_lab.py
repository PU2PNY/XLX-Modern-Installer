#!/usr/bin/env python3
"""ENV-only bridge E2E. Requires externally built xuvd/Helix/corpus client."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import socket
import struct
import subprocess
import time

def stop(p):
    if p is not None:
        if p.poll() is None:
            p.terminate()
        try:
            p.wait(timeout=3)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait(timeout=3)

def ready_socket(p, path):
    for _ in range(200):
        if path.exists():
            return
        if p.poll() is not None:
            raise RuntimeError("Helix exited before socket was ready")
        time.sleep(.01)
    raise RuntimeError("Helix socket readiness timeout")

def stats(pid):
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1].split()
        ticks = int(fields[11]) + int(fields[12])
        rss = int(fields[21]) * os.sysconf("SC_PAGE_SIZE") / 1024
        return ticks, rss
    except FileNotFoundError:
        return 0, 0

def pct(xs, q):
    return sorted(xs)[max(0, math.ceil(len(xs)*q)-1)]

def run_case(args, tag, mode, helix_mode=None, streams=1, kill_at=None):
    work = args.output
    sock = work / (tag + ".sock")
    hx = xv = client = None
    handles = []
    try:
        env = dict(os.environ, XLX_HELIX_MODE=mode, XLX_HELIX_TIMEOUT_MS="5",
                   XLX_HELIX_SOCKET=str(sock), XLX_HELIX_OBSERVE_SOCKET=str(sock))
        if helix_mode:
            hlog = open(work / (tag + ".helix.log"), "w")
            handles.append(hlog)
            hx = subprocess.Popen([str(args.helix), helix_mode, str(sock)],
                                  stdout=hlog, stderr=subprocess.STDOUT)
            ready_socket(hx, sock)
        xlog = open(work / (tag + ".xuvd.log"), "w")
        handles.append(xlog)
        xv = subprocess.Popen([str(args.xuvd)], env=env,
                              stdout=xlog, stderr=subprocess.STDOUT)
        # Starting a lab instance must not steal an existing listener.
        for _ in range(200):
            ports = subprocess.check_output(["ss", "-lun"], text=True)
            if re.search(r"127\.0\.0\.1:10100\b", ports):
                break
            if xv.poll() is not None:
                raise RuntimeError("xuvd exited before readiness")
            time.sleep(.01)
        else:
            raise RuntimeError("xuvd port readiness timeout")
        started = time.monotonic()
        xb, _ = stats(xv.pid)
        hb, _ = stats(hx.pid) if hx else (0, 0)
        rss_x = rss_h = 0
        latencies = []
        with open(work / (tag + ".bin"), "wb") as output:
            client = subprocess.Popen([str(args.client), str(streams), "40", "20"],
                                      stdout=output, stderr=subprocess.PIPE, text=True)
            assert client.stderr is not None
            for line in client.stderr:
                with open(work / (tag + ".client.log"), "a") as client_log:
                    client_log.write(line)
                fields = line.split()
                if fields and fields[0] == "FRAME":
                    latencies.append(float(fields[3]))
                    rss_x = max(rss_x, stats(xv.pid)[1])
                    if hx and hx.poll() is None:
                        rss_h = max(rss_h, stats(hx.pid)[1])
                    if kill_at is not None and int(fields[1]) == streams-1 and int(fields[2]) == kill_at:
                        stop(hx)
                elif fields and fields[0] in ("openfail", "framefail"):
                    raise RuntimeError("corpus client: " + line.strip())
            assert client.wait(timeout=5) == 0
        elapsed = time.monotonic() - started
        xe, _ = stats(xv.pid)
        he, _ = stats(hx.pid) if hx and hx.poll() is None else (hb, 0)
        assert xv.poll() is None, "transcoder crashed"
        assert len(latencies) == 40 * streams
        time.sleep(.05)  # allow close-stream telemetry to be written
        stop(xv)
        xv = None
        xlog.flush()
        log = (work / (tag + ".xuvd.log")).read_text()
        counters = [dict(zip(("packets", "failures", "helix_ok", "helix_fallback"),
                            map(int, m))) for m in re.findall(
            r"frames=(\d+).*?failures=(\d+).*?helix_ok=(\d+).*?helix_fallback=(\d+)", log)]
        assert len(counters) == streams, log
        assert all(c["packets"] == 40 and c["failures"] == 0 for c in counters), counters
        data = (work / (tag + ".bin")).read_bytes()
        assert len(data) == 440 * streams
        return {"case": tag, "frames": len(latencies), "sha256": hashlib.sha256(data).hexdigest(),
                "latency_ms": {"p50": pct(latencies,.5), "p95": pct(latencies,.95),
                               "p99": pct(latencies,.99), "max": max(latencies)},
                "rss_max_kib": {"xuvd": rss_x, "helix": rss_h},
                "cpu_percent": {"xuvd": 100*(xe-xb)/os.sysconf("SC_CLK_TCK")/elapsed,
                                "helix": None if kill_at is not None else
                                100*(he-hb)/os.sysconf("SC_CLK_TCK")/elapsed},
                "streams": counters}
    finally:
        stop(client)
        stop(xv)
        stop(hx)
        for h in handles:
            h.close()

def direct_stream_isolation(args):
    path = args.output / "isolation.sock"
    with open(args.output / "isolation.log", "w") as log:
        daemon = subprocess.Popen([str(args.helix), "--pcm-bridge", str(path)],
                                  stdout=log, stderr=subprocess.STDOUT)
        try:
            ready_socket(daemon, path)
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as peer:
                peer.settimeout(1)
                peer.connect(str(path))
                def request(stream, f, level):
                    pcm = struct.pack("<160h", *[level]*160)
                    packet = struct.pack("<4sBBHIIQ", b"HXP1", 1, 1 | (2 if f == 0 else 0),
                                         160, stream, 8000, f*160) + pcm
                    peer.sendall(packet)
                    data = bytearray()
                    while len(data) < len(packet):
                        part = peer.recv(len(packet)-len(data))
                        assert part
                        data.extend(part)
                    magic, version, flags, count, sid, rate, timestamp = struct.unpack("<4sBBHIIQ", data[:24])
                    assert (magic,version,count,sid,rate,timestamp) == (b"HXP1",1,160,stream,8000,f*160)
                    assert flags & 128
                    return data[24:]
                low = [request(101,f,500) for f in range(40)]
                high = [request(102,f,15000) for f in range(40)]
                # Different IDs must produce the same per-stream sequence when interleaved.
                for f in range(40):
                    assert request(201,f,500) == low[f]
                    assert request(202,f,15000) == high[f]

                for stream in range(1000,1100):
                    request(stream,0,1000)
                warm_rss = stats(daemon.pid)[1]
                for stream in range(1100,1600):
                    request(stream,0,1000)
                final_rss = stats(daemon.pid)[1]
                assert final_rss - warm_rss <= 2048, (warm_rss,final_rss)
            return {"isolation": "PASS (40 low/high frames, isolated versus interleaved, bit-identical PCM)",
                    "churn_unique_streams": 600, "rss_warm_kib": warm_rss,
                    "rss_final_kib": final_rss, "bounded_churn": "PASS (short test, not 24h soak)"}

        finally:
            stop(daemon)

def main():
    parser = argparse.ArgumentParser()
    for name in ("xuvd", "helix", "client", "output"):
        parser.add_argument("--"+name, required=True, type=Path)
    args = parser.parse_args()
    args.output = args.output.resolve()
    if len(str(args.output / "process-kill.sock")) >= 108:
        raise RuntimeError("output path too long for Unix sockets")
    args.output.mkdir(parents=True, exist_ok=False)
    assert not re.search(r"127\.0\.0\.1:10100\b",
                         subprocess.check_output(["ss","-lun"], text=True)), "control port in use"
    results = [
        run_case(args,"off","off"),
        run_case(args,"absent","process"),
        run_case(args,"shadow","shadow","--pcm-observe"),
        run_case(args,"shadow-kill","shadow","--pcm-observe",kill_at=19),
        run_case(args,"process","process","--pcm-bridge"),
        run_case(args,"process-kill","process","--pcm-bridge",kill_at=19),
        run_case(args,"multi","process","--pcm-bridge",streams=2)]
    a,b,c,d,e,f,g = results
    assert a["sha256"] == b["sha256"] == c["sha256"] == d["sha256"]
    assert b["streams"][0]["helix_fallback"] > 0
    assert c["streams"][0]["helix_ok"] == 40
    assert e["sha256"] != a["sha256"] and e["streams"][0]["helix_ok"] > 0
    assert f["streams"][0]["helix_ok"] > 0 and f["streams"][0]["helix_fallback"] > 0
    assert all(s["helix_ok"] > 0 for s in g["streams"])
    report = {"classification": "ENV", "result": "PASS", "cases": results,
              "dsp_stream_isolation": direct_stream_isolation(args),
              "limits": "Short synthetic corpus, no RF/audio-quality/24h-soak/PROD validation. CPU tick granularity 10ms; killed Helix CPU unavailable."}
    (args.output / "report.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))

if __name__ == "__main__":
    main()
