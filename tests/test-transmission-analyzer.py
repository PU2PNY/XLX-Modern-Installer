#!/usr/bin/env python3
import importlib.util
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
PATH = ROOT / "observability" / "transmission-analyzer" / "monitor.py"
spec = importlib.util.spec_from_file_location("txa", PATH)
txa = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = txa
spec.loader.exec_module(txa)


def ysf(kind=b"YSFD", gateway="PS7JAP", source="PS7JAP", dest="ALL", seq=0, eot=0):
    if kind == b"YSFP":
        return b"YSFP" + gateway.ljust(10).encode("ascii")

    packet = bytearray(155)
    packet[:4] = b"YSFD"
    packet[4:14] = gateway.ljust(10).encode("ascii")
    packet[14:24] = source.ljust(10).encode("ascii")
    packet[24:34] = dest.ljust(10).encode("ascii")
    packet[34] = ((seq & 0x7F) << 1) | (1 if eot else 0)
    return bytes(packet)


class AnalyzerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        txa.EVENT_LOG = pathlib.Path(self.tmp.name) / "events.log"
        self.analyzer = txa.Analyzer(now_fn=lambda: 0.0)

    def tearDown(self):
        self.tmp.cleanup()

    def station(self, callsign="PS7JAP"):
        return self.analyzer.snapshot(10.0)["stations"][callsign]

    def test_normal_sequence(self):
        for seq, stamp in [(10, 1.0), (11, 1.1), (12, 1.2)]:
            self.analyzer.process_ysf(ysf(seq=seq), "10.0.0.1", 50000, stamp)
        row = self.station()
        self.assertEqual(row["likely_missing_frames"], 0)
        self.assertEqual(row["counter_jumps"], 0)
        self.assertEqual(row["duplicate_frames"], 0)

    def test_timing_matched_gap(self):
        self.analyzer.process_ysf(ysf(seq=20), "10.0.0.1", 50000, 1.0)
        self.analyzer.process_ysf(ysf(seq=23), "10.0.0.1", 50000, 1.3)
        row = self.station()
        self.assertEqual(row["likely_missing_frames"], 2)
        self.assertEqual(row["timing_gap_events"], 1)

    def test_fast_large_jump_not_fake_loss(self):
        self.analyzer.process_ysf(ysf(seq=3), "10.0.0.1", 50000, 1.0)
        self.analyzer.process_ysf(ysf(seq=25), "10.0.0.1", 50000, 1.17)
        row = self.station()
        self.assertEqual(row["likely_missing_frames"], 0)
        self.assertEqual(row["counter_jumps"], 1)

    def test_eot_packet_is_not_reported_as_counter_jump(self):
        self.analyzer.process_ysf(ysf(seq=40), "10.0.0.1", 50000, 1.0)
        self.analyzer.process_ysf(ysf(seq=0, eot=1), "10.0.0.1", 50000, 1.1)
        row = self.station()
        self.assertEqual(row["counter_jumps"], 0)
        self.assertEqual(row["out_of_order_or_reset"], 0)
        self.assertEqual(row["likely_missing_frames"], 0)

    def test_eot_breaks_continuity(self):
        self.analyzer.process_ysf(ysf(seq=40, eot=1), "10.0.0.1", 50000, 1.0)
        self.analyzer.process_ysf(ysf(seq=2), "10.0.0.1", 50000, 1.1)
        row = self.station()
        self.assertEqual(row["likely_missing_frames"], 0)
        self.assertEqual(row["counter_jumps"], 0)

    def test_concurrent_endpoints_without_ip_in_state(self):
        self.analyzer.process_ysf(ysf(kind=b"YSFP"), "10.0.0.1", 42000, 1.0)
        self.analyzer.process_ysf(ysf(kind=b"YSFP"), "10.0.0.1", 48927, 1.1)
        row = self.station()
        self.assertEqual(row["active_endpoint_count"], 2)
        self.assertNotIn("10.0.0.1", str(self.analyzer.snapshot(2.0)))

    def test_non_ysf_ignored(self):
        self.analyzer.process_ysf(b"hello", "10.0.0.1", 50000, 1.0)
        self.assertEqual(self.analyzer.snapshot(2.0)["stations"], {})


if __name__ == "__main__":
    unittest.main()
