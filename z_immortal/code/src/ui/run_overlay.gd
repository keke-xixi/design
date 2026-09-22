extends CanvasLayer

## Slim combat ceremony: start + clear + soft death (no wave modal).
## Hierarchy: dim → glow → panel → one hero CTA pulse; secondary actions quiet.

enum Kind { NONE, START, RESULT, DEATH }

const _UiStyle := preload("res://src/ui/ui_style.gd")

var _kind: int = Kind.NONE
var _root: Control
var _dim: ColorRect
var _glow: ColorRect
var _panel: PanelContainer
var _title: Label
var _desc: Label
var _buttons: VBoxContainer
var _hero_btn: Button = null
var _accent := Color(0.55, 0.78, 0.88)
var _title_halo: ColorRect
var _title_rule: ColorRect
var _start_auto_timer: SceneTreeTimer = null
var _death_hub_pull := false  # Pity death: hero CTA = 回宗花石
## Dynasty settle: louder warm-gold pulse on 「回宗花石」.
var _dynasty_hub_pulse := false
## Clear settle land — sect teal / dynasty gold wrap (pairs start wipe).
var _result_land_t := 0.0
var _result_land_teal := false
## Stage-select handoff: start already wiped — close burst skips second full wipe.
var _start_handoff_wiped := false

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.stage_reward.connect(_on_stage_reward)
	EventBus.player_died.connect(_on_player_died)
	call_deferred("_show_start")

func _process(_delta: float) -> void:
	if not visible:
		return
	if _result_land_t > 0.0:
		_result_land_t = maxf(_result_land_t - _delta, 0.0)
	var t := Time.get_ticks_msec() * 0.001
	var land := clampf(_result_land_t / 0.55, 0.0, 1.0)
	if _kind == Kind.START and _title:
		# Title halo breathes — brand the stage before the CTA.
		var breathe := 0.92 + 0.08 * sin(t * 3.2)
		if GameState.stage_id == "sect":
			# Cool cyan wash matches yard minimap / HUD kill-bar.
			_title.modulate = Color(0.78 + 0.22 * breathe, 1.0, 0.96, 1.0)
		elif GameState.stage_id == "country":
			# Warm gold — dynasty identity vs sect teal.
			_title.modulate = Color(1.0, 0.88 + 0.1 * breathe, 0.55 + 0.15 * breathe, 1.0)
		else:
			_title.modulate = Color(breathe, breathe, breathe * 0.98, 1.0)
		if _title_halo:
			_title_halo.modulate.a = 0.35 + 0.25 * sin(t * 2.6)
	elif _kind == Kind.RESULT and _title and (land > 0.0 or _result_land_teal or _dynasty_hub_pulse):
		# Clear settle title — teal/gold punch then soft hold (mirrors start brand).
		var pulse := 0.55 + 0.45 * sin(t * 3.0)
		if _result_land_teal or (not _dynasty_hub_pulse and GameState.stage_id == "sect"):
			var a := maxf(land, 0.35 + 0.15 * pulse)
			_title.modulate = Color(0.7 + 0.2 * a, 1.05 + 0.1 * a, 1.0 + 0.05 * a)
			if _title_halo and _title_halo.visible:
				_title_halo.modulate.a = 0.4 + 0.35 * land + 0.2 * pulse
		elif _dynasty_hub_pulse:
			var a2 := maxf(land, 0.4 + 0.15 * pulse)
			_title.modulate = Color(1.05 + 0.2 * a2, 0.9 + 0.1 * a2, 0.55 + 0.12 * a2)
			if _title_halo and _title_halo.visible:
				_title_halo.modulate.a = 0.4 + 0.35 * land + 0.2 * pulse
	if _hero_btn == null or not is_instance_valid(_hero_btn):
		return
	# Soft gold breath — louder on early clear/death hub pull; loudest after dynasty「收刀」.
	var amp := 0.08 if _kind == Kind.START else (0.12 if _kind == Kind.RESULT or _death_hub_pull else 0.05)
	var hz := 4.2 if _kind == Kind.START else (5.2 if _kind == Kind.RESULT or _death_hub_pull else 3.6)
	if _dynasty_hub_pulse and _kind == Kind.RESULT:
		amp = 0.18
		hz = 6.4
	var g := 1.0 + amp * sin(t * hz)
	if _dynasty_hub_pulse and _kind == Kind.RESULT:
		# Hotter gold kick — spend loop CTA after 收刀.
		_hero_btn.modulate = Color(minf(g * 1.22, 1.55), minf(g * 0.95, 1.25), minf(g * 0.55, 0.95))
		var s2 := 1.0 + 0.055 * sin(t * hz)
		_hero_btn.scale = Vector2(s2, s2)
		_hero_btn.pivot_offset = _hero_btn.size * 0.5
	elif _kind == Kind.RESULT and _result_land_teal:
		# Sect clear CTA — courtyard teal breath (pairs dynasty gold).
		var tg := 1.0 + (0.1 + 0.08 * land) * sin(t * 5.0)
		_hero_btn.modulate = Color(minf(0.55 * tg, 0.85), minf(tg * 1.05, 1.35), minf(tg * 0.98, 1.25))
		var s3 := 1.0 + 0.03 * sin(t * 5.0) + 0.06 * land
		_hero_btn.scale = Vector2(s3, s3)
		_hero_btn.pivot_offset = _hero_btn.size * 0.5
	elif _kind == Kind.RESULT or _death_hub_pull:
		# Warm gold pulse so 「回宗花石」 reads as the spend loop CTA.
		_hero_btn.modulate = Color(minf(g * 1.08, 1.35), minf(g * 0.98, 1.2), minf(g * 0.72, 1.0))
		var s := 1.0 + 0.035 * sin(t * hz)
		_hero_btn.scale = Vector2(s, s)
		_hero_btn.pivot_offset = _hero_btn.size * 0.5
	else:
		_hero_btn.modulate = Color(g, g * 0.97, g * 0.88)
		_hero_btn.scale = Vector2.ONE
	if _glow:
		var glow_amp := 0.28 if _dynasty_hub_pulse else (0.22 if _result_land_teal and _kind == Kind.RESULT else (0.18 if _kind == Kind.RESULT or _death_hub_pull else 0.12))
		_glow.modulate.a = 0.35 + glow_amp * sin(t * (3.4 if _dynasty_hub_pulse or _result_land_teal else 2.8)) + 0.2 * land
		if _dynasty_hub_pulse:
			_glow.color = Color(1.0, 0.78, 0.35, 0.22)
		elif _result_land_teal and _kind == Kind.RESULT:
			_glow.color = Color(0.4, 0.9, 0.85, 0.22)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _kind == Kind.START:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_close()
			get_viewport().set_input_as_handled()
	elif _kind == Kind.DEATH:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			_do_revive()
			get_viewport().set_input_as_handled()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.03, 0.06, 0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	_root.add_child(_dim)
	# Soft halo behind the panel — depth without a second card.
	_glow = ColorRect.new()
	_glow.set_anchors_preset(Control.PRESET_CENTER)
	_glow.offset_left = -190
	_glow.offset_top = -118
	_glow.offset_right = 190
	_glow.offset_bottom = 118
	_glow.color = Color(0.55, 0.78, 0.88, 0.18)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glow)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -150
	_panel.offset_top = -86
	_panel.offset_right = 150
	_panel.offset_bottom = 86
	_UiStyle.apply_ceremony_panel(_panel, Color(0.55, 0.78, 0.88, 0.9))
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.92, 0.97, 0.98))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("shadow_offset_x", 1)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	v.add_child(_title)
	# Soft wash behind title — reads as halo without a second card.
	_title_halo = ColorRect.new()
	_title_halo.custom_minimum_size = Vector2(220, 6)
	_title_halo.color = Color(0.7, 0.9, 1.0, 0.0)
	_title_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title_halo)
	_title_rule = ColorRect.new()
	_title_rule.custom_minimum_size = Vector2(72, 2)
	_title_rule.color = Color(0.95, 0.88, 0.55, 0.85)
	_title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_title_rule)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(260, 16)
	_desc.add_theme_font_size_override("font_size", 11)
	_desc.add_theme_color_override("font_color", Color(0.78, 0.84, 0.88))
	v.add_child(_desc)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 7)
	v.add_child(_buttons)

func _on_dim_input(event: InputEvent) -> void:
	if _kind == Kind.START and event is InputEventMouseButton and event.pressed:
		_close()

