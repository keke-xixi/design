class_name EnemyDef
extends RefCounted

## Enemy template from content/enemies.json.

var id: String = ""
var display_name: String = ""
var hp: int = 0
var attack: int = 0
var defense: int = 0
var speed: float = 40.0
var size: float = 6.0
var color: String = "#888888"
var sprite: String = "mob_disciple.png"
var sprite_scale: float = 0.05
var xp_attack: int = 1
var is_boss: bool = false
var loot: Array = []
var boss_skill: Dictionary = {}
var ai: String = "chase"

static func from_dict(data: Dictionary) -> EnemyDef:
	var row := EnemyDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.hp = int(data.get("hp", 0))
	row.attack = int(data.get("attack", 0))
	row.defense = int(data.get("defense", 0))
	row.speed = float(data.get("speed", 40))
	row.size = float(data.get("size", 6))
	row.color = str(data.get("color", "#888888"))
	row.sprite = str(data.get("sprite", "mob_disciple.png"))
	row.sprite_scale = float(data.get("sprite_scale", 0.05))
	row.xp_attack = int(data.get("xp_attack", 1))
	row.is_boss = bool(data.get("is_boss", false))
	row.ai = str(data.get("ai", "chase"))
	var raw_loot: Variant = data.get("loot", [])
	row.loot = raw_loot if typeof(raw_loot) == TYPE_ARRAY else []
	var raw_skill: Variant = data.get("boss_skill", {})
	row.boss_skill = raw_skill if typeof(raw_skill) == TYPE_DICTIONARY else {}
	return row
