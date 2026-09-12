#!/usr/bin/env python3
"""Arm Mode-2 session marker (~N hours of autonomous polish)."""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKER = ROOT / ".cursor" / "mode2-session.json"
NEXT = ROOT / ".cursor" / "mode2-next.md"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=8.0)
    args = ap.parse_args()
    now = time.time()
    payload = {
        "armed_at": now,
        "ends_at": now + max(args.hours, 0.1) * 3600.0,
        "hours": args.hours,
        "project": "tongxuan",
    }
    MARKER.parent.mkdir(parents=True, exist_ok=True)
    MARKER.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    if not NEXT.exists():
        NEXT.write_text(
            "下一刀：战斗手感与前期关卡节奏（好玩 + 少卡顿）\n",
            encoding="utf-8",
        )
    print(f"MODE2_ARMED ends_at={payload['ends_at']:.0f} hours={args.hours}")


if __name__ == "__main__":
    main()
