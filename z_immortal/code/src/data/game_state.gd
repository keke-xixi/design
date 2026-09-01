extends Node

const _Combat := preload("res://src/core/combat.gd")

## Runtime player state. Survives scene changes; not a save file yet.

var cultivation: CultivationState
var inventory: Inventory
var hp: int = 1
var max_hp: int = 1
var dead: bool = false
var stage_id: String = "sect"
var unlocked_order: int = 1
var kills: Dictionary = {}
var run_time: float = 0.0


func _ready() -> void:
	cultivation = CultivationState.new()
	inventory = Inventory.new()
	var start := ContentDB.section("start")
	cultivation.attack = int(start.get("attack", 1))
	cultivation.wisdom_rank = int(start.get("wisdom_rank", 1))
	cultivation.defense = int(start.get("defense", 1))
	cultivation.attack_realm_id = str(start.get("attack_realm_id", "ninglu_chu"))
	stage_id = str(start.get("stage_id", "sect"))
	var stage := ContentDB.get_stage(stage_id)
	if stage:
		unlocked_order = stage.order
	refill_hp()


func current_stage() -> StageDef:
	return ContentDB.get_stage(stage_id)


func stage_kills() -> int:
	return int(kills.get(stage_id, 0))


func is_stage_cleared(id: String = "") -> bool:
	var sid := id if not id.is_empty() else stage_id
	var stage := ContentDB.get_stage(sid)
	if stage == null:
		return false
	return int(kills.get(sid, 0)) >= stage.kill_target


func can_enter(stage: StageDef) -> bool:
	return stage != null and stage.order <= unlocked_order


func enter_stage(id: String) -> bool:
	var stage := ContentDB.get_stage(id)
	if not can_enter(stage):
		return false
	stage_id = id
	dead = false
	run_time = 0.0
	refill_hp()
	EventBus.stage_changed.emit(stage_id)
	return true


func try_next_stage() -> bool:
	var stage := current_stage()
	if stage == null or stage.next_id.is_empty():
		return false
	if not is_stage_cleared():
		return false
	return enter_stage(stage.next_id)


func cycle_stage(delta_order: int) -> bool:
	var stage := current_stage()
	if stage == null:
		return false
	var next := ContentDB.stages.get_by_order(stage.order + delta_order)
	if not can_enter(next):
		return false
	return enter_stage(next.id)


func register_kill(enemy_id: String) -> void:
	kills[stage_id] = stage_kills() + 1
	EventBus.enemy_killed.emit(enemy_id, stage_id)
	var stage := current_stage()
	if stage and stage_kills() == stage.kill_target:
		var nxt := ContentDB.get_stage(stage.next_id)
		if nxt:
			unlocked_order = maxi(unlocked_order, nxt.order)
		EventBus.stage_cleared.emit(stage_id)


func apply_hurt(amount: int) -> void:
	if dead:
		return
	hp = maxi(hp - maxi(amount, 0), 0)
	EventBus.player_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		dead = true
		EventBus.player_died.emit()


func revive() -> void:
	dead = false
	run_time = 0.0
	refill_hp()
	EventBus.stage_changed.emit(stage_id)


func recompute_max_hp() -> void:
	var cbt := ContentDB.section("combat")
	max_hp = _Combat.player_max_hp(
		int(cbt.get("hp_base", 80)),
		cultivation.defense,
		int(cbt.get("hp_per_defense", 18)),
	)


func refill_hp() -> void:
	recompute_max_hp()
	hp = max_hp
	EventBus.player_hp_changed.emit(hp, max_hp)


func cultivate_attack() -> int:
	return cultivate_attack_amount(int(ContentDB.section("attack").get("cultivate_gain", 0)))


func cultivate_attack_amount(gain: int) -> int:
	var atk := ContentDB.section("attack")
	var cap := cultivation.attack_cap(int(atk.get("mortal_max", 1)), int(atk.get("mystic_max", 1)), ContentDB.realms)
	var gained := cultivation.cultivate_attack(gain, int(atk.get("min", 1)), cap)
	if gained > 0:
		EventBus.attack_gained.emit(gained, cultivation.attack)
	return gained


func try_breakthrough() -> Dictionary:
	var atk := ContentDB.section("attack")
	var result := cultivation.try_breakthrough(
		ContentDB.realms,
		ContentDB.breakthrough_costs(),
		bool(atk.get("mystic_resets_attack", true)),
		int(atk.get("mystic_start", 1)),
	)
	if bool(result.get("ok", false)):
		EventBus.cultivation_broke_through.emit(str(result.get("realm_id", "")))
	return result


func projectile_damage_against(enemy_def: int) -> int:
	var cbt := ContentDB.section("combat")
	return _Combat.hit_damage(
		cultivation.attack,
		enemy_def,
		int(cbt.get("damage_flat", 8)),
		float(cbt.get("damage_per_attack", 1)),
	)
