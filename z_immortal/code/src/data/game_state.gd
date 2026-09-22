extends Node

const _Combat := preload("res://src/core/combat.gd")
const _StageRunScript := preload("res://src/core/stage_run.gd")

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
var combo: int = 0
var run = _StageRunScript.new()
var _boss_spawned_this_run: bool = false
var _last_kill_time: float = -999.0
## Last clear payout (UI); hub_celebrate drives return-to-spend flash.
var last_clear_stones: int = 0
var last_clear_first: bool = false
var last_clear_stage_id: String = ""
var hub_celebrate_stones: int = 0
var last_death_pity: int = 0
## Transient: hub「炼丹 · 花」→ alchemy shows「花石炼丹」tip (not saved).
var alchemy_flower_enter: bool = false
## Transient: hub「坊市 · 花」→ market shows「花石坊市」tip (not saved).
var market_flower_enter: bool = false
## Transient: hub「王朝 · 首通」→ stage select focuses country (not saved).
var stage_select_focus_id: String = ""
## Transient: hub challenge CTA → stage select shows「开战到手 · 选关」tip (not saved).
var hub_fight_enter: bool = false
## Transient: after dynasty「收刀」return → stage select tip echoes 收刀 (not saved).
var hub_shoudao_enter: bool = false
## Transient: stage-select「开战」→ combat start teal/gold handoff (not saved).
## Values: "" | "sect" | "country"
var combat_enter_handoff: String = ""

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
	return cultivation.attack + int(equipment_bonus().get("attack", 0)) + run.atk_bonus()

func effective_defense() -> int:
	return cultivation.defense + int(equipment_bonus().get("defense", 0))

func effective_speed_mult() -> float:
	return (1.0 + float(equipment_bonus().get("speed_pct", 0.0))) * run.speed_mult()

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
	# Spirit stones are currency — never stash as inventory rows.
	if item_id == "spirit_stones":
		add_spirit_stones(amount)
		if emit_event:
			EventBus.item_gained.emit(item_id, amount, "rare")
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
	EventBus.spirit_stones_gained.emit(amount)
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
	combo = 0
	_last_kill_time = -999.0
	run.reset(id)
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

func early_kill_hook() -> bool:
	# First minute of 宗门/王朝 — punchy kill read for early retention.
	return run_time < 60.0 and stage_id in ["sect", "country"]

func register_kill(enemy_id: String) -> void:
	kills[stage_id] = stage_kills() + 1
	_update_combo()
	_apply_kill_growth()
	EventBus.enemy_killed.emit(enemy_id, stage_id)
	var stage := current_stage()
	if stage:
		var wave := stage.current_wave(stage_kills())
		var hint := str(wave.get("hint", ""))
		if not hint.is_empty():
			EventBus.wave_changed.emit(hint)
		# Halfway ping on early maps — keeps forward momentum readable.
		var half := maxi(int(ceil(float(stage.kill_target) * 0.5)), 1)
		if stage_id in ["sect", "country"] and stage_kills() == half:
			EventBus.wave_changed.emit("半途 · 愈区可回血")
		if not _boss_spawned_this_run and not stage.boss_id.is_empty():
			var trigger := stage.boss_at_kill if stage.boss_at_kill > 0 else stage.kill_target - 1
			if stage_kills() >= trigger:
				_boss_spawned_this_run = true
				EventBus.boss_spawned.emit(stage.boss_id)
	if stage and stage_kills() == stage.kill_target:
		_complete_stage_unlock(stage)
	SaveService.save_game()

func _complete_stage_unlock(stage: StageDef) -> void:
	var nxt := ContentDB.get_stage(stage.next_id)
	# First clear = unlocking the next order (or final stage with no next).
	var first_clear := nxt == null or unlocked_order < nxt.order
	if nxt:
		unlocked_order = maxi(unlocked_order, nxt.order)
	_grant_stage_clear_reward(stage, first_clear)
	run.cleared_stage = true
	EventBus.stage_cleared.emit(stage_id)

func complete_run_stage() -> void:
	var stage := current_stage()
	if stage == null or run.cleared_stage:
		return
	_complete_stage_unlock(stage)
	SaveService.save_game()

func _grant_stage_clear_reward(stage: StageDef, first_clear: bool = true) -> void:
	var g := ContentDB.section("growth")
	var stones := int(g.get("stage_clear_stones_base", 15)) + stage.order * int(g.get("stage_clear_stones_per_order", 8))
	if first_clear:
		stones += int(g.get("stage_clear_first_bonus", 6))
	# Early stages pay a bit more so first clears pull players back to hub shops.
	if stage.id in ["sect", "country"]:
		stones += int(g.get("early_clear_stones_bonus", 6))
		if first_clear:
			stones += int(g.get("early_first_clear_extra", 8))
	last_clear_stones = stones
	last_clear_first = first_clear
	last_clear_stage_id = stage.id
	# Flag hub to flash spend CTAs when player returns with a fresh purse.
	if stage.id in ["sect", "country"] or first_clear:
		hub_celebrate_stones = stones
	add_spirit_stones(stones)
	EventBus.stage_reward.emit(stones)