func _on_stage_cleared(stage_id: String) -> void:
	call_deferred("_show_result", stage_id, -1)

func _on_stage_reward(stones: int) -> void:
	call_deferred("_show_result", GameState.stage_id, stones)

func _on_player_died() -> void:
	call_deferred("_show_death")

func _tint_glow(c: Color) -> void:
	_accent = c
	if _glow:
		_glow.color = Color(c.r, c.g, c.b, 0.22)
		_glow.modulate = Color(1, 1, 1, 0.4)

func _show_start() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stage := GameState.current_stage()
	if stage == null:
		return
	_kind = Kind.START
	_start_handoff_wiped = false
	var handoff := GameState.combat_enter_handoff
	GameState.combat_enter_handoff = ""
	var yard := GameState.stage_id == "sect"
	var dynasty := GameState.stage_id == "country"
	var from_select := (handoff == "sect" and yard) or (handoff == "country" and dynasty)
	var accent := Color.from_string(stage.accent, Color(0.55, 0.78, 0.88))
	if yard:
		# Same teal as minimap frame / kill-bar — mountain-sect identity.
		accent = Color(0.45, 0.88, 0.82)
	elif dynasty:
		# Warm gold — streets / hub dynasty CTA language.
		accent = Color(0.95, 0.78, 0.38)
	_UiStyle.apply_ceremony_panel(_panel, Color(accent.r, accent.g, accent.b, 0.94))
	_title.add_theme_font_size_override("font_size", 26 if yard or dynasty else 24)
	_title.add_theme_color_override("font_color", accent.lightened(0.32))
	_title.modulate = Color.WHITE
	_tint_glow(accent)
	# Lighter veil — battlefield peeks through; one second to fight.
	if _dim:
		if yard:
			_dim.color = Color(0.02, 0.08, 0.08, 0.36)
		elif dynasty:
			_dim.color = Color(0.1, 0.06, 0.02, 0.4)
		else:
			_dim.color = Color(0.02, 0.03, 0.06, 0.42)
	if _title_halo:
		_title_halo.color = Color(accent.r, accent.g, accent.b, 0.5 if yard or dynasty else 0.45)
		_title_halo.visible = true
		_title_halo.custom_minimum_size = Vector2(240 if yard or dynasty else 220, 7 if yard or dynasty else 6)
	if _title_rule:
		_title_rule.color = Color(accent.r, accent.g, accent.b, 0.95).lightened(0.2)
		_title_rule.visible = true
	# One short line only — kill count, no lecture.
	var crib := "外门 · 杀 %d" % stage.kill_target if yard else ("市井 · 杀 %d" % stage.kill_target if dynasty else ("杀 %d" % stage.kill_target))
	_size_panel(-70 if yard or dynasty else -64, 70 if yard or dynasty else 64)
	_open_panel(stage.display_name, crib, [["开战", _close]], true)
	# Start CTA is taller / louder than death/result heroes.
	if _hero_btn:
		_hero_btn.custom_minimum_size = Vector2(0, 42 if yard or dynasty else 40)
		_hero_btn.add_theme_font_size_override("font_size", 16)
		_hero_btn.text = "开战"
		if yard:
			_hero_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.95))
			_hero_btn.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 0.98))
		elif dynasty:
			_hero_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.7))
			_hero_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.85))
	if from_select:
		# Continuity: fade the select wipe color into the ceremony, then fight.
		_start_handoff_wiped = true
		if yard:
			_wipe_teal_flash()
		elif dynasty:
			_wipe_gold_flash()
		_pop_panel()
		if _hero_btn:
			_hero_btn.pivot_offset = _hero_btn.size * 0.5
			_hero_btn.scale = Vector2(0.88, 0.88)
			var htw := create_tween()
			htw.tween_property(_hero_btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
			htw.tween_property(_hero_btn, "scale", Vector2.ONE, 0.14)
		# Snappier — handoff already spent a beat on select.
		_start_auto_timer = get_tree().create_timer(0.82 if yard else 0.78, true)
	else:
		_pop_panel()
		# ~1s auto-enter — click / Space / Esc also skip.
		_start_auto_timer = get_tree().create_timer(1.05 if yard else (1.0 if dynasty else 0.95), true)
	_start_auto_timer.timeout.connect(_on_start_auto_close)

func _on_start_auto_close() -> void:
	if _kind == Kind.START:
		_close()

func _show_death() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not GameState.dead:
		return
	_kind = Kind.DEATH
	_death_hub_pull = false
	_title.add_theme_font_size_override("font_size", 22)
	_title.modulate = Color.WHITE
	if _dim:
		_dim.color = Color(0.02, 0.03, 0.06, 0.58)
	var kills := GameState.stage_kills()
	var stage := GameState.current_stage()
	var target := stage.kill_target if stage else 0
	var pity := GameState.last_death_pity
	var early := GameState.stage_id in ["sect", "country"]
	# Soft consolation palette when pity lands — death must not feel empty.
	var soft := pity > 0
	if _title_halo:
		_title_halo.visible = soft
		if soft:
			_title_halo.color = Color(0.95, 0.82, 0.4, 0.4)
	if _title_rule:
		_title_rule.visible = true
		_title_rule.color = Color(0.95, 0.82, 0.45, 0.85) if soft else Color(0.95, 0.55, 0.45, 0.75)
	var panel_c := Color(0.92, 0.72, 0.38) if soft else Color(0.9, 0.42, 0.36)
	_UiStyle.apply_ceremony_panel(_panel, Color(panel_c.r, panel_c.g, panel_c.b, 0.94))
	_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75) if soft else Color(1.0, 0.88, 0.8))
	_tint_glow(panel_c)
	# One short line — pity + kept progress, no lecture.
	var title := "气散"
	var desc := "进度保留 · %d/%d" % [kills, target]
	if pity > 0:
		title = "抚恤到手"
		desc = "抚恤 +%d石 · 进度 %d/%d" % [pity, kills, target]
	elif early:
		desc = "进度保留 · %d/%d · R再战" % [kills, target]
	_size_panel(-100, 100)
	var actions: Array = []
	# Early pity → loud hub spend CTA; R still revives from keyboard.
	if early and pity > 0:
		_death_hub_pull = true
		actions = [
			["回宗花石", _hub],
			["再战 (R)", _do_revive],
			["选关", _leave],
		]
	else:
		actions = [
			["再战 (R)", _do_revive],
			["回宗花石", _hub],
			["选关", _leave],
		]
	_open_panel(title, desc, actions, true)
	_pop_panel()
	if _death_hub_pull and _hero_btn:
		_hero_btn.add_theme_font_size_override("font_size", 15)
		_hero_btn.custom_minimum_size = Vector2(0, 40)
		_hero_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62))
		_hero_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.8))
		_hero_btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.85, 0.45))
	# Extra float so pity lands even if HUD shout is missed.
	if pity > 0:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			FloatTextManager.show_message(player.global_position + Vector2(0, -52), "+%d石" % pity, Color(1.0, 0.9, 0.5))
			FloatTextManager.show_message(player.global_position + Vector2(0, -68), "回宗可花", Color(1.0, 0.92, 0.65))
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("flash_recover_edges"):
			# Soft gold rim — same family as combo flash, softer consolation.
			hud.call("flash_recover_edges")

