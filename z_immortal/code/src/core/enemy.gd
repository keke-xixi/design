class_name EnemyDef
extends RefCounted

## Enemy template from content/enemies.json. Combat is not wired yet.

var id: String = ""
var display_name: String = ""
var hp: int = 0
var attack: int = 0
var defense: int = 0
var realm_id: String = ""
var loot: Array = []


static func from_dict(data: Dictionary) -> EnemyDef:
	var row := EnemyDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.hp = int(data.get("hp", 0))
	row.attack = int(data.get("attack", 0))
	row.defense = int(data.get("defense", 0))
	row.realm_id = str(data.get("realm_id", ""))
	var raw_loot: Variant = data.get("loot", [])
	row.loot = raw_loot if typeof(raw_loot) == TYPE_ARRAY else []
	return row
