extends Node

## Local save to user://save.json. Steam Cloud can wrap this later.

const PATH := "user://save.json"


func _ready() -> void:
	if has_save():
		load_game()
	else:
		_grant_starters()


func _grant_starters() -> void:
	var raw: Variant = ContentDB.section("start").get("starter_inventory", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in raw.keys():
		var item_id := str(key)
		var qty := int(raw[key])
		if qty > 0:
			GameState.grant_item(item_id, qty, false)
	if GameState.inventory.count_of("wooden_sword") > 0:
		GameState.equip_item("wooden_sword")
	if GameState.inventory.count_of("sect_robe") > 0:
		GameState.equip_item("sect_robe")
	save_game()


func save_game() -> void:
	var data := GameState.to_save_dict()
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)


func load_game() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	GameState.from_save_dict(parsed)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(PATH)
