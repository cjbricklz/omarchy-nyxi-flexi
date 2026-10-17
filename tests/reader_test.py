import importlib.util
import os
import struct
import unittest

spec = importlib.util.spec_from_file_location("reader", os.path.join(os.path.dirname(__file__), "..", "gamepad-reader.py"))
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


def ev(t, c, v):
    return reader.EVENT.pack(1, 2, t, c, v)


class Reader(unittest.TestCase):
    def test_frames_are_batched_until_syn(self):
        b = reader.Batcher()
        self.assertIsNone(b.feed(reader.EV_KEY, 0x130, 1))
        self.assertIsNone(b.feed(reader.EV_ABS, 0, -500))
        self.assertEqual(b.feed(reader.EV_SYN, reader.SYN_REPORT, 0), {"t": "s", "k": {0x130: 1}, "a": {0: -500}})
        self.assertIsNone(b.feed(reader.EV_SYN, reader.SYN_REPORT, 0), "empty frames are dropped")

    def test_key_repeat_is_ignored(self):
        b = reader.Batcher()
        b.feed(reader.EV_KEY, 0x130, 2)
        self.assertIsNone(b.feed(reader.EV_SYN, reader.SYN_REPORT, 0))

    def test_partial_event_is_kept_for_next_read(self):
        data = ev(reader.EV_KEY, 0x131, 1) + ev(reader.EV_SYN, 0, 0)
        events, rest = reader.decode(data[:-5])
        self.assertEqual(events, [(reader.EV_KEY, 0x131, 1)])
        events, rest = reader.decode(rest + data[-5:])
        self.assertEqual((events, rest), ([(reader.EV_SYN, 0, 0)], b""))

    def test_negative_values(self):
        events, _ = reader.decode(ev(reader.EV_ABS, 1, -32767))
        self.assertEqual(events, [(reader.EV_ABS, 1, -32767)])

    def test_bit_helper(self):
        bits = bytearray([0b00000101, 0b10000000])
        self.assertTrue(reader._has(bits, 0) and reader._has(bits, 2) and reader._has(bits, 15))
        self.assertFalse(reader._has(bits, 1) or reader._has(bits, 99))


class Battery(unittest.TestCase):
    def supply(self, tmp, **files):
        os.makedirs(tmp, exist_ok=True)
        for name, text in files.items():
            with open(os.path.join(tmp, name), "w") as f:
                f.write(text)
        return tmp

    def test_percentage_and_status(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = self.supply(d, capacity="87\n", status="Discharging\n")
            self.assertEqual(reader.read_power_supply(p), {"pct": 87, "status": "Discharging", "level": None})

    def test_level_only_is_a_coarse_percentage(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = self.supply(d, capacity_level="Low\n")
            self.assertEqual(reader.read_power_supply(p), {"pct": 25, "status": "Unknown", "level": "Low"})

    def test_nothing_readable(self):
        self.assertEqual(reader.read_power_supply("/nonexistent"), {"pct": None, "status": "Unknown", "level": None})

    def test_supply_is_matched_by_ancestry(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            hid = os.path.join(d, "devices", "0005:045E:02FD.0017")
            node = os.path.join(hid, "input", "input30", "event25")
            os.makedirs(node)
            other = os.path.join(d, "devices", "other")
            os.makedirs(other)
            for name, owner in (("ps-a", other), ("ps-b", hid)):
                os.makedirs(os.path.join(d, "power", name))
                os.symlink(owner, os.path.join(d, "power", name, "device"))
            os.makedirs(os.path.join(d, "class_input", "event25"))
            os.symlink(node, os.path.join(d, "class_input", "event25", "device"))
            found = reader.power_supply_for("/dev/input/event25", os.path.join(d, "power"), os.path.join(d, "class_input"))
            self.assertEqual(found, os.path.join(d, "power", "ps-b"))

    def test_bluez_percentage(self):
        self.assertEqual(reader.parse_bluez_battery("\tBattery Percentage: 0x64 (100)\n"), 100)
        self.assertEqual(reader.parse_bluez_battery("\tBattery Percentage: 0x37 (55)"), 55)
        self.assertIsNone(reader.parse_bluez_battery("Name: x"))


if __name__ == "__main__":
    unittest.main()
