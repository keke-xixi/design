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
var lore: String = ""
var accent: String = "#d4af37"
var boss_id: String = ""
var boss_at_kill: int = 0
var waves: Array = []
var map: Dictionary = {}
var spawns: Array = []
var nodes: Array = []

static func from_dict(data: Dictionary) -> StageDef:
	var row := StageDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.description = str(data.get("description", ""))
	row.lore = str(data.get("lore", ""))
	row.order = int(data.get("order", 0))
	row.next_id = str(data.get("next_id", ""))
	row.kill_target = int(data.get("kill_target", 10))
	row.spawn_interval = float(data.get("spawn_interval", 0.8))
	row.max_alive = int(data.get("max_alive", 14))
	row.accent = str(data.get("accent", "#d4af37"))
	row.boss_id = str(data.get("boss_id", ""))
	row.boss_at_kill = int(data.get("boss_at_kill", 0))
	var raw_waves: Variant = data.get("waves", [])
	row.waves = raw_waves if typeof(raw_waves) == TYPE_ARRAY else []
	var raw_map: Variant = data.get("map", {})
	row.map = raw_map if typeof(raw_map) == TYPE_DICTIONARY else {}
	var raw_spawns: Variant = data.get("spawns", [])
	row.spawns = raw_spawns if typeof(raw_spawns) == TYPE_ARRAY else []
	var raw_nodes: Variant = data.get("nodes", [])
	row.nodes = raw_nodes if typeof(raw_nodes) == TYPE_ARRAY else []
	return row

func has_nodes() -> bool:
	return not nodes.is_empty()

func background_path() -> String:
	var file_name := str(map.get("background", ""))
	if file_name.is_empty():
		return ""
	return "res://assets/backgrounds/%s" % file_name

func pick_enemy_id() -> String:
	return _pick_from_spawns(spawns)

func current_wave(kills: int) -> Dictionary:
	if waves.is_empty():
		return {}
	var current: Dictionary = {}
	for raw in waves:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if kills >= int(raw.get("at_kills", 0)):
			current = raw
	return current

func spawn_interval_for(kills: int) -> float:
	var wave := current_wave(kills)
	var mult := float(wave.get("spawn_interval_mult", 1.0))
	return spawn_interval * mult

func max_alive_for(kills: int) -> int:
	var wave := current_wave(kills)
	return max_alive + int(wave.get("max_alive_bonus", 0))

func wave_hint(kills: int) -> String:
	var wave := current_wave(kills)
	return str(wave.get("hint", ""))

func _pick_from_spawns(pool: Array) -> String:
	var total := 0
	for raw in pool:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		total += int(raw.get("weight", 0))
	if total <= 0:
		return ""
	var roll := randi() % total
	var acc := 0
	for raw in pool:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		acc += int(raw.get("weight", 0))
		if roll < acc:
			return str(raw.get("enemy_id", ""))
	return ""