func _show_result(stage_id: String, stones: int) -> void:
	if DisplayServer.get_name() == "headless":
		_close()
		return
	var stage := ContentDB.get_stage(stage_id)
	var name := stage.display_name if stage else stage_id
	var payout := stones if stones >= 0 else GameState.last_clear_stones
	var first := GameState.last_clear_first and GameState.last_clear_stage_id == stage_id
	var desc := ""
	if payout >= 0:
		desc = ("首通 +%d石" % payout) if first else ("+%d石" % payout)
	if stage and not stage.next_id.is_empty():
		var nxt := ContentDB.get_stage(stage.next_id)
		if nxt and GameState.can_enter(nxt):
			desc += (" · %s开" % nxt.display_name) if not desc.is_empty() else ("%s已开" % nxt.display_name)
	_kind = Kind.RESULT
	_dynasty_hub_pulse = stage_id == "country"
	_result_land_teal = stage_id == "sect"
	_result_land_t = 0.55 if (stage_id == "sect" or stage_id == "country") else 0.0
	_title.add_theme_font_size_override("font_size", 22)
	_title.modulate = Color.WHITE
	if _dim:
		_dim.color = Color(0.02, 0.03, 0.06, 0.62)
	if _title_halo:
		_title_halo.visible = false
	if _title_rule:
		_title_rule.visible = true
		_title_rule.color = Color(0.95, 0.88, 0.55, 0.85)
	var gold := Color(0.92, 0.78, 0.42)
	var teal := Color(0.45, 0.88, 0.82)
	if stage_id == "sect":
		# Courtyard teal settle — pairs dynasty gold「收刀」wrap.
		_UiStyle.apply_ceremony_panel(_panel, Color(teal.r, teal.g, teal.b, 0.94))
		_title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.95))
		_tint_glow(teal)
		if _dim:
			_dim.color = Color(0.02, 0.08, 0.08, 0.52)
		if _title_halo:
			_title_halo.visible = true
			_title_halo.color = Color(0.4, 0.92, 0.86, 0.45)
			_title_halo.custom_minimum_size = Vector2(220, 6)
		if _title_rule:
			_title_rule.color = Color(0.5, 0.95, 0.88, 0.9)
	else:
		_UiStyle.apply_ceremony_panel(_panel, Color(gold.r, gold.g, gold.b, 0.94))
		_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
		_tint_glow(gold)
	_size_panel(-100, 100)
	var actions: Array = []
	var early := stage != null and stage.id in ["sect", "country"]
	# Early first clear → hub spend is the loud desire; next layer stays secondary.
	# Dynasty always prefers 回宗花石 as hero after 收刀.
	var pull_hub := early and (first or payout >= 18 or stage_id == "country")
	if pull_hub:
		actions.append(["回宗花石", _hub])
		if stage and not stage.next_id.is_empty():
			var nxt2 := ContentDB.get_stage(stage.next_id)
			if nxt2 and GameState.can_enter(nxt2):
				var nid := nxt2.id
				actions.append(["下一层", func() -> void: SceneManager.go_combat(nid)])
		actions.append(["选关", _leave])
	else:
		var hero := "留下"
		var hero_cb: Callable = _close
		if stage and not stage.next_id.is_empty():
			var nxt3 := ContentDB.get_stage(stage.next_id)
			if nxt3 and GameState.can_enter(nxt3):
				var nid2 := nxt3.id
				hero = "下一层"
				hero_cb = func() -> void: SceneManager.go_combat(nid2)
		actions.append([hero, hero_cb])
		actions.append(["回宗花石", _hub])
		actions.append(["选关", _leave])
	var title := "通关 · %s" % name
	if stage_id == "sect":
		title = "通关 · 外门"
		_title.add_theme_font_size_override("font_size", 24)
	elif stage_id == "country":
		# Echo battlefield「收刀」— dynasty settle language.
		title = "收刀 · 王朝"
		_title.add_theme_font_size_override("font_size", 24)
		_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		if _title_halo:
			_title_halo.visible = true
			_title_halo.color = Color(1.0, 0.82, 0.38, 0.45)
			_title_halo.custom_minimum_size = Vector2(220, 6)
		if _title_rule:
			_title_rule.color = Color(1.0, 0.86, 0.42, 0.9)
		if _dim:
			_dim.color = Color(0.08, 0.05, 0.02, 0.58)
	_open_panel(title, desc, actions, true)
	_pop_panel()
	if (pull_hub or _dynasty_hub_pulse or _result_land_teal) and _hero_btn:
		_hero_btn.add_theme_font_size_override("font_size", 16 if _dynasty_hub_pulse else 15)
		_hero_btn.custom_minimum_size = Vector2(0, 42 if _dynasty_hub_pulse else 40)
		if _result_land_teal:
			_hero_btn.add_theme_color_override("font_color", Color(0.75, 1.0, 0.94))
			_hero_btn.add_theme_color_override("font_hover_color", Color(0.9, 1.0, 0.98))
			_hero_btn.add_theme_color_override("font_pressed_color", Color(0.45, 0.88, 0.8))
		else:
			_hero_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55) if _dynasty_hub_pulse else Color(1.0, 0.94, 0.62))
			_hero_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.78) if _dynasty_hub_pulse else Color(1.0, 0.98, 0.8))
			_hero_btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.85, 0.45))
		if _dynasty_hub_pulse:
			_hero_btn.text = "回宗花石"
			_UiStyle.apply_cta_button(_hero_btn)

