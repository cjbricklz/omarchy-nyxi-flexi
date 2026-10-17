#!/usr/bin/env python3
"""Streams a game controller's live input as JSON lines, for the NYXI Flexi panel.

Reads raw evdev events straight from /dev/input/event*, so it needs no extra
packages and no root: a controller is readable by the logged-in user (udev
uaccess). Read-only; it never grabs the device or sends anything to it.

Output, one JSON object per line:
  {"t":"dev", "name", "vendor", "product", "path", "abs": {code: [min, max]},
              "k": {code: 0|1}, "a": {code: value}}   controller found, initial state
  {"t":"s", "k": {code: 0|1}, "a": {code: value}}      changed buttons and axes
  {"t":"bat", "pct": 0..100 | null, "status": "Charging" | ...}   battery, when Linux reports one
  {"t":"none"}                                          no controller found yet
  {"t":"gone"}                                          the controller went away

Usage: gamepad-reader.py [/dev/input/eventN]   (default: first controller found)
"""
import fcntl
import glob
import json
import os
import re
import select
import struct
import subprocess
import sys
import time

EV_SYN, EV_KEY, EV_ABS = 0x00, 0x01, 0x03
SYN_REPORT = 0
BTN_SOUTH, BTN_TRIGGER, KEY_MAX, ABS_MAX = 0x130, 0x120, 0x2FF, 0x3F
ABS_X = 0

EVENT = struct.Struct("llHHi")  # struct input_event (64-bit): time, type, code, value
ABSINFO = struct.Struct("6i")   # struct input_absinfo: value, min, max, fuzz, flat, res


def _ioc_read(nr, size):
    return (2 << 30) | (size << 16) | (ord("E") << 8) | nr


def _bits(fd, ev, nbits):
    size = nbits // 8 + 1
    buf = bytearray(size)
    fcntl.ioctl(fd, _ioc_read(0x20 + ev, size), buf)
    return buf


def _has(bits, n):
    return n // 8 < len(bits) and bool(bits[n // 8] >> (n % 8) & 1)


