# 长生

2D 修仙 RPG 脚手架，目标平台 Steam。引擎为 **Godot 4.7**，玩法数值全部走 JSON 配置表。

## 运行

1. 安装 [Godot 4.7.x 稳定版](https://godotengine.org/download/windows/)（标准版即可，不需要 .NET / C#）。
2. 用 Godot 打开本目录（含 `project.godot` 的文件夹）。
3. 按 F5 运行。主场景是 `scenes/world/main.tscn`。

若本机已把编辑器解压到 `../tools/godot/`，也可以在该目录找到 `Godot_v4.7.2-stable_win64.exe`，用「导入」选择本项目。

### 操作

- `WASD` / 方向键：移动
- `J` 或空格：吐纳（按当前功法增加灵气）
- `K`：尝试突破到下一境界（灵气不足时不会升境）

## 目录

| 路径 | 职责 |
| --- | --- |
| `content/` | 境界、功法、物品、敌人配置表。加内容优先改这里 |
| `src/core/` | 纯规则：突破、吐纳、背包、战斗结算。不 `extends Node`，不引用场景 |
| `src/data/` | 读表、运行时状态 |
| `src/world/` | 地图、角色、NPC |
| `src/ui/` | HUD / 之后的背包、功法界面 |
| `src/steam/` | Steamworks 封装，开发期是 mock |
| `scenes/` | 场景与预制体 |
| `assets/` | 贴图、音频、字体 |

约定：新系统（炼丹、天劫、宗门）只加「一张表 + 一个 core 模块 + 必要时一个 UI 场景」。用 `EventBus` 通知表现层，不要让 UI 直接改玩家数值。

## 配置表格式

根对象里放一个数组。`id` 必须唯一。

`content/realms.json`：

```json
{
  "realms": [
    {
      "id": "qi_refining_1",
      "name": "炼气一层",
      "order": 1,
      "breakthrough_qi": 100,
      "description": "感应天地灵气，踏入修仙门槛。"
    }
  ]
}
```

`content/arts.json` 字段：`id`、`name`、`realm_req`、`qi_per_tick`、`description`。

`content/items.json` 字段：`id`、`name`、`kind`（`pill` / `material` / `weapon`）、`qi_restore`、`description`。

`content/enemies.json` 字段：`id`、`name`、`hp`、`attack`、`defense`、`realm_id`、`loot`。

改表后在编辑器里重新运行即可，不必改脚本。

## Steam

现在不要接 Steamworks。等垂直切片（走图、战斗、突破、存档）能玩之后，再用 [GodotSteam](https://godotsteam.com/) 替换 `src/steam/steam_service.gd` 的实现。成就、云存档只通过这一层调用。

## 下一步

- 把程序生成的色块地图换成正式 TileSet
- 战斗与掉落接到 `CombatResolver` / `enemies.json`
- 本地 JSON 存档（`user://`）
- 对话与任务表


## 启动
打开项目

运行 D:\design\design\z_immortal\tools\godot\Godot_v4.7.2-stable_win64.exe （你的 godot 安装目录 ）
如果弹出项目管理器，点 导入，选中文件夹 D:\design\design\z_immortal\code（里面有 project.godot）
再点 编辑
也可以把 code 文件夹直接拖到 Godot 图标上。

开始玩

进编辑器后按 F5（或点右上角播放按钮）
关掉游戏窗口回到编辑器：按 F8