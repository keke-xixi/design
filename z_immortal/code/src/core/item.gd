class_name ItemDef
extends RefCounted

## Item / pill / material / treasure from content/items.json.

var id: String = ""
var display_name: String = ""
var kind: String = ""
var rarity: String = "common"
var qi_restore: int = 0
var value: int = 0
var tradeable: bool = true
var equip_slot: String = ""
var bonus_attack: int = 0
var bonus_defense: int = 0
var bonus_hp: int = 0
var bonus_speed_pct: float = 0.0
var description: String = ""


static func from_dict(data: Dictionary) -> ItemDef:
	var row := ItemDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.kind = str(data.get("kind", ""))
	row.rarity = str(data.get("rarity", "common"))
	row.qi_restore = int(data.get("qi_restore", 0))
	row.value = int(data.get("value", 0))
	row.tradeable = bool(data.get("tradeable", true))
	row.equip_slot = str(data.get("equip_slot", ""))
	row.bonus_attack = int(data.get("bonus_attack", 0))
	row.bonus_defense = int(data.get("bonus_defense", 0))
	row.bonus_hp = int(data.get("bonus_hp", 0))
	row.bonus_speed_pct = float(data.get("bonus_speed_pct", 0.0))
	row.description = str(data.get("description", ""))
	return row
