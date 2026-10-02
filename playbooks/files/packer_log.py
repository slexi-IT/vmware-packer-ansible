#!/usr/bin/env python3
"""Turn Packer's -machine-readable output into readable lines for the AWX job log.

  packer_log.py tail <out> <offset> <rc_file> <disk> <wait_seconds>
      Wait until new output arrives, Packer exits or wait_seconds pass, then print
      JSON with the new lines since <offset>, the new offset, the disk size so far
      and, once Packer has exited, its return code.

  packer_log.py summary <out> <debug_log> <debug_tail_lines>
      Print JSON with the artifacts, errors and the last lines of the debug log.
"""
import json
import os
import sys
import time
from datetime import datetime


def unescape(text):
    # Packer escapes commas and newlines inside machine-readable fields
    return text.replace("%!(PACKER_COMMA)", ",").replace("\\n", "\n").replace("\\r", "")


def parse(line):
    """Return (timestamp, type, fields) for one machine-readable line, or None."""
    parts = line.rstrip("\n").split(",")
    if len(parts) < 3 or not parts[0].isdigit():
        return None
    return int(parts[0]), parts[2], [unescape(p) for p in parts[3:]]


def human(ts, kind, text):
    stamp = datetime.fromtimestamp(ts).strftime("%H:%M:%S")
    prefix = "ERROR: " if kind == "error" else ""
    return [f"{stamp}  {prefix}{part}" for part in text.splitlines() if part.strip()]


def size(path):
    try:
        n = os.path.getsize(path)
    except OSError:
        return 0, "-"
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return n, f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024


def read_rc(rc_file):
    try:
        with open(rc_file) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return None


def tail(out, offset, rc_file, disk, wait):
    deadline = time.monotonic() + wait
    while time.monotonic() < deadline:
        if read_rc(rc_file) is not None:
            break
        try:
            if os.path.getsize(out) > offset:
                break
        except OSError:
            pass
        time.sleep(1)

    lines = []
    try:
        with open(out, "rb") as f:
            f.seek(offset)
            chunk = f.read()
    except OSError:
        chunk = b""
    # Only consume complete lines; a partial last line is picked up next time
    complete = chunk[: chunk.rfind(b"\n") + 1]
    for raw in complete.decode("utf-8", "replace").splitlines():
        parsed = parse(raw)
        if parsed and parsed[1] == "ui" and len(parsed[2]) >= 2:
            lines += human(parsed[0], parsed[2][0], parsed[2][1])

    disk_bytes, disk_human = size(disk)
    return {
        "offset": offset + len(complete),
        "lines": lines,
        "rc": read_rc(rc_file),
        "disk_bytes": disk_bytes,
        "disk": disk_human,
    }


def summary(out, debug_log, debug_tail):
    artifacts, errors = [], []
    try:
        with open(out, encoding="utf-8", errors="replace") as f:
            for raw in f:
                parsed = parse(raw)
                if not parsed:
                    continue
                _, kind, fields = parsed
                # artifact,<index>,<subtype>,<value...>; files are artifact,<index>,file,<n>,<path>
                if kind == "artifact" and len(fields) >= 4 and fields[1] == "file":
                    artifacts.append(fields[3])
                elif kind == "ui" and len(fields) >= 2 and fields[0] == "error":
                    errors.append(fields[1])
                elif kind == "error" and fields:
                    errors.append(fields[-1])
    except OSError:
        pass
    try:
        with open(debug_log, encoding="utf-8", errors="replace") as f:
            debug = [l.rstrip("\n") for l in f.readlines()[-debug_tail:]]
    except OSError:
        debug = []
    return {"artifacts": artifacts, "errors": errors, "debug_tail": debug}


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "tail":
        result = tail(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5], int(sys.argv[6]))
    elif mode == "summary":
        result = summary(sys.argv[2], sys.argv[3], int(sys.argv[4]))
    else:
        sys.exit(f"unknown mode {mode}")
    print(json.dumps(result))