func _size_panel(top: float, bottom: float) -> void:
	_panel.offset_left = -150
	_panel.offset_right = 150
	_panel.offset_top = top
	_panel.offset_bottom = bottom
	if _glow:
		_glow.offset_left = -188
		_glow.offset_right = 188
		_glow.offset_top = top - 22
		_glow.offset_bottom = bottom + 22

func _pop_panel() -> void:
	_panel.scale = Vector2(0.9, 0.9)
	_panel.pivot_offset = _panel.size * 0.5
	var pop := create_tween()
	pop.tween_property(_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	if _glow:
		_glow.scale = Vector2(0.85, 0.85)
		_glow.pivot_offset = _glow.size * 0.5
		var gt := create_tween()
		gt.tween_property(_glow, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD)

func _open_panel(title: String, desc: String, actions: Array, hero_first: bool = false) -> void:
	visible = true
	_title.text = title
	_desc.text = desc
	_desc.visible = not desc.is_empty()
	_clear_buttons()
	_hero_btn = null
	var idx := 0
	for raw in actions:
		if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
			continue
		var b := Button.new()
		var label := str(raw[0])
		var is_hero := hero_first and idx == 0
		# Only the first action is loud; hub/select stay quiet so the eye sticks on CTA.
		b.custom_minimum_size = Vector2(0, 36 if is_hero else 24)
		b.text = label
		if is_hero:
			_UiStyle.apply_cta_button(b)
			_hero_btn = b
		else:
			_UiStyle.apply_button(b)
			b.add_theme_font_size_override("font_size", 11)
			b.modulate = Color(0.82, 0.86, 0.9, 0.88)
		var cb: Callable = raw[1]
		b.pressed.connect(func() -> void:
			_close()
			cb.call()
		)
		_buttons.add_child(b)
		idx += 1

func _clear_buttons() -> void:
	_hero_btn = null
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()

func _close() -> void:
	var was_start := _kind == Kind.START
	var handoff_skip_wipe := was_start and _start_handoff_wiped
	_kind = Kind.NONE
	_death_hub_pull = false
	_dynasty_hub_pulse = false
	_result_land_t = 0.0
	_result_land_teal = false
	_start_handoff_wiped = false
	visible = false
	if _hero_btn and is_instance_valid(_hero_btn):
		_hero_btn.scale = Vector2.ONE
	_hero_btn = null
	_title.modulate = Color.WHITE
	_clear_buttons()
	if was_start and GameState.stage_id == "sect":
		_burst_sect_enter(not handoff_skip_wipe)
	elif was_start and GameState.stage_id == "country":
		_burst_country_enter(not handoff_skip_wipe)

func _burst_sect_enter(do_wipe: bool = true) -> void:
	# One beat of courtyard teal — ritual lands, then fight. Not a cutscene.
	if SfxService:
		SfxService.play_start()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	FloatTextManager.show_message(player.global_position + Vector2(0, -36), "开战", Color(0.45, 0.95, 0.88))
	if player.has_method("pulse_camera"):
		player.pulse_camera(0.08)
	# Full-bleed teal wipe — skip if select→start already wiped (handoff).
	if do_wipe:
		_wipe_teal_flash()
	var parent := player.get_parent()
	if parent == null:
		return
	for ring_i in 2:
		var ring := Line2D.new()
		ring.width = 2.6 - float(ring_i) * 0.5
		ring.default_color = Color(0.4, 0.92, 0.86, 0.85 - float(ring_i) * 0.22)
		ring.z_index = 8
		var r0 := 14.0 + float(ring_i) * 7.0
		for i in 25:
			var a := TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(a), sin(a)) * r0)
		parent.add_child(ring)
		ring.global_position = player.global_position
		var delay := float(ring_i) * 0.04
		var tw := ring.create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
		tw.tween_callback(ring.queue_free)
	var outline := player.get_node_or_null("Outline") as Sprite2D
	if outline:
		outline.modulate = Color(0.35, 0.95, 0.88, 0.8)
		outline.scale = Vector2(1.12, 1.12)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_clear"):
		hud.call("show_clear", "开战")
	if hud and hud.has_method("flash_sect_top"):
		hud.call("flash_sect_top")
	# Minimap teal ping at the hero — courtyard open lands on the radar.
	var world := get_tree().get_first_node_in_group("game_world")
	if world and world.has_method("radar_ping"):
		world.call("radar_ping", player.global_position, "yard")