def probe(path):
    """Returns device info if `path` is a game controller, else None."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        return None
    try:
        name = bytearray(256)
        n = fcntl.ioctl(fd, _ioc_read(0x06, 256), name)
        name = bytes(name[: n - 1]).decode("utf-8", "replace")
        if "IMU" in name or "Motion" in name:  # the Pro Controller's separate gyro device
            return None
        keys, absb = _bits(fd, EV_KEY, KEY_MAX), _bits(fd, EV_ABS, ABS_MAX)
        # A pad has gamepad or joystick buttons and at least one stick axis.
        if not (_has(keys, BTN_SOUTH) or _has(keys, BTN_TRIGGER)) or not _has(absb, ABS_X):
            return None
        ident = bytearray(8)
        fcntl.ioctl(fd, _ioc_read(0x02, 8), ident)
        _bus, vendor, product, _ver = struct.unpack("4H", bytes(ident))
        return {"path": path, "name": name, "vendor": vendor, "product": product}
    except OSError:
        return None
    finally:
        os.close(fd)


def find(wanted=None):
    if wanted:
        return probe(wanted)
    for path in sorted(glob.glob("/dev/input/event*"), key=lambda p: int(p[16:])):
        info = probe(path)
        if info:
            return info
    return None


def snapshot(fd):
    """Initial pressed buttons, axis values and axis ranges."""
    keys = _bits(fd, EV_KEY, KEY_MAX)
    state = bytearray(len(keys))
    fcntl.ioctl(fd, _ioc_read(0x18, len(state)), state)  # EVIOCGKEY: currently pressed
    absb = _bits(fd, EV_ABS, ABS_MAX)
    k = {c: int(_has(state, c)) for c in range(KEY_MAX + 1) if _has(keys, c)}
    a, ranges = {}, {}
    for c in range(ABS_MAX + 1):
        if not _has(absb, c):
            continue
        buf = bytearray(ABSINFO.size)
        fcntl.ioctl(fd, _ioc_read(0x40 + c, ABSINFO.size), buf)
        value, lo, hi, *_ = ABSINFO.unpack(bytes(buf))
        a[c], ranges[c] = value, [lo, hi]
    return k, a, ranges


# ---------- Battery ----------
# Linux exposes a HID controller's battery as a power supply whose device is the controller's own HID
# device (an ancestor of its input node). Bluetooth can also report one over its Battery Service.
POWER = "/sys/class/power_supply"
LEVELS = {"full": 100, "high": 75, "normal": 50, "low": 25, "critical": 10}   # coarse stand-ins for a missing percentage


def read_file(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def power_supply_for(event_path, root=POWER, sys_input="/sys/class/input"):
    """The power supply that belongs to this controller, or None."""
    node = os.path.realpath(os.path.join(sys_input, os.path.basename(event_path), "device"))
    try:
        names = sorted(os.listdir(root))
    except OSError:
        return None
    for name in names:
        owner = os.path.realpath(os.path.join(root, name, "device"))
        if owner != "/" and (node == owner or node.startswith(owner + "/")):
            return os.path.join(root, name)
    return None


def read_power_supply(directory):
    """{"pct": int | None, "status": str, "level": str | None} from a power supply directory.

    "level" is the kernel's own word ("Normal", "Low", ...) and is set only when there is no real percentage,
    so the UI can show it instead of passing a coarse stand-in off as a measurement (hid-nintendo does this)."""
    cap = read_file(os.path.join(directory, "capacity"))
    level = read_file(os.path.join(directory, "capacity_level"))
    status = read_file(os.path.join(directory, "status")) or "Unknown"
    if cap and cap.isdigit():
        return {"pct": int(cap), "status": status, "level": None}
    pct = LEVELS.get((level or "").lower())
    return {"pct": pct, "status": status, "level": level if pct is not None else None}


def parse_bluez_battery(text):
    """Percentage from `bluetoothctl info` ("Battery Percentage: 0x64 (100)"), or None."""
    m = re.search(r"Battery Percentage:\s*0x[0-9a-fA-F]+\s*\((\d+)\)", text or "")
    return int(m.group(1)) if m else None


def bluetooth_battery(fd):
    """Battery over Bluetooth, found through the controller's address (the input device's unique id)."""
    try:
        buf = bytearray(64)
        n = fcntl.ioctl(fd, _ioc_read(0x08, 64), buf)
        mac = bytes(buf[:n]).split(b"\0")[0].decode("ascii", "replace").upper()
    except OSError:
        return None
    if not re.fullmatch(r"([0-9A-F]{2}:){5}[0-9A-F]{2}", mac):
        return None
    try:
        out = subprocess.run(["bluetoothctl", "info", mac], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    pct = parse_bluez_battery(out)
    return None if pct is None else {"pct": pct, "status": "Unknown"}


class Battery:
    """Polls the battery now and then and reports it when it changes."""

    def __init__(self, fd, event_path, every=10.0):
        self.fd, self.event_path, self.every = fd, event_path, every
        self.last_poll, self.last_sent = 0.0, None

    def poll(self, now):
        if now - self.last_poll < self.every:
            return None
        self.last_poll = now
        supply = power_supply_for(self.event_path)
        reading = read_power_supply(supply) if supply else bluetooth_battery(self.fd)
        if reading is None:
            reading = {"pct": None, "status": "Unknown"}
        if reading == self.last_sent:
            return None
        self.last_sent = reading
        return dict(reading, t="bat")


def decode(data):
    """Splits raw bytes into (type, code, value) events; leftover bytes are returned too."""
    n = len(data) // EVENT.size
    events = [EVENT.unpack_from(data, i * EVENT.size)[2:] for i in range(n)]
    return events, data[n * EVENT.size:]


class Batcher:
    """Collects button/axis changes until the controller's SYN_REPORT, then emits one frame."""

    def __init__(self):
        self.k, self.a = {}, {}

    def feed(self, etype, code, value):
        if etype == EV_KEY and value != 2:  # 2 is auto-repeat
            self.k[code] = value
        elif etype == EV_ABS:
            self.a[code] = value
        elif etype == EV_SYN and code == SYN_REPORT and (self.k or self.a):
            frame = {"t": "s", "k": self.k, "a": self.a}
            self.k, self.a = {}, {}
            return frame
        return None


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def stream(info):
    fd = os.open(info["path"], os.O_RDONLY | os.O_NONBLOCK)
    try:
        k, a, ranges = snapshot(fd)
        emit(dict(info, t="dev", abs=ranges, k=k, a=a))
        batcher, pending, battery = Batcher(), b"", Battery(fd, info["path"])
        while True:
            report = battery.poll(time.monotonic())
            if report:
                emit(report)
            if not select.select([fd], [], [], 5)[0]:      # wake now and then to look at the battery
                continue
            try:
                data = os.read(fd, EVENT.size * 64)
            except BlockingIOError:
                continue
            events, pending = decode(pending + data)
            for etype, code, value in events:
                frame = batcher.feed(etype, code, value)
                if frame:
                    emit(frame)
    except OSError:  # unplugged, or switched off
        emit({"t": "gone"})
    finally:
        os.close(fd)


def main():
    wanted = sys.argv[1] if len(sys.argv) > 1 else None
    announced = False
    while True:
        info = find(wanted)
        if info:
            announced = False
            stream(info)
        elif not announced:
            emit({"t": "none"})
            announced = True
        time.sleep(1.5)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
