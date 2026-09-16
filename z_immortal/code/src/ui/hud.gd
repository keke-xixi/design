extends CanvasLayer

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _stage_label: Label = $Root/TopBar/Panel/StageLabel
@onready var _hp_fill: ColorRect = $Root/TopBar/Panel/HpRow/HpBarBg/HpBarFill
@onready var _kill_label: Label = $Root/TopBar/Panel/KillLabel
@onready var _kill_fill: ColorRect = $Root/TopBar/Panel/KillBarBg/KillBarFill
@onready var _stone_label: Label = get_node_or_null("Root/TopBar/Panel/StoneLabel")
@onready var _combo_label: Label = $Root/ComboLabel
@onready var _hint_label: Label = $Root/HintLabel
@onready var _clear: Label = $Root/ClearBanner
@onready var _boss_bar: PanelContainer = $Root/BossBar
@onready var _boss_name: Label = $Root/BossBar/VBox/BossName
@onready var _boss_hp_fill: ColorRect = $Root/BossBar/VBox/BossHpBg/BossHpFill
@onready var _skill_l: Label = $Root/SkillDock/SkillBar/KeyL/SkillL
@onready var _skill_u: Label = $Root/SkillDock/SkillBar/KeyU/SkillU
@onready var _skill_i: Label = $Root/SkillDock/SkillBar/KeyI/SkillI
@onready var _skill_o: Label = $Root/SkillDock/SkillBar/KeyO/SkillO
@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _skill_dock: PanelContainer = $Root/SkillDock

const _SKILL_IDS := ["dash", "ring_slash", "use_pill", "spirit_burst"]
const _SKILL_KEYS := ["L", "U", "I", "O"]
const _HP_BAR_W := 152.0
const _KILL_BAR_W := 152.0

var _skill_was_ready: Array[bool] = [true, true, true, true] # edge-detect CD→ready flash

func _style_skill_keys() -> void:
	for key_name in ["KeyL", "KeyU", "KeyI", "KeyO"]:
		var key := $Root/SkillDock/SkillBar.get_node_or_null(key_name) as PanelContainer
		if key:
			_UiStyle.apply_panel(key, Color(0.82, 0.72, 0.45, 0.7))

func _ready() -> void:
	add_to_group("hud")
	_UiStyle.apply_panel(_top_bar, Color(0.72, 0.62, 0.38, 0.5))
	_UiStyle.apply_panel(_skill_dock, Color(0.72, 0.62, 0.38, 0.4))
	_UiStyle.apply_panel(_boss_bar, Color(0.9, 0.45, 0.3, 0.55))
	_style_skill_keys()
	EventBus.cultivation_broke_through.connect(_on_any)
	EventBus.mystic_crossed.connect(_on_mystic)
	EventBus.attack_gained.connect(_on_any2)
	EventBus.enemy_killed.connect(_on_any2)
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.player_died.connect(_on_dead)
	EventBus.stage_changed.connect(_on_stage)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.wave_changed.connect(_on_wave)
	EventBus.boss_spawned.connect(_on_boss)
	EventBus.item_gained.connect(_on_any2)
	EventBus.equipment_changed.connect(_on_any)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_hp_cleared.connect(_on_boss_hp_cleared)
	EventBus.stage_reward.connect(_on_stage_reward)
	EventBus.combo_milestone.connect(_on_combo_milestone)
	EventBus.cultivation_stat_gained.connect(_on_growth_ping)
	EventBus.skill_used.connect(_on_skill_used)
	_clear.visible = false
	_hint_label.visible = false
	_refresh()

func _process(_delta: float) -> void:
	_update_skill_bar()
	if _stone_label:
		_stone_label.text = "石 %d" % GameState.spirit_stones
	# Pulse crisis vignette when low HP.
	var crisis := GameState.hp > 0 and float(GameState.hp) / float(maxi(GameState.max_hp, 1)) <= 0.3 and not GameState.dead
	if crisis:
		var pulse := 0.32 + 0.12 * sin(Time.get_ticks_msec() * 0.008)
		var root := $Root
		for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
			var edge := root.get_node_or_null(edge_name) as ColorRect
			if edge:
				edge.color = Color(0.5, 0.05, 0.05, pulse)

func _update_skill_bar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var labels := [_skill_l, _skill_u, _skill_i, _skill_o]
	var keys := ["KeyL", "KeyU", "KeyI", "KeyO"]
	for i in _SKILL_IDS.size():
		var key: String = _SKILL_KEYS[i]
		var cd_left := 0.0
		if player and player.has_method("get_skill_cooldown"):
			cd_left = player.get_skill_cooldown(_SKILL_IDS[i])
		var key_panel := $Root/SkillDock/SkillBar.get_node_or_null(keys[i]) as CanvasItem
		var ready := cd_left <= 0.05
		# Flash when a skill comes off cooldown — readable agency.
		if ready and i < _skill_was_ready.size() and not _skill_was_ready[i]:
			if key_panel:
				key_panel.modulate = Color(1.35, 1.2, 0.7)
				var tw := create_tween()
				tw.tween_property(key_panel, "modulate", Color.WHITE, 0.28)
			labels[i].modulate = Color(1.0, 0.95, 0.65, 1.0)
		if i < _skill_was_ready.size():
			_skill_was_ready[i] = ready
		if not ready:
			labels[i].text = "%.0f" % ceil(cd_left)
			labels[i].modulate = Color(0.45, 0.5, 0.55, 0.9)
			if key_panel and key_panel.modulate.r < 1.2:
				key_panel.modulate = Color(0.65, 0.7, 0.75, 0.85)
		else:
			labels[i].text = key
			if labels[i].modulate.g < 0.9:
				labels[i].modulate = Color(0.95, 0.97, 1.0, 1.0)
			if key_panel and key_panel.modulate.r < 1.15:
				key_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func show_clear(custom: String = "") -> void:
	_clear.text = custom if not custom.is_empty() else "通关"
	_clear.visible = true
	_clear.modulate = Color(1.0, 0.94, 0.6, 1.0)
	_clear.scale = Vector2(0.88, 0.88)
	var tw := create_tween()
	tw.tween_property(_clear, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.85)
	tw.tween_property(_clear, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _clear.visible = false)

