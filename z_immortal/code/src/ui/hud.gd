extends CanvasLayer

const _DefenseBands := preload("res://src/core/defense_bands.gd")

@onready var _stage_label: Label = $Root/TopBar/Panel/StageLabel
@onready var _hp_label: Label = $Root/TopBar/Panel/HpLabel
@onready var _kill_label: Label = $Root/TopBar/Panel/KillLabel
@onready var _realm_label: Label = $Root/TopBar/Panel/RealmLabel
@onready var _attack_label: Label = $Root/TopBar/Panel/AttackLabel
@onready var _wisdom_label: Label = $Root/TopBar/Panel/WisdomLabel
@onready var _defense_label: Label = $Root/TopBar/Panel/DefenseLabel
@onready var _hint_label: Label = $Root/HintLabel
@onready var _portrait: TextureRect = $Root/Portrait
@onready var _clear: Label = $Root/ClearBanner
@onready var _stones_label: Label = $Root/TopBar/Panel/StonesLabel
@onready var _skill_l: Label = $Root/SkillBar/SkillL
@onready var _skill_u: Label = $Root/SkillBar/SkillU
@onready var _skill_i: Label = $Root/SkillBar/SkillI
@onready var _skill_o: Label = $Root/SkillBar/SkillO

const _SKILL_IDS := ["dash", "ring_slash", "use_pill", "spirit_burst"]
const _SKILL_LABELS := ["L闪避", "U环斩", "I服丹", "O灵爆"]


func _ready() -> void:
	EventBus.cultivation_broke_through.connect(_on_broke)
	EventBus.mystic_crossed.connect(_on_mystic)
	EventBus.attack_gained.connect(_on_attack)
	EventBus.enemy_killed.connect(_on_kill)
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.player_died.connect(_on_any_noargs)
	EventBus.stage_changed.connect(_on_stage)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.wave_changed.connect(_on_wave)
	EventBus.boss_spawned.connect(_on_boss)
	EventBus.item_gained.connect(_on_item)
	EventBus.equipment_changed.connect(_on_equipment)
	var tex := load("res://assets/portraits/player.png")
	if tex and _portrait:
		_portrait.texture = tex
	_clear.visible = false
	_refresh()


func _process(_delta: float) -> void:
	_update_skill_bar()


func _update_skill_bar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var labels := [_skill_l, _skill_u, _skill_i, _skill_o]
	for i in _SKILL_IDS.size():
		var base := _SKILL_LABELS[i] if i < _SKILL_LABELS.size() else _SKILL_IDS[i]
		var cd_left := 0.0
		if player and player.has_method("get_skill_cooldown"):
			cd_left = player.get_skill_cooldown(_SKILL_IDS[i])
		if cd_left > 0.05:
			labels[i].text = "%s %.1fs" % [base, cd_left]
			labels[i].modulate = Color(0.55, 0.6, 0.65)
		else:
			labels[i].text = base
			labels[i].modulate = Color(0.85, 0.92, 0.98)


func _on_equipment() -> void:
	_refresh()


func show_clear(custom: String = "") -> void:
	_clear.text = custom if not custom.is_empty() else "本层已破 · 通玄之路更进一步"
	_clear.visible = true
	_clear.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_clear, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: _clear.visible = false)


func _on_mystic() -> void:
	_clear.text = "踏入通玄之上！"
	show_clear()
	_refresh()


func _on_broke(_new_realm_id: String) -> void:
	_refresh()


func _on_attack(_amount: int, _total: int) -> void:
	_refresh()


func _on_kill(_enemy_id: String, _stage_id: String) -> void:
	_refresh()


func _on_hp(_hp: int, _max_hp: int) -> void:
	_refresh()


func _on_any_noargs() -> void:
	_refresh()


func _on_stage(_stage_id: String) -> void:
	_clear.visible = false
	_wave_label.text = ""
	_refresh()


func _on_wave(hint: String) -> void:
	_wave_label.text = hint


func _on_boss(enemy_id: String) -> void:
	var enemy := ContentDB.get_enemy(enemy_id)
	var name := enemy.display_name if enemy else enemy_id
	_wave_label.text = "Boss · %s" % name
	show_clear("%s 降临！" % name)


func _on_item(_item_id: String, _amount: int, _rarity: String) -> void:
	_refresh()


func _on_cleared(_stage_id: String) -> void:
	show_clear()
	_refresh()


func _refresh() -> void:
	var c := GameState.cultivation
	var stage := GameState.current_stage()
	var stage_name := stage.display_name if stage else GameState.stage_id
	var band := GameState.realm_band_name()
	if stage and not stage.lore.is_empty():
		_stage_label.text = "%s · %s" % [stage_name, band]
	else:
		_stage_label.text = "关卡  %s · %s" % [stage_name, band]
	_hp_label.text = "气血  %d / %d" % [GameState.hp, GameState.max_hp]
	if stage:
		_kill_label.text = "杀敌  %d / %d" % [GameState.stage_kills(), stage.kill_target]
	else:
		_kill_label.text = "杀敌  %d" % GameState.stage_kills()
	var realm := ContentDB.realms.get_realm(c.attack_realm_id)
	var realm_name := realm.display_name if realm else c.attack_realm_id
	_realm_label.text = "攻境  %s（%s）" % [realm_name, band]
	var next_realm := ContentDB.realms.get_next(c.attack_realm_id)
	if next_realm:
		var need := int(ContentDB.breakthrough_costs().get(next_realm.id, 0))
		_attack_label.text = "攻  %d(+%d) / %d → %s" % [
			GameState.effective_attack(),
			GameState.effective_attack() - c.attack,
			need,
			next_realm.display_name,
		]
	else:
		_attack_label.text = "攻  %d(+%d)" % [GameState.effective_attack(), GameState.effective_attack() - c.attack]
	_wisdom_label.text = "智  %d 阶" % c.wisdom_rank
	var def_name: String = _DefenseBands.name_for(c.defense, ContentDB.section("defense").get("bands", []))
	var eff_def := GameState.effective_defense()
	if def_name.is_empty():
		_defense_label.text = "防  %d(+%d)" % [eff_def, eff_def - c.defense]
	else:
		_defense_label.text = "防  %d(+%d)（%s）" % [eff_def, eff_def - c.defense, def_name]
	_stones_label.text = "灵石  %d" % GameState.spirit_stones
	if _wave_label.text.is_empty():
		var stage := GameState.current_stage()
		if stage:
			_wave_label.text = stage.wave_hint(GameState.stage_kills())
	if GameState.dead:
		_hint_label.text = "已阵亡  R 重生   Esc 返回选关"
	elif GameState.is_stage_cleared():
		_hint_label.text = "本关已通  Esc 返回选关继续下一层"
	else:
		_hint_label.text = "WASD 移动  L闪避 U环斩 I服丹 O灵爆  J吐纳 K突破"
