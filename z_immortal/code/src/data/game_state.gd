extends Node

const _Combat := preload("res://src/core/combat.gd")

var cultivation: CultivationState
var inventory: Inventory
var equipment: EquipmentLoadout
var hp: int = 1
var max_hp: int = 1
var dead: bool = false
var stage_id: String = "sect"
var unlocked_order: int = 1
var kills: Dictionary = {}
var run_time: float = 0.0
var spirit_stones: int = 0
var _boss_spawned_this_run: bool = false


func _ready() -> void:
	cultivation = CultivationState.new()
	inventory = Inventory.new()
	equipment = EquipmentLoadout.new()
	var start := ContentDB.section("start")
	cultivation.attack = int(start.get("attack", 1))
	cultivation.wisdom_rank = int(start.get("wisdom_rank", 1))
	cultivation.defense = int(start.get("defense", 1))
	cultivation.attack_realm_id = str(start.get("attack_realm_id", "ninglu_chu"))
	stage_id = str(start.get("stage_id", "sect"))
	spirit_stones = int(start.get("spirit_stones", 0))
	var stage := ContentDB.get_stage(stage_id)
	if stage:
		unlocked_order = stage.order
	refill_hp()


func equipment_bonus() -> Dictionary:
	return equipment.bonus_stats()


func effective_attack() -> int:
	return cultivation.attack + int(equipment_bonus().get("attack", 0))


func effective_defense() -> int:
	return cultivation.defense + int(equipment_bonus().get("defense", 0))


func effective_speed_mult() -> float:
	return 1.0 + float(equipment_bonus().get("speed_pct", 0.0))


func equip_item(item_id: String) -> bool:
	var item := ContentDB.get_item(item_id)
	if item == null or item.equip_slot.is_empty():
		return false
	if inventory.count_of(item_id) < 1:
		return false
	var old_hp_ratio := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	equipment.set_slot(item.equip_slot, item_id)
	recompute_max_hp()
	hp = clampi(int(float(max_hp) * old_hp_ratio), 1, max_hp)
	EventBus.player_hp_changed.emit(hp, max_hp)
	EventBus.equipment_changed.emit()
	SaveService.save_game()
	return true


func unequip_slot(slot: String) -> bool:
	if not slot in EquipmentLoadout.SLOTS:
		return false
	var old_hp_ratio := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	equipment.set_slot(slot, "")
	recompute_max_hp()
	hp = clampi(int(float(max_hp) * old_hp_ratio), 1, max_hp)
	EventBus.player_hp_changed.emit(hp, max_hp)
	EventBus.equipment_changed.emit()
	SaveService.save_game()
	return true


func to_save_dict() -> Dictionary:
	return {
		"attack": cultivation.attack,
		"wisdom_rank": cultivation.wisdom_rank,
		"defense": cultivation.defense,
		"attack_realm_id": cultivation.attack_realm_id,
		"stage_id": stage_id,
		"unlocked_order": unlocked_order,
		"kills": kills.duplicate(),
		"spirit_stones": spirit_stones,
		"inventory": inventory.all_counts(),
		"equipment": equipment.to_dict(),
	}


func from_save_dict(data: Dictionary) -> void:
	cultivation.attack = int(data.get("attack", cultivation.attack))
	cultivation.wisdom_rank = int(data.get("wisdom_rank", cultivation.wisdom_rank))
	cultivation.defense = int(data.get("defense", cultivation.defense))
	cultivation.attack_realm_id = str(data.get("attack_realm_id", cultivation.attack_realm_id))
	stage_id = str(data.get("stage_id", stage_id))
	unlocked_order = int(data.get("unlocked_order", unlocked_order))
	var raw_kills: Variant = data.get("kills", {})
	if typeof(raw_kills) == TYPE_DICTIONARY:
		kills = raw_kills.duplicate()
	spirit_stones = int(data.get("spirit_stones", spirit_stones))
	var raw_inv: Variant = data.get("inventory", {})
	if typeof(raw_inv) == TYPE_DICTIONARY:
		inventory = Inventory.new()
		for key in raw_inv.keys():
			inventory.add(str(key), int(raw_inv[key]))
	var raw_eq: Variant = data.get("equipment", {})
	if typeof(raw_eq) == TYPE_DICTIONARY:
		equipment.from_dict(raw_eq)
	refill_hp()


func grant_item(item_id: String, amount: int = 1, emit_event: bool = true) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	inventory.add(item_id, amount)
	if emit_event:
		var item := ContentDB.get_item(item_id)
		var rarity := item.rarity if item else "common"
		EventBus.item_gained.emit(item_id, amount, rarity)
		SaveService.save_game()


func add_spirit_stones(amount: int) -> void:
	if amount <= 0:
		return
	spirit_stones += amount
	SaveService.save_game()


func heal_amount(amount: int) -> int:
	if dead:
		return 0
	var before := hp
	hp = mini(hp + maxi(amount, 0), max_hp)
	EventBus.player_hp_changed.emit(hp, max_hp)
	return hp - before


func use_pill_from_inventory(priority: Array) -> Dictionary:
	for raw in priority:
		var item_id := str(raw)
		if inventory.count_of(item_id) < 1:
			continue
		var item := ContentDB.get_item(item_id)
		if item == null or item.qi_restore <= 0:
			continue
		inventory.remove(item_id, 1)
		var healed := heal_amount(item.qi_restore)
		SaveService.save_game()
		return { "ok": true, "item_id": item_id, "healed": healed }
	return { "ok": false, "reason": "no_pill" }


func realm_band_name() -> String:
	var realm := ContentDB.realms.get_realm(cultivation.attack_realm_id)
	if realm == null:
		return "未知"
	return "通玄之上" if realm.band == "mystic" else "通玄之下"


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
	_boss_spawned_this_run = false
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
	if stage:
		var wave := stage.current_wave(stage_kills())
		var hint := str(wave.get("hint", ""))
		if not hint.is_empty():
			EventBus.wave_changed.emit(hint)
		if not _boss_spawned_this_run and not stage.boss_id.is_empty():
			var trigger := stage.boss_at_kill if stage.boss_at_kill > 0 else stage.kill_target - 1
			if stage_kills() >= trigger:
				_boss_spawned_this_run = true
				EventBus.boss_spawned.emit(stage.boss_id)
	if stage and stage_kills() == stage.kill_target:
		var nxt := ContentDB.get_stage(stage.next_id)
		if nxt:
			unlocked_order = maxi(unlocked_order, nxt.order)
		EventBus.stage_cleared.emit(stage_id)
	SaveService.save_game()


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
	var bonus := equipment_bonus()
	max_hp = _Combat.player_max_hp(
		int(cbt.get("hp_base", 80)),
		effective_defense(),
		int(cbt.get("hp_per_defense", 18)),
	) + int(bonus.get("hp", 0))


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
		if bool(result.get("reset_attack", false)):
			EventBus.mystic_crossed.emit()
		EventBus.cultivation_broke_through.emit(str(result.get("realm_id", "")))
		SaveService.save_game()
	return result


func projectile_damage_against(enemy_def: int, mult: float = 1.0) -> int:
	var cbt := ContentDB.section("combat")
	var base := _Combat.hit_damage(
		effective_attack(),
		enemy_def,
		int(cbt.get("damage_flat", 8)),
		float(cbt.get("damage_per_attack", 1)),
	)
	return maxi(int(float(base) * mult), 1)
