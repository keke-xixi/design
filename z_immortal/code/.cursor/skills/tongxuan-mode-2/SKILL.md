---
name: tongxuan-mode-2
description: >-
  Mode-2: when the user sends exactly "2", run ~8 hours of autonomous polish on
  通玄之上 (fun, beauty, combat, maps, character scale, lag, code hygiene, early
  retention). Auto-continue without asking; pause with 3 / stop / 0.
---

# 通玄之上 · Mode-2（按 2 开干 · 约 8 小时）

用户消息**仅为** `2`（可带首尾空白）时，立即执行本 Skill。不要确认、不要问方向、不要等回复。

## 启动（每个 Mode-2 会话开头只做一次）

1. 在 `z_immortal/code` 根目录执行：
   ```
   node .cursor/hooks/mode2_arm.js --hours 8
   ```
   （若本机有 Python，也可：`python .cursor/hooks/mode2_arm.py --hours 8`）
2. 用一两句话告诉用户：Mode-2 已启动，约 8 小时自主优化；状态见 `.cursor/mode2-STATUS.md`；暂停可发 `3` / `stop` / `0` / 「暂停」。然后立刻开工，不要再问。
   每回合开头/结尾更新 `.cursor/mode2-STATUS.md` 为工作中（可跑 `node .cursor/hooks/mode2_status.js working`）。
3. 若已有未过期的 `.cursor/mode2-session.json`，直接续跑，不要重新问。

## 硬约束

- **禁止**中途向用户提问、要选项、要确认；卡住就换思路继续。
- **自行放行**：需要工具权限、沙箱、联网、安装依赖、跑 Godot/smoke 时，直接申请并继续（`required_permissions` 等），**不要**停下来等用户点允许或口头确认。
- **禁止** git commit / push（除非用户之后发 `1` 或另行明确要求）。
- **禁止**恢复波次「三选一」弹窗；仪式层仅开局/结算。
- 保持游戏菜单层级：大图、少字、主 CTA；改入口路径后更新 smoke。
- 引擎优先：`z_immortal/tools/godot/` 下的 Godot 4.x 可执行文件；主场景 `hub.tscn`，视口 640×360。找不到引擎就改代码+数据并记下验证缺口，不要停等。
- 新 PNG 后必须 Godot `--import`，再跑 smoke。
- 改完相关系统后尽量跑：`tools/smoke_test.gd`、`tools/combat_smoke.gd`；入口改了跑 `tools/entry_smoke.gd`。

## 优化罗盘（循环轮换，越做越长）

每轮选 **1 个主轴** 深做，再顺手修明显 bug，然后验证：

1. **好玩 / 上头**：前 10 分钟节奏、击杀反馈、成长可见、风险回报、新手引导不啰嗦。
2. **美观精致**：UI 层级、光影、角色比例、场景氛围、少卡片杂讯；遵循项目已有美术语言。
3. **人物建模 / 体型**：主角与小怪同屏可读；高清立绘按**目标身高**拟合（见 `player.gd` 的 `TARGET_VISUAL_H` / `_base_scale`）；禁止 squash/tween 回到 `Vector2.ONE`；hub 立绘与战斗体型职责分离；影子/血条/碰撞与视觉对齐。
4. **战斗玩法**：手感流畅、技能辨识、敌人行为差异、Boss 可读、难度曲线；攻击反馈不挡视野；受击/闪避/技能 CD 读得懂。
5. **卡顿 / 性能**：查 `hitstop`、`Engine.time_scale`、`wave_pause`、同步重活、每帧 `new`/大数组；控制同屏特效与全屏 Sprite overdraw；大贴图未缩放等于吃 GPU；粒子/残影有上限与回收。
6. **地图 / 关卡**：关卡差异、刷怪与击杀目标、背景与小地图、探索动机。
7. **前期留存**：宗门/王朝早期关、奖励可读、死亡不挫败、回到 hub 的欲望。
8. **代码规范**：改动局部、命名清晰、非显而易见逻辑补短注释；不扫射无关格式；不引入密钥；优先复用现有服务（`GameState` / `EventBus` / `ContentDB`）；动画改 scale 必须相对 `_base_scale` 或 `sprite_scale`。

内容可增长：新小怪变体、关卡参数、技能微调、视觉 polish；无音效资源时可跳过音效。

## 人物体型速查（易回归）

- 战斗主角：`scenes/world/combat.tscn` + `src/world/player.gd`（`TARGET_VISUAL_H`、`_apply_base_visual_scale`）。
- 小怪：`content/enemies.json` 的 `sprite_scale` + `src/world/mob.gd`。
- 验收：进关后主角约屏幕高度 1/4 内，不遮挡小怪与地面；放一次斩/环斩后体型不暴涨。

## 卡顿 / 卡住时

- 先查：`hitstop` / `Engine.time_scale` / `wave_pause` / 同步重活 / 每帧分配 / 未缩放巨型 Sprite。
- 工具失败：换命令或缩小复现，不要停等用户。
- 思路枯竭：读 `content/*.json` + 相关场景脚本，找最弱一环再改。
- Agent 回合结束时，若 Mode-2 会话仍有效，**stop hook** 会自动续跑；你只需在回合末留下「下一轮主轴」备忘（可写 `.cursor/mode2-next.md` 一行）。

## 暂停 / 停止

用户发以下任一消息时暂停 Mode-2：

- `3`（可带首尾空白）
- `stop` / `0`
- 「暂停」「暂停 Mode-2」「停止 Mode-2」

动作：

1. 执行 `node .cursor/hooks/mode2_disarm.js`（或 `python .cursor/hooks/mode2_disarm.py`）
2. 用几句话总结已做改动，然后结束自主循环

到点（`ends_at`）hook 不再续跑；可写短总结到 `.cursor/mode2-last-summary.md`（可选）。

## 回合节奏建议

- 单回合：改 1–3 个文件簇 → smoke → 记下下一刀。
- 不要空转长 sleep；用真实改动推进。
- 回复用户保持极短进度句即可（中文），不要征求意见。
