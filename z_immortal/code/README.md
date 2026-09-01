# 长生

2D 修仙 RPG，目标平台 Steam。引擎 **Godot 4.7**。玩法按 `design/sheets/` 里的 Excel 大纲来；**所有可调数字只放 `content/balance.json`**。

## 运行

1. 打开 Godot，导入 `code` 目录
2. 按 **F5**：先进入**宗门广场**，点「挑战关卡」选关，再进战斗
3. 战斗中 **Esc** 返回选关

### 流程

**广场** → **选关**（宗门→宇宙）→ **战斗**（刷怪、自动攻击）

### 操作（战斗内）

- `WASD` / 方向键：移动
- 靠近小怪自动出剑气
- `J`：吐纳加攻
- `K`：突破
- `R`：阵亡后重生
- `Esc`：返回选关

## 你改表、改数值的方式

继续用 Excel 五列写：**序号 / 模块 / 内容 / 详细 / 备注**。把文件放到 `design/sheets/`（现在是 `cultivation.xls`、`equipment.xls`、`gacha.xls`）。

然后在本目录执行：

```
python tools/import_sheets.py
```

这会生成 `content/design_notes.json`（设计大纲快照，游戏不直接当数值用）。

**改数字只改** [`content/balance.json`](content/balance.json)：

- 攻上限、是否通玄重置、每次吐纳加多少
- 智 1～100、防 1～100 及凡/灵/绝/玄区间
- 每个攻境的突破需求 `breakthrough_attack`
- 白色丹药 99% / 1% 等抽卡权重

文件里的 `_doc` 就是注释，改数字时不要删。改完回 Godot 按 F5 即可，不用改脚本。

境界名字、抽卡档位、装备来源分别在 `content/realms.json`、`gacha.json`、`equipment.json`。

## 为什么现在不用那台 MySQL

这是 Steam 单机（以后再考虑交易市场）。攻/智/防、突破、抽卡概率必须打进游戏包，才能离线玩、过 Steam Deck 审核，也不会因为服务器挂了整局不能开。

那台库以后如果要做这些再接：

- 账号登录
- 交易市场
- 全服排行

现在不要把数据库密码写进游戏或 Git。我在仓库里只放了 `.env.example` 模板。你贴出来的密码建议在云服务器上**改掉**，当作已经泄露。

本地若想练手 SQL，用 **SQLite** 一个文件即可，不必连远程。Navicat 连远程时：主机 `127.0.0.1` 先别填成生产库做数值调试。

## 目录

- `content/balance.json` — 唯一数值总表
- `content/*.json` — 境界 / 抽卡 / 装备 / 物品结构
- `design/sheets/` — 你的 Excel 原稿
- `tools/import_sheets.py` — Excel → 大纲 JSON
- `src/core/` — 规则（不挂场景）
- `src/data/` — 读表与运行时状态
- `src/steam/` — Steam 接口空壳

## Steam

垂直切片能玩之后，再用 [GodotSteam](https://godotsteam.com/) 替换 `src/steam/steam_service.gd`。