## Dynasty open — short warm-gold wipe (not teal rings). Distinct from 宗门 ritual.
func _burst_country_enter(do_wipe: bool = true) -> void:
	if SfxService:
		SfxService.play_start()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	FloatTextManager.show_message(player.global_position + Vector2(0, -36), "开战", Color(1.0, 0.86, 0.45))
	if player.has_method("pulse_camera"):
		player.pulse_camera(0.09)
	if do_wipe:
		_wipe_gold_flash()
	var parent := player.get_parent()
	if parent:
		# Single warm steel ring — city grit, not courtyard teal double-ring.
		var ring := Line2D.new()
		ring.width = 2.4
		ring.default_color = Color(1.0, 0.82, 0.38, 0.9)
		ring.z_index = 8
		for i in 25:
			var a := TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(a), sin(a)) * 16.0)
		parent.add_child(ring)
		ring.global_position = player.global_position
		var tw := ring.create_tween()
		tw.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.26)
		tw.tween_callback(ring.queue_free)
	var outline := player.get_node_or_null("Outline") as Sprite2D
	if outline:
		outline.modulate = Color(1.0, 0.82, 0.4, 0.85)
		outline.scale = Vector2(1.14, 1.14)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_clear"):
		hud.call("show_clear", "王朝 · 开战")
	if hud and hud.has_method("flash_steel_edges"):
		hud.call("flash_steel_edges")
	if hud and hud.has_method("flash_dynasty_top"):
		hud.call("flash_dynasty_top")
	# Minimap warm-gold ping at the hero — dynasty open lands on the radar.
	var world := get_tree().get_first_node_in_group("game_world")
	if world and world.has_method("radar_ping"):
		world.call("radar_ping", player.global_position, "gold")

