class_name StageDef
extends RefCounted

## One combat stage. Map theme and spawn list live here; global feel is in balance.json.

var id: String = ""
var display_name: String = ""
var description: String = ""
var order: int = 0
var next_id: String = ""
var kill_target: int = 10
var spawn_interval: float = 0.8
var max_alive: int = 14
var map: Dictionary = {}
var spawns: Array = []


static func from_dict(data: Dictionary) -> StageDef:
	var row := StageDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.description = str(data.get("description", ""))
	row.order = int(data.get("order", 0))
	row.next_id = str(data.get("next_id", ""))
	row.kill_target = int(data.get("kill_target", 10))
	row.spawn_interval = float(data.get("spawn_interval", 0.8))
	row.max_alive = int(data.get("max_alive", 14))
	var raw_map: Variant = data.get("map", {})
	row.map = raw_map if typeof(raw_map) == TYPE_DICTIONARY else {}
	var raw_spawns: Variant = data.get("spawns", [])
	row.spawns = raw_spawns if typeof(raw_spawns) == TYPE_ARRAY else []
	return row


func pick_enemy_id() -> String:
	var total := 0
	for raw in spawns:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		total += int(raw.get("weight", 0))
	if total <= 0:
		return ""
	var roll := randi() % total
	var acc := 0
	for raw in spawns:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		acc += int(raw.get("weight", 0))
		if roll < acc:
			return str(raw.get("enemy_id", ""))
	return ""
