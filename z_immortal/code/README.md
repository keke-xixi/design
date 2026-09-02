# 通玄之上

2D 修仙 RPG，目标平台 Steam。引擎 **Godot 4.7**。世界观参考《万古神帝》式多层宇宙：**宗门 → 王朝 → 荒星 → 星域 → 界域 → 混沌星海**，以「通玄」为凡与玄的分界。

**所有可调数字只放 `content/balance.json`**。

## 运行

1. 打开 Godot，导入 `code` 目录
2. 按 **F5**：先进**宗门广场** → **挑战关卡** → 选关进入战斗
3. 战斗中 **Esc** 返回选关；进度自动保存至 `user://save.json`

### 视觉资源

- 首页 / 选关 / 六关背景：`assets/backgrounds/`
- 清晰角色：`assets/characters/*_clear.png`
- 重新生成美术：`python tools/generate_art.py`

### 流程

**广场**（境界、灵石、背包摘要）→ **选关**（波次 + Boss + lore）→ **战斗**（掉落宝物）→ **通玄坊**（交易市场）

### 宝物与交易

- 击杀怪物概率掉落物品（common → legendary），Boss 必掉稀有宝 + 灵石
- 广场 **通玄坊 · 交易**：购买、回收、上架
- 广场 **装备**：武器/防具/饰品三槽，穿戴加成攻防血速
- 广场 **炼丹**：配方炼制 + 灵石抽卡（白丹/兵器池）
- 配置：`content/items.json`、`content/alchemy.json`、`content/skills.json`

### 战斗技能（快捷键）

| 键 | 技能 | 说明 |
|----|------|------|
| L | 闪避 | 瞬移 + 短暂无敌 |
| U | 环斩 | 范围 AOE |
| I | 服丹 | 消耗背包丹药回血 |
| O | 灵爆 | 八方剑气 |
| J/K | 吐纳/突破 | 修炼 |

右上角 **小地图** 显示玩家、怪物、障碍与 Boss（大点）。

### 操作（战斗内）

- `WASD`：移动，靠近自动攻击
- `J` / `K`：吐纳 / 突破
- `R`：重生
- `Esc`：返回选关

## 世界观与文案

- 总览：`content/lore.json`（tagline、intro、六层说明）
- 关卡 lore：`content/stages.json` 每关 `lore` 字段
- 攻境名称：`content/realms.json`（通玄之下 / 通玄之上）

## 你改表、改数值的方式

继续用 Excel 五列写：**序号 / 模块 / 内容 / 详细 / 备注**。把文件放到 `design/sheets/`。

```
python tools/import_sheets.py
```

这会生成 `content/design_notes.json`（设计大纲快照，游戏不直接当数值用）。

**改数字只改** [`content/balance.json`](content/balance.json)：

- 攻上限、是否通玄重置、每次吐纳加多少
- 智 1～100、防 1～100 及凡/灵/绝/玄区间
- 每个攻境的突破需求 `breakthrough_attack`
- 战斗手感：`combat` 段（移速、刷怪、伤害、灵气吸附）

改完回 Godot 按 F5 即可，不用改脚本。

## 目录

- `content/balance.json` — 唯一数值总表
- `content/lore.json` — 世界观文案
- `content/*.json` — 境界 / 关卡 / 抽卡 / 装备
- `design/sheets/` — Excel 原稿
- `tools/import_sheets.py` — Excel → 大纲 JSON
- `tools/generate_art.py` — 程序化背景与角色
- `src/core/` — 规则（不挂场景）
- `src/data/` — 读表、存档、运行时状态
- `src/ui/` — HUD、选关、飘字
- `src/steam/` — Steam 接口空壳

## Steam

垂直切片能玩之后，再用 [GodotSteam](https://godotsteam.com/) 替换 `src/steam/steam_service.gd`。