func _wipe_gold_flash() -> void:
	# Full-bleed warm gold wash on HUD — survives ceremony panel closing.
	var host: Control = null
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		host = hud.get_node_or_null("Root") as Control
	if host == null:
		host = _root
	if host == null:
		return
	var wipe := ColorRect.new()
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.color = Color(1.0, 0.82, 0.35, 0.55)
	wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	wipe.z_index = 50
	host.add_child(wipe)
	# Soft horizontal sweep — reads as wipe, not a hard cutscene.
	wipe.pivot_offset = Vector2(0, maxf(host.size.y, 360.0) * 0.5)
	wipe.scale = Vector2(0.08, 1.0)
	var tw := wipe.create_tween()
	tw.tween_property(wipe, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wipe, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(wipe.queue_free)

## Sect open — teal courtyard wipe (pairs dynasty gold wipe).
func _wipe_teal_flash() -> void:
	var host: Control = null
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		host = hud.get_node_or_null("Root") as Control
	if host == null:
		host = _root
	if host == null:
		return
	var wipe := ColorRect.new()
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.color = Color(0.35, 0.92, 0.85, 0.48)
	wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	wipe.z_index = 50
	host.add_child(wipe)
	wipe.pivot_offset = Vector2(0, maxf(host.size.y, 360.0) * 0.5)
	wipe.scale = Vector2(0.08, 1.0)
	var tw := wipe.create_tween()
	tw.tween_property(wipe, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wipe, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(wipe.queue_free)

func _do_revive() -> void:
	_close()
	GameState.revive()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		if player.has_method("soft_revive_guard"):
			player.call("soft_revive_guard", 1.15)
		var tip := "再起"
		if GameState.stage_id in ["sect", "country"]:
			tip = "再起 · 伤↑"
		FloatTextManager.show_message(player.global_position + Vector2(0, -36), tip, Color(0.55, 0.98, 0.85))
		if player.has_method("pulse_camera"):
			player.pulse_camera(0.1)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_clear"):
			hud.call("show_clear", tip)

func _leave() -> void:
	SceneManager.go_stage_select()

func _hub() -> void:
	SceneManager.go_hub()