func _update_combo() -> void:
	var window := float(ContentDB.section("combat").get("combo_window", 3.0))
	if run_time - _last_kill_time <= window:
		combo += 1
	else:
		combo = 1
	_last_kill_time = run_time
	# Dense early milestones so combo power reads every few kills.
	var hit := combo == 3 or combo == 5 or combo == 8
	hit = hit or (combo >= 10 and combo % 5 == 0)
	if hit:
		EventBus.combo_milestone.emit(combo)
		# Slightly meatier heal on shout beats — reward the streak.
		var heal_pct := 0.05
		if combo >= 8:
			heal_pct = 0.08
		elif combo >= 5:
			heal_pct = 0.06
		heal_amount(maxi(int(float(max_hp) * heal_pct), 1))
	elif combo == 2:
		# 二连 always cues — sect teal / dynasty gold short feedback, no heal.
		EventBus.combo_milestone.emit(combo)

func _apply_kill_growth() -> void:
	var g := ContentDB.section("growth")
	var kill_n := stage_kills()
	var w_every := int(g.get("kills_per_wisdom", 8))
	var d_every := int(g.get("kills_per_defense", 10))
	# Sect first: slightly faster visible growth.
	if stage_id == "sect":
		w_every = maxi(w_every - 1, 3)
		d_every = maxi(d_every - 1, 4)
	var w_max := int(ContentDB.section("wisdom").get("max_rank", 100))
	var d_max := int(ContentDB.section("defense").get("max", 100))
	if w_every > 0 and kill_n % w_every == 0 and cultivation.wisdom_rank < w_max:
		cultivation.wisdom_rank += 1
		EventBus.cultivation_stat_gained.emit("wisdom", cultivation.wisdom_rank)
		SaveService.save_game()
	if d_every > 0 and kill_n % d_every == 0 and cultivation.defense < d_max:
		cultivation.defense += 1
		recompute_max_hp()
		EventBus.cultivation_stat_gained.emit("defense", cultivation.defense)
		EventBus.player_hp_changed.emit(hp, max_hp)
		SaveService.save_game()

func revive() -> void:
	if not dead:
		return
	# Soft revive: keep kill progress and map state so early deaths aren't a full wipe.
	dead = false
	combo = 0
	_last_kill_time = -999.0
	refill_hp()
	# Early stages: soft power + free pill so retry feels hopeful, not punished.
	if stage_id in ["sect", "country"]:
		var g := ContentDB.section("growth")
		var dmg := float(g.get("early_revive_temp_damage", 0.08))
		var reduce := int(g.get("early_revive_hurt_reduce", 1))
		var effect := {}
		if dmg > 0.0 and float(run.run_buffs.get("temp_damage", 0.0)) < 0.2:
			effect["temp_damage"] = dmg
		if reduce > 0 and int(run.run_buffs.get("hurt_reduce", 0)) < 2:
			effect["hurt_reduce"] = reduce
		if not effect.is_empty():
			run.apply_effect(effect)
		var pill_id := str(g.get("early_revive_pill_id", "white_pill"))
		if not pill_id.is_empty() and inventory.count_of(pill_id) < 1:
			grant_item(pill_id, 1)
	EventBus.player_hp_changed.emit(hp, max_hp)

func apply_hurt(amount: int) -> void:
	if dead:
		return
	var reduced := maxi(amount - run.hurt_reduce(), 1) if amount > 0 else 0
	hp = maxi(hp - reduced, 0)
	EventBus.player_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		dead = true
		# Tiny pity once per stage entry — makes retry feel less empty.
		var g := ContentDB.section("growth")
		var pity := int(g.get("death_pity_stones", 2))
		if stage_id in ["sect", "country"]:
			pity += int(g.get("early_death_pity_bonus", 3))
		last_death_pity = 0
		if pity > 0 and not run.death_pity_given:
			run.death_pity_given = true
			last_death_pity = pity
			add_spirit_stones(pity)
			# Early deaths still feed the hub spend loop — purse flash on return.
			if stage_id in ["sect", "country"]:
				hub_celebrate_stones = maxi(hub_celebrate_stones, pity)
			EventBus.death_pity_gained.emit(pity)
		EventBus.player_died.emit()

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
	var combo_bonus := 1.0 + float(mini(combo, 20)) * float(cbt.get("combo_damage_per_stack", 0.02))
	var crisis := 1.0
	if max_hp > 0 and float(hp) / float(max_hp) <= 0.3:
		crisis = float(cbt.get("low_hp_damage_mult", 1.2))
	return maxi(int(float(base) * mult * run.damage_mult() * combo_bonus * crisis), 1)

func combo_mult() -> float:
	var cbt := ContentDB.section("combat")
	return 1.0 + float(mini(combo, 20)) * float(cbt.get("combo_damage_per_stack", 0.02))
