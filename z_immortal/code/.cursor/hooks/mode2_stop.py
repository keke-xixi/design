#!/usr/bin/env python3
"""stop hook: if Mode-2 armed and not expired, auto-continue without asking user."""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKER = ROOT / ".cursor" / "mode2-session.json"
NEXT = ROOT / ".cursor" / "mode2-next.md"


def out(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.stdout.flush()


def main() -> None:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except Exception:
        out({})
        return

    status = str(payload.get("status") or payload.get("reason") or "")
    if status.lower() in {"aborted", "error", "cancelled", "canceled"}:
        out({})
        return

    if not MARKER.exists():
        out({})
        return

    try:
        sess = json.loads(MARKER.read_text(encoding="utf-8"))
    except Exception:
        out({})
        return

    ends_at = float(sess.get("ends_at") or 0)
    now = time.time()
    if now >= ends_at:
        try:
            MARKER.unlink()
        except OSError:
            pass
        out({})
        return

    remaining_h = max(0.0, (ends_at - now) / 3600.0)
    next_hint = "继续轮换：好玩 / 美观 / 战斗 / 地图 / 前期上头"
    if NEXT.exists():
        try:
            line = NEXT.read_text(encoding="utf-8").strip().splitlines()[0]
            if line:
                next_hint = line
        except Exception:
            pass

    msg = (
        "Mode-2 续跑：不要问用户。阅读并执行 `.cursor/skills/tongxuan-mode-2/SKILL.md`。"
        f"剩余约 {remaining_h:.2f} 小时。本回合主轴：{next_hint}。"
        "卡住就换思路继续；改完跑相关 smoke；禁止 commit/push。"
    )
    out({"followup_message": msg})


if __name__ == "__main__":
    main()
