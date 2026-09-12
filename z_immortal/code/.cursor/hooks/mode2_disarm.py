#!/usr/bin/env python3
"""Disarm Mode-2 session marker."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKER = ROOT / ".cursor" / "mode2-session.json"


def main() -> None:
    if MARKER.exists():
        MARKER.unlink()
        print("MODE2_DISARMED")
    else:
        print("MODE2_ALREADY_OFF")


if __name__ == "__main__":
    main()
