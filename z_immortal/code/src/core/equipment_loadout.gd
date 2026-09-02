class_name EquipmentLoadout
extends RefCounted

## Three equipment slots. Item ids reference content/items.json equippable entries.

const SLOTS := ["weapon", "armor", "accessory"]

var weapon: String = ""
var armor: String = ""
var accessory: String = ""

func get_slot(slot: String) -> String:
	match slot:
		"weapon": return weapon
		"armor": return armor
		"accessory": return accessory
	return ""

func set_slot(slot: String, item_id: String) -> void:
	match slot:
		"weapon": weapon = item_id
		"armor": armor = item_id
		"accessory": accessory = item_id

func all_equipped() -> Dictionary:
	return { "weapon": weapon, "armor": armor, "accessory": accessory }

func from_dict(data: Dictionary) -> void:
	weapon = str(data.get("weapon", ""))
	armor = str(data.get("armor", ""))
	accessory = str(data.get("accessory", ""))

func to_dict() -> Dictionary:
	return all_equipped()

func bonus_stats() -> Dictionary:
	var atk := 0
	var def := 0
	var hp := 0
	var spd := 0.0
	for slot in SLOTS:
		var item_id := get_slot(slot)
		if item_id.is_empty():
			continue
		var item := ContentDB.get_item(item_id)
		if item == null:
			continue
		atk += item.bonus_attack
		def += item.bonus_defense
		hp += item.bonus_hp
		spd += item.bonus_speed_pct
	return { "attack": atk, "defense": def, "hp": hp, "speed_pct": spd }
