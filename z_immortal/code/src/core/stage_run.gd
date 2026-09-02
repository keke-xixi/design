extends RefCounted

## Per-run node progress for a stage (trial / event / rest / boss).

enum Phase { INTRO, PLAYING, CLEARING, CHOICE, EVENT, REST, RESULT, DONE }

var stage_id: String = ""
var node_index: int = 0
var node_kills: int = 0
var phase: int = Phase.INTRO
var paused_spawn: bool = true
var run_buffs: Dictionary = {
	"temp_atk": 0,
	"temp_damage": 0.0,
	"temp_speed": 0.0,
	"hurt_reduce": 0,
}
var pending_choices: Array = []
var last_title: String = ""
var cleared_stage: bool = false

func reset(for_stage_id: String) -> void:
	stage_id = for_stage_id
	node_index = 0
	node_kills = 0
	phase = Phase.INTRO
	paused_spawn = true
	run_buffs = { "temp_atk": 0, "temp_damage": 0.0, "temp_speed": 0.0, "hurt_reduce": 0 }
	pending_choices.clear()
	last_title = ""
	cleared_stage = false

func stage() -> StageDef:
	return ContentDB.get_stage(stage_id)

func nodes() -> Array:
	var s := stage()
	return s.nodes if s else []

func current_node() -> Dictionary:
	var list := nodes()
	if node_index < 0 or node_index >= list.size():
		return {}
	var raw: Variant = list[node_index]
	return raw if typeof(raw) == TYPE_DICTIONARY else {}

func node_count() -> int:
	return nodes().size()

func has_nodes() -> bool:
	return node_count() > 0

func node_type() -> String:
	return str(current_node().get("type", "trial"))

func kill_goal() -> int:
	return int(current_node().get("kill_goal", 8))

func apply_effect(effect: Dictionary) -> void:
	if effect.is_empty():
		return
	var heal_pct := float(effect.get("heal_pct", 0.0))
	if heal_pct != 0.0:
		var amount := int(float(GameState.max_hp) * heal_pct)
		if amount >= 0:
			GameState.heal_amount(amount)
		else:
			GameState.apply_hurt(-amount)
	var stones := int(effect.get("stones", 0))
	if stones > 0:
		GameState.add_spirit_stones(stones)
	elif stones < 0:
		GameState.spirit_stones = maxi(GameState.spirit_stones + stones, 0)
	var item_id := str(effect.get("item_id", ""))
	var item_amount := int(effect.get("item_amount", 0))
	if not item_id.is_empty() and item_amount > 0:
		GameState.grant_item(item_id, item_amount)
	run_buffs["temp_atk"] = int(run_buffs.get("temp_atk", 0)) + int(effect.get("temp_atk", 0))
	run_buffs["temp_damage"] = float(run_buffs.get("temp_damage", 0.0)) + float(effect.get("temp_damage", 0.0))
	run_buffs["temp_speed"] = float(run_buffs.get("temp_speed", 0.0)) + float(effect.get("temp_speed", 0.0))
	run_buffs["hurt_reduce"] = int(run_buffs.get("hurt_reduce", 0)) + int(effect.get("hurt_reduce", 0))

func damage_mult() -> float:
	return 1.0 + float(run_buffs.get("temp_damage", 0.0))

func speed_mult() -> float:
	return 1.0 + float(run_buffs.get("temp_speed", 0.0))

func atk_bonus() -> int:
	return int(run_buffs.get("temp_atk", 0))

func hurt_reduce() -> int:
	return int(run_buffs.get("hurt_reduce", 0))