func _on_mystic() -> void:
	show_clear("通玄")
	_refresh()

func _on_any(_a = null) -> void:
	_refresh()

func _on_any2(_a = null, _b = null, _c = null) -> void:
	_refresh()

func _on_hp(_hp: int, _max_hp: int) -> void:
	_refresh()

func _on_dead() -> void:
	_hint_label.visible = true
	_hint_label.text = "气散 · 看中央再战"
	_refresh()

func _on_stage(_stage_id: String) -> void:
	_clear.visible = false
	_boss_bar.visible = false
	_hint_label.visible = false
	_refresh()

func _on_wave(hint: String) -> void:
	show_clear(hint)

func _on_combo_milestone(count: int) -> void:
	_combo_label.visible = true
	_combo_label.text = "%d连" % count
	_combo_label.modulate = Color(1.0, 0.88, 0.45, 1.0)
	_combo_label.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.65)
	tw.tween_property(_combo_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: _combo_label.visible = false)

func _on_growth_ping(stat: String, _value: int) -> void:
	# Brief top-bar flash so kill-growth is felt even if float text is missed.
	var tip := "悟性↑" if stat == "wisdom" else "体魄↑"
	show_clear(tip)

func _on_skill_used(skill_id: String, _cooldown: float) -> void:
	var idx := _SKILL_IDS.find(skill_id)
	if idx < 0:
		return
	var keys := ["KeyL", "KeyU", "KeyI", "KeyO"]
	var key_panel := $Root/SkillDock/SkillBar.get_node_or_null(keys[idx]) as CanvasItem
	if key_panel == null:
		return
	key_panel.modulate = Color(0.55, 0.85, 1.0)
	var tw := create_tween()
	tw.tween_property(key_panel, "modulate", Color(0.65, 0.7, 0.75, 0.85), 0.15)

func _on_boss_hp(name: String, hp: int, max_hp: int) -> void:
	_boss_bar.visible = true
	_boss_name.text = name
	var ratio := 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var bar_w := 220.0
	_boss_hp_fill.size.x = bar_w * ratio
	_boss_hp_fill.color = Color(1.0, 0.45, 0.3) if ratio > 0.35 else Color(1.0, 0.25, 0.2)

func _on_boss_hp_cleared() -> void:
	_boss_bar.visible = false

func _on_boss(enemy_id: String) -> void:
	var enemy := ContentDB.get_enemy(enemy_id)
	show_clear(enemy.display_name if enemy else enemy_id)

func _on_cleared(_stage_id: String) -> void:
	show_clear("通关")
	_refresh()

func _on_stage_reward(stones: int) -> void:
	show_clear("+%d石" % stones)

func _refresh() -> void:
	var stage := GameState.current_stage()
	_stage_label.text = stage.display_name if stage else GameState.stage_id
	var hp_ratio := 0.0 if GameState.max_hp <= 0 else clampf(float(GameState.hp) / float(GameState.max_hp), 0.0, 1.0)
	_hp_fill.size.x = _HP_BAR_W * hp_ratio
	if hp_ratio <= 0.3:
		_hp_fill.color = Color(0.9, 0.35, 0.3)
	elif hp_ratio <= 0.55:
		_hp_fill.color = Color(0.95, 0.75, 0.35)
	else:
		_hp_fill.color = Color(0.35, 0.82, 0.48)
	if stage:
		var kills := GameState.stage_kills()
		var target := maxi(stage.kill_target, 1)
		_kill_label.text = "%d/%d" % [kills, stage.kill_target]
		var ratio := clampf(float(kills) / float(target), 0.0, 1.0)
		_kill_fill.size.x = _KILL_BAR_W * ratio
		# Boss phase = orange; near-clear = gold pulse (urge to finish).
		var near_clear := ratio >= 0.75 and kills < stage.kill_target
		var boss_phase := kills >= stage.boss_at_kill and not stage.boss_id.is_empty() and kills < stage.kill_target
		if boss_phase:
			_kill_fill.color = Color(1.0, 0.5, 0.35)
		elif near_clear:
			var pulse := 0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.01)
			_kill_fill.color = Color(1.0, 0.82, 0.35, pulse)
		else:
			_kill_fill.color = Color(0.9, 0.75, 0.4)
	else:
		_kill_label.text = "—"
		_kill_fill.size.x = 0.0
	if _stone_label:
		_stone_label.text = "石 %d" % GameState.spirit_stones
	if GameState.combo >= 3:
		_combo_label.visible = true
		_combo_label.text = "%d连" % GameState.combo
		_combo_label.modulate.a = 1.0
	elif GameState.combo < 2:
		_combo_label.visible = false
	var root := $Root
	var crisis := GameState.hp > 0 and float(GameState.hp) / float(maxi(GameState.max_hp, 1)) <= 0.3
	for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
		var edge := root.get_node_or_null(edge_name) as ColorRect
		if edge:
			edge.color = Color(0.45, 0.05, 0.05, 0.4) if crisis else Color(0.02, 0.03, 0.05, 0.26)
	if GameState.dead:
		_hint_label.visible = true
		_hint_label.text = "气散 · 看中央再战"
	elif GameState.is_stage_cleared():
		_hint_label.visible = true
		_hint_label.text = "Esc 选关 · 通关奖励已入账"
	else:
		_hint_label.visible = false
