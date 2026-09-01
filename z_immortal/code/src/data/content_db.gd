extends Node

## Loads JSON tables from res://content. Callers use typed lookups, not raw dicts.

var balance: Dictionary = {}
var realms := RealmTable.new()
var arts: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var gacha: Dictionary = {}
var equipment: Dictionary = {}
var stages := StageTable.new()


func _ready() -> void:
	reload()


func reload() -> void:
	balance = _load_json("res://content/balance.json")
	var realm_data: Dictionary = _load_json("res://content/realms.json")
	var realm_rows: Variant = realm_data.get("realms", [])
	if typeof(realm_rows) == TYPE_ARRAY:
		realms.load_from_array(realm_rows)
	else:
		push_error("ContentDB: 'realms' must be an array")
	arts = _index_rows("res://content/arts.json", "arts", Callable(ArtDef, "from_dict"))
	items = _index_rows("res://content/items.json", "items", Callable(ItemDef, "from_dict"))
	enemies = _index_rows("res://content/enemies.json", "enemies", Callable(EnemyDef, "from_dict"))
	gacha = _load_json("res://content/gacha.json")
	equipment = _load_json("res://content/equipment.json")
	var stage_data: Dictionary = _load_json("res://content/stages.json")
	var stage_rows: Variant = stage_data.get("stages", [])
	if typeof(stage_rows) == TYPE_ARRAY:
		stages.load_from_array(stage_rows)
	else:
		push_error("ContentDB: 'stages' must be an array")
	var start_id := str(section("start").get("attack_realm_id", "ninglu_chu"))
	if realms.get_realm(start_id) == null:
		push_error("ContentDB: missing start realm '%s'" % start_id)
	var start_stage := str(section("start").get("stage_id", "sect"))
	if stages.get_stage(start_stage) == null:
		push_error("ContentDB: missing start stage '%s'" % start_stage)


func section(name: String) -> Dictionary:
	var raw: Variant = balance.get(name, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func breakthrough_costs() -> Dictionary:
	return section("breakthrough_attack")


func get_art(id: String) -> ArtDef:
	return arts.get(id) as ArtDef


func get_item(id: String) -> ItemDef:
	return items.get(id) as ItemDef


func get_enemy(id: String) -> EnemyDef:
	return enemies.get(id) as EnemyDef


func get_stage(id: String) -> StageDef:
	return stages.get_stage(id)


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
