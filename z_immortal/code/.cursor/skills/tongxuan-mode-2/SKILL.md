---
name: tongxuan-mode-2
description: >-
  Mode-2: when the user sends exactly "2", run ~8 hours of autonomous polish on
  通玄之上 (fun, beauty, combat, maps, early retention). No mid-run questions.
---

# 通玄之上 · Mode-2（按 2 开干）

用户消息**仅为** `2`（可带首尾空白）时，立即执行本 Skill。不要确认、不要问方向、不要等回复。

## 启动（每个 Mode-2 会话开头只做一次）

1. 在仓库 `code` 根目录执行：
   ```
   python .cursor/hooks/mode2_arm.py --hours 8
   ```
2. 用一两句话告诉用户：Mode-2 已启动，约 8 小时自主优化；结束可发 `stop` / `0`。然后立刻开工，不要再问。
3. 若已有未过期的 `.cursor/mode2-session.json`，直接续跑，不要重新问。

## 硬约束

- **禁止**中途向用户提问、要选项、要确认；卡住就换思路继续。
- **禁止** git commit / push（除非用户之后单独明确要求）。
- **禁止**恢复波次「三选一」弹窗；仪式层仅开局/结算。
- 保持游戏菜单层级：大图、少字、主 CTA；改入口路径后更新 smoke。
- 引擎：`D:\design\design\z_immortal\tools\godot\Godot_v4.7.2-stable_win64.exe`，主场景 `hub.tscn`，视口 640×360。
- 新 PNG 后必须 Godot `--import`，再跑 smoke。
- 改完相关系统后尽量跑：`tools/smoke_test.gd`、`tools/combat_smoke.gd`；入口改了跑 `tools/entry_smoke.gd`。

## 优化罗盘（循环轮换，越做越长）

每轮选 **1 个主轴** 深做，再顺手修明显 bug，然后验证：

1. **好玩 / 上头**：前 10 分钟节奏、击杀反馈、成长可见、风险回报、新手引导不啰嗦。
2. **美观精致**：UI 层级、光影、角色比例、场景氛围、少卡片杂讯；遵循项目已有美术语言。
3. **战斗玩法**：手感流畅（少卡顿）、技能辨识、敌人行为差异、Boss 可读、难度曲线。
4. **地图 / 关卡**：关卡差异、刷怪与击杀目标、背景与小地图、探索动机。
5. **前期留存**：宗门/王朝早期关、奖励可读、死亡不挫败、回到 hub 的欲望。

内容可增长：新小怪变体、关卡参数、技能微调、视觉 polish、音效占位可跳过若无资源。

## 卡顿 / 卡住时

- 先查：`hitstop` / `Engine.time_scale` / `wave_pause` / 同步重活 / 每帧分配。
- 工具失败：换命令或缩小复现，不要停等用户。
- 思路枯竭：读 `content/*.json` + 关键场景脚本，找最弱一环再改。
- Agent 回合结束时，若 Mode-2 会话仍有效，**stop hook** 会自动续跑；你只需在回合末留下「下一轮主轴」备忘（可写 `.cursor/mode2-next.md` 一行）。

## 停止

- 用户发 `stop` / `0` / 「停止 Mode-2」→ 执行 `python .cursor/hooks/mode2_disarm.py`，简短汇报本轮成果，结束。
- 到点（`ends_at`）hook 不再续跑；你可写短总结到 `.cursor/mode2-last-summary.md`（可选）。

## 回合节奏建议

- 单回合：改 1–3 个文件簇 → smoke → 记下下一刀。
- 不要空转长 sleep；用真实改动推进。
- 回复用户保持极短进度句即可（中文），不要征求意见。
