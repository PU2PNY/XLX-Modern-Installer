# PROD — SoftAMBE replaces xuvd/Helix runtime — 2026-11-03

## Decision and evidence levels

The operator explicitly authorized an **in-place PROD change without using WartyWallaby**, accepted a temporary outage, requested PP5PK default SoftAMBE audio values, Helix runtime deactivation and a full rollback point. This was an operational exception to the prior ENV-first gate and **does not count as ENV/HW validation**. The existing XLXD and Nginx/PHP-FPM dashboard were not replaced, and the external complete installer was never executed. Tracked at [issue #92](https://github.com/PU2PNY/XLX-Modern-Installer/issues/92) and [DMR↔YSF request #91](https://github.com/PU2PNY/XLX-Modern-Installer/issues/91).

### Provenance (DOC)
- [PP5PK/XLX-SoftAMBE_Installer](https://github.com/PP5PK/XLX-SoftAMBE_Installer) commit \`eff797298744f3b2e1db7bb5b9424db18a03827b\`
- [PP5PK/xlxd](https://github.com/PP5PK/xlxd) commit \`f10f91bdc5c19ad5b435d96a6595f945403e093a\`
- [SoftAMBE patch](https://github.com/PP5PK/XLX-SoftAMBE_Installer/blob/eff797298744f3b2e1db7bb5b9424db18a03827b/patches/xlxd-ambed-softambe.patch), Git blob SHA \`dca3f9015edf017458f192b744c5b78889769258\`
- Our main \`55732025a7649dd131234542be4b1d113f17e889\`; version document \`1.4.6\`; service state verified directly, not assumed from source tree.

### Full pre-switch recovery point (PROD)
Root-owned, mode 0700 directory:
\`\`\`
/opt/xlx026-backups/SOFTAMBE_PRE_SWITCH_20261103_191457Z/
  snapshot.tar.gz
  snapshot.tar.gz.sha256
  manifest.txt
  ROLLBACK.sh
\`\`\`
Archive SHA256 \`c694c4028f9b55af5fb913a16da28e2a08248cace98a3ad43ef9cc31ad370a9f\`; 22,230,572 bytes. Covers \`/xlxd\`, \`/opt/xlx-unified-voice\`, \`/opt/helix-voice\`, \`/etc/systemd/system\`, \`/etc/xlx-modern\`. No real backup data, secret or config contents belong in GitHub. Hash and archive listing verified; extracted-and-compared key files verified. **The rollback was actually executed in PROD after the first unsuccessful service start, and restored both xuvd and Helix successfully without restarting XLXD.** This supports a real service restoration test, not just a file-copy claim.

### Build and tests
- SW on PROD host, non-root, isolated temporary source tree: \`git apply --check\` PASS, \`make -j2 NO_FTDI=1\` PASS. No \`make install\`/root build.
- Built x86_64 ELF SHA256: \`59cbb514eaa727e7bd209287bfab72df3c2083a71daefedc92cf2af59c52875e\`.
- Standalone isolated socket \`127.0.0.2:10100\` returned \`AMBEDPONG\`; opened 1→2 and 2→1; accepted and returned one artificial 11-byte frame in each direction. These are synthetic contract tests, **not** live RF quality checks.
- First systemd cutover failed because \`/opt/xlx-softambe\` was created mode 0700, inaccessible to service \`DynamicUser\`. The rollback was invoked and verified both old services active, XLXD PID 1298 retained.
- Directory permissions were corrected to 0755, not executable permissions weakened; binary SHA unchanged.

### Current installed PROD components and configuration

\`\`\`text
/opt/xlx-softambe/bin/ambed      [root-owned executable, SHA above]
/opt/xlx-softambe/ambed.conf     [upstream PP5PK template; 3 pairs]
/etc/systemd/system/xlx-softambe.service
/etc/systemd/system/xlx-softambe-rollback.service
\`\`\`

- \`xlx-softambe.service\`: enabled and active, reported PID **7092** at initial successful canary; control bound \`127.0.0.1:10100\`. Unit is custom for XLX026, uses DynamicUser, limits and Conflicts with xuvd, crash OnFailure rollback unit.
- \`xlxd.service\`: enabled and active, reported PID **1298**, **not restarted**. Externally bound \`82.152.175.30:10100\`.
- \`xlx-unified-voice.service\`: inactive/disabled.
- \`helix-voice-shadow.service\`: inactive/disabled; \`xlx-helix-monitor.timer\`: inactive/disabled. Binaries retained for rollback; not deleted.
- PP5PK config copied with \`AMBED_SOFT_PAIRS=3\` (three CPUs): \`GAIN_DSTAR_TO_DMR=-20\`, \`EQ_DSTAR_TO_DMR=0\`, \`GATE_DSTAR_TO_DMR=0\`, \`GAIN_DMR_TO_DSTAR=19\`, \`EQ_DMR_TO_DSTAR=0\`, \`GATE_DMR_TO_DSTAR=-50\`, \`EQ_LOWCUT_HZ=250\`, \`EQ_PEAK_HZ=1800\`, gate ratio 2, max cut 15dB, hold 100ms, release 270ms, idle reset 500ms.
- Systemd verify PASS (warning about pre-existing unrelated \`xlx-tx-turn-ai-monitor.service\` user nobody).
- PROD keepalive \`AMBEDPING\`→\`AMBEDPONG\` PASS on 127.0.0.1:10100.
- XLXD journald showed four AMBED streams and packets with **0 timeouts** in observed batches: 0/211, 0/221, 0/96, 0/90. These are limited samples; not a 24h soak. SoftAMBE reported 6 channels ready.
- Website paths \`/\`, \`/ao-vivo\`, \`/modulos\` returned HTTP200 after cutover, Live functionality/radio quality not fully proven by this check.
- Initial observed SoftAMBE process RSS ~5.7MB and CPU ~4.1%, not a sustained load benchmark.

### Revert if operator dislikes the audio
**Do not reinstall XLXD.** With root on the host, the preserved rollback tool is:

\`\`\`bash
sudo /opt/xlx026-backups/SOFTAMBE_PRE_SWITCH_20261103_191457Z/ROLLBACK.sh --check
sudo /opt/xlx026-backups/SOFTAMBE_PRE_SWITCH_20261103_191457Z/ROLLBACK.sh --apply
\`\`\`

The script verifies SHA256 first, stops/disables \`xlx-softambe.service\`, restores original xuvd/Helix binary/unit/drop-in files, enables/starts Helix observer and its timer, starts xuvd (legacy service remains disabled for automatic boot as it was before this override), and **does not restart XLXD**. The independent OnFailure service invokes this script if SoftAMBE enters a fatal failed state. Follow up by checking \`xlxd\`, \`xlx-unified-voice\`, \`helix-voice-shadow\` and the control socket and test D-STAR↔DMR/YSF audio. Avoid public logs or keys.

### Important limits / follow-ups
- **No HW/RF listening test done**. Ask the operator to compare live D-STAR→YSF, YSF DN→D-STAR, D-STAR→DMR and DMR→D-STAR, at normal radio microphone gain, and report distortion, volume and any EOT issue.
- **SoftAMBE defaults have EQ OFF**; the frequency values do not enable EQ by themselves.
- **DMR↔YSF DN uses AMBE+2 direct frame adaptation** and is generally not modified by the D-STAR↔DMR SoftAMBE swap; no claim that issue #91 is fixed.
- VW remains YSF native only.
- Do not run PP5PK full installer, enable old xuvd alongside ambed, update XLXD core or remove the rollback backup.
- No claims of 24h soak, PROD full protocols or live RF parity until separately observed.

## External sources
- [PP5PK installer](https://github.com/PP5PK/XLX-SoftAMBE_Installer)
- [Original ambed.conf template](https://github.com/PP5PK/XLX-SoftAMBE_Installer/blob/master/templates/ambed.conf)
- [Current xuvd interface contract](https://github.com/PU2PNY/XLX-Modern-Installer/blob/main/experimental/helix-bridge/xuvd.cpp)

## Production-only validation follow-up — 2026-11-03
The operator explicitly reiterated: **all remaining tests will be performed on XLX026 PROD, not WartyWallaby**. This is a scope constraint, not a representation that ENV/HW tests have been done.

Read-only measurements on PROD, without reboot, restart, synthetic radio injection or new process deployment:
- Both \`xlxd.service\` and \`xlx-softambe.service\` were active/enabled, initial PIDs 1298 and 7092 **unchanged**; xuvd and Helix remained inactive/disabled.
- Since SoftAMBE activation at 16:24:33 -03, journals contained 23 AMBED stream open events and 23 SoftAMBE pair open and close events.
- 23 closed-stream statistics included 22 internally consistent entries: **4 timeouts out of 10,389 packets** in those entries (about 0.0385%). There was **one anomalous counter \`2 of 1 packets timed out\`**, which cannot legitimately contribute to a loss ratio without separate source-code analysis. Do not hide or silently normalize it.
- The highest reported per-stream latency was 103.0 ms (maximum, not p95, not steady-state latency).
- No error/failure strings were present in the SoftAMBE journal in that measured window and no transcoder keepalive timeout was detected in the XLXD journal.
- Four public routes, \`/\`, \`/ao-vivo\`, \`/modulos\`, \`/consulta-indicativo.php\`, all returned HTTP200 with probe response times ~0.04..0.18s. HTTP200 does not prove real-time UI functionality.
- RSS: \`ambed\` about 6.6 MB, \`xlxd\` about 66.0 MB, point-in-time CPU columns ~7.5% and 7.2%; memory available ~1,245 MB. These are point samples, not full-load benchmarks.
- Backup \`snapshot.tar.gz\` SHA256 verification still PASS. Production port 127.0.0.1:10100 bound by ambed PID7092; XLXD listened at the configured public IP 10100.
- No actual hardware listening / audio quality observation, prolonged soak, DMR↔YSF EQ changes, full RF protocol regression or disaster recovery test can be claimed yet.

**IMPORTANT:** A result of \`2 of 1\` in codec statistics is logically inconsistent as a packet-loss fraction. Investigate the XLXD log counter semantics and stream termination before interpreting this as dropped audio. It is not evidence on its own to raise mic gain or modify EQ.

### Production validation guardrails
Use only read-only checks and real voluntarily occurring RF streams. Never play synthetic packets into public XLXD/codec sockets, switch an active transcoder, restart services or change EQ solely for test metrics. Keep the pre-switch archive for immediate rollback upon operator-reported audio degradation. Radio intelligibility requires operator observations in both directions of each intended crossmode flow and cannot be inferred from server logs.

