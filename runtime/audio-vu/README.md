# Passive VU recovery source

Observed XLX026 passive VU source. It decodes a passive copy of packets, never
proxies or alters transmitted voice. It requires the approved XLXD headers,
OP25 and the existing adapter. The absolute XLXD include matches the canonical
source location; restore/build only with the corresponding pinned dependencies.
This source is preserved for recovery; no VU process is enabled by this commit.

`bash runtime/build-audio-recovery.sh /new/output/directory` builds both the
transcoder and passive VU with pinned XLXD/OP25 dependencies. It changes the
absolute header include in a temporary build copy only and records both hashes.
No packet capture, service activation or production replacement is performed.
