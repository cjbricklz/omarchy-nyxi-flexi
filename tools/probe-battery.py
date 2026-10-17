#!/usr/bin/env python3
"""Finds out whether the Flexi will tell the PC its battery level over Bluetooth, and how.

The controller's HID description declares a battery (input report 4, "Battery Strength"), but the kernel
never gets a value, so /sys/class/power_supply shows "No data available". This asks the controller for report 4
directly (a HID GET_REPORT) and then listens for a while for it to arrive by itself, printing every battery report.
Read-only: it sends nothing but that one request. Needs root to open /dev/hidraw*.

Usage: sudo python3 tools/probe-battery.py [/dev/hidrawN] [seconds, default 20]
"""
import collections
import fcntl
import glob
import os
import select
import sys
import time

VENDOR, PRODUCT = "0000045E", "000002FD"      # the Flexi pretends to be an Xbox Wireless Controller


def hidraw_node():
    for uevent in glob.glob("/sys/class/hidraw/hidraw*/device/uevent"):
        text = open(uevent).read().upper()
        if VENDOR in text and PRODUCT in text:
            return "/dev/" + uevent.split("/")[4]
    return None


def hidioc_get_input(length):
    """HIDIOCGINPUT(len): ask the device for an input report (_IOC read|write, 'H', 0x0A)."""
    return (3 << 30) | (length << 16) | (ord("H") << 8) | 0x0A


def main():
    node = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].startswith("/dev/") else hidraw_node()
    seconds = int(sys.argv[-1]) if sys.argv[-1].isdigit() else 20
    if not node:
        raise SystemExit("no Flexi found on Bluetooth; connect it as \"Xbox Wireless Controller\" first")
    try:
        fd = os.open(node, os.O_RDWR | os.O_NONBLOCK)
    except PermissionError:
        raise SystemExit("run this with sudo: the hidraw device is root-only")
    print("using", node)

    buf = bytearray([4]) + bytearray(7)
    try:
        n = fcntl.ioctl(fd, hidioc_get_input(len(buf)), buf)
        print("GET_REPORT 4 answered, %d bytes: %s" % (n, bytes(buf[:max(n, 1)]).hex(" ")))
    except OSError as e:
        print("GET_REPORT 4 got no answer:", e.strerror, "(errno %d)" % e.errno)

    print("listening for %d s; press buttons so the controller keeps talking" % seconds)
    seen, end = collections.Counter(), time.time() + seconds
    while time.time() < end:
        if not select.select([fd], [], [], 0.5)[0]:
            continue
        try:
            data = os.read(fd, 64)
        except BlockingIOError:
            continue
        seen[data[0]] += 1
        if data[0] == 4:
            print("battery report:", data.hex(" "))
    print("report ids seen (id: count):", dict(seen))
    print("No report 4 above means the Flexi never sends a battery level over Bluetooth.")


if __name__ == "__main__":
    main()
