extends Node

## Loads JSON tables from res://content. Callers use typed lookups, not raw dicts.

var realms := RealmTable.new()
var arts: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	var realm_data: Dictionary = _load_json("res://content/realms.json")
	var realm_rows: Variant = realm_data.get("realms", [])
	if typeof(realm_rows) == TYPE_ARRAY:
		realms.load_from_array(realm_rows)
	else:
		push_error("ContentDB: 'realms' must be an array")
	arts = _index_rows("res://content/arts.json", "arts", Callable(ArtDef, "from_dict"))
	items = _index_rows("res://content/items.json", "items", Callable(ItemDef, "from_dict"))
	enemies = _index_rows("res://content/enemies.json", "enemies", Callable(EnemyDef, "from_dict"))
	if realms.get_realm("mortal") == null:
		push_error("ContentDB: missing required realm 'mortal'")


func get_art(id: String) -> ArtDef:
	return arts.get(id) as ArtDef


func get_item(id: String) -> ItemDef:
	return items.get(id) as ItemDef


func get_enemy(id: String) -> EnemyDef:
	return enemies.get(id) as EnemyDef


func _index_rows(path: String, key: String, mapper: Callable) -> Dictionary:
	var data: Dictionary = _load_json(path)
	var indexed: Dictionary = {}
	var rows: Variant = data.get(key, [])
	if typeof(rows) != TYPE_ARRAY:
		push_error("ContentDB: '%s' in %s is not an array" % [key, path])
		return indexed
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: RefCounted = mapper.call(raw)
		var id := str(row.get("id"))
		if id.is_empty():
			push_error("ContentDB: empty id in %s" % path)
			continue
		if indexed.has(id):
			push_error("ContentDB: duplicate id '%s' in %s" % [id, path])
			continue
		indexed[id] = row
	return indexed


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ContentDB: missing file %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ContentDB: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ContentDB: root of %s must be an object" % path)
		return {}
	return parsed
