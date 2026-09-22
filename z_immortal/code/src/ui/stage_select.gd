extends Control

## Game-like stage select: left map list, right full preview + fight CTA.
## Early stages shout first-clear / spend-stones desire without a modal.

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _list: VBoxContainer = $Root/LeftPanel/LeftVBox/Scroll/List
@onready var _detail_title: Label = $Root/DetailTitle
@onready var _detail_stats: Label = $Root/DetailStats
@onready var _thumb: TextureRect = $Root/MapPreview
@onready var _enter_btn: Button = $Root/EnterButton
@onready var _hint: Label = $Root/LeftPanel/LeftVBox/Hint
@onready var _left_panel: PanelContainer = $Root/LeftPanel
@onready var _back_btn: Button = $Root/LeftPanel/LeftVBox/Header/BackButton

var _selected_id: String = ""
var _thumb_base := Vector2(200, 8)
var _pulse_ids: Dictionary = {} # stage_id -> true for first-clear bait
## Country row after 宗门 clear — matches hub「外门已通」warm-gold language.
var _dynasty_pull_ids: Dictionary = {}
## Country row after dynasty clear — warm-gold「再战」bait (quieter than 首通 pull).
var _dynasty_replay_ids: Dictionary = {}
## Sect row after courtyard clear — teal「再战」bait (mirrors dynasty gold replay).
var _sect_replay_ids: Dictionary = {}
var _thumb_hover := false
var _thumb_push := 0.0
var _thumb_locked := false
var _thumb_base_mod := Color.WHITE
## 「外门已通 · 王朝首通」hint — flash once then warm-gold breath.
var _dynasty_hint := false
var _dynasty_hint_flash_t := 0.0
## Brief punch on 开战 when preview frame flashes (doesn't replace breath).
var _enter_gold_pop_t := 0.0
## Guard: handoff wipe in flight — ignore double-tap 开战.
var _enter_handoff_busy := false
## Focus-row entry flash — sect teal / dynasty gold.
var _row_flash_t := 0.0
var _row_flash_teal := false
var _row_flash_id := ""
## 开战 CTA land flash — sect teal / dynasty gold.
var _enter_land_t := 0.0
var _enter_land_teal := false
var _mapframe_lock_t := 0.0
## Sect thumbnail teal lift — courtyard air on the preview art.
var _thumb_teal_t := 0.0
var _thumb_gold_t := 0.0
## Detail title land flash — sect teal / dynasty gold.
var _title_flash_t := 0.0
var _title_flash_teal := false
## Detail stats land flash — softer echo of the title.
var _stats_flash_t := 0.0
var _stats_flash_teal := false
## Hint bar land flash — sect teal / dynasty gold (defers to dynasty pull breath).
var _hint_land_t := 0.0
var _hint_land_teal := false

func _process(_delta: float) -> void:
	if _enter_btn == null:
		return
	if _enter_gold_pop_t > 0.0:
		_enter_gold_pop_t = maxf(_enter_gold_pop_t - _delta, 0.0)
	if _row_flash_t > 0.0:
		_row_flash_t = maxf(_row_flash_t - _delta, 0.0)
	if _enter_land_t > 0.0:
		_enter_land_t = maxf(_enter_land_t - _delta, 0.0)
	if _mapframe_lock_t > 0.0:
		_mapframe_lock_t = maxf(_mapframe_lock_t - _delta, 0.0)
	if _thumb_teal_t > 0.0:
		_thumb_teal_t = maxf(_thumb_teal_t - _delta, 0.0)
	if _thumb_gold_t > 0.0:
		_thumb_gold_t = maxf(_thumb_gold_t - _delta, 0.0)
	if _title_flash_t > 0.0:
		_title_flash_t = maxf(_title_flash_t - _delta, 0.0)
	if _stats_flash_t > 0.0:
		_stats_flash_t = maxf(_stats_flash_t - _delta, 0.0)
	if _hint_land_t > 0.0:
		_hint_land_t = maxf(_hint_land_t - _delta, 0.0)
	_tick_detail_title_flash()
	_tick_detail_stats_flash()
	_tick_hint_land()
	var t := Time.get_ticks_msec() * 0.002
	var dynasty_enter := (_dynasty_pull_ids.has(_selected_id) or _dynasty_replay_ids.has(_selected_id)) and not _enter_btn.disabled
	var sect_replay := _sect_replay_ids.has(_selected_id) and not _enter_btn.disabled
	var pop := clampf(_enter_gold_pop_t / 0.38, 0.0, 1.0)
	var land := clampf(_enter_land_t / 0.55, 0.0, 1.0)
	var replay := _dynasty_replay_ids.has(_selected_id)
	if land > 0.0 and _enter_land_teal and not _enter_btn.disabled:
		# Courtyard teal pop on 开战 — pairs focus-row teal, not gold dynasty.
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02)
		_enter_btn.modulate = Color(0.5 + 0.2 * pulse, 1.08 + 0.12 * pulse, 0.95 + 0.08 * pulse)
		_enter_btn.pivot_offset = _enter_btn.size * 0.5
		var st := 1.0 + 0.08 * land * pulse
		_enter_btn.scale = Vector2(st, st)
		_enter_btn.add_theme_color_override("font_color", Color(0.4, 0.98, 0.9, 0.75 + 0.25 * land))
	elif dynasty_enter:
		# Warm-gold breath — 首通 louder; 再战 slightly quieter settle.
		var hz := 2.05 if not replay else 1.75
		var amp := 0.14 if not replay else 0.1
		var g := 1.0 + amp * sin(t * hz) + 0.22 * pop
		_enter_btn.modulate = Color(minf(g * 1.25, 1.55), minf(g * 0.92, 1.25), minf(g * 0.55, 0.98))
		_enter_btn.pivot_offset = _enter_btn.size * 0.5
		var s := 1.0 + (0.04 if not replay else 0.03) * sin(t * hz) + 0.1 * pop
		_enter_btn.scale = Vector2(s, s)
		_enter_btn.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9 + 0.06 * pop, 0.48 + 0.1 * pop)
		)
	elif sect_replay:
		# Courtyard teal breath — 宗门再战 mirrors dynasty 再战 gold.
		var hz_t := 1.75
		var gt := 1.0 + 0.1 * sin(t * hz_t) + 0.12 * land
		_enter_btn.modulate = Color(0.55 + 0.1 * gt, minf(gt * 1.1, 1.35), minf(gt * 1.05, 1.28))
		_enter_btn.pivot_offset = _enter_btn.size * 0.5
		var st2 := 1.0 + 0.03 * sin(t * hz_t) + 0.06 * land
		_enter_btn.scale = Vector2(st2, st2)
		_enter_btn.add_theme_color_override(
			"font_color",
			Color(0.4, 0.96, 0.88)
		)
	elif land > 0.0 and not _enter_land_teal and not _enter_btn.disabled:
		# Dynasty land punch when not in first-clear breath (再战).
		var gp := 1.0 + 0.2 * land
		_enter_btn.modulate = Color(minf(gp * 1.2, 1.5), minf(gp * 0.95, 1.22), minf(gp * 0.55, 1.0))
		_enter_btn.pivot_offset = _enter_btn.size * 0.5
		_enter_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	elif not _enter_btn.disabled:
		_enter_btn.scale = Vector2.ONE
		var g := 1.0 + 0.04 * sin(t)
		_enter_btn.modulate = Color(g, g * 0.96, g * 0.88)
	else:
		_enter_btn.scale = Vector2.ONE
		_enter_btn.modulate = Color(0.55, 0.55, 0.58)
	# Dynasty hint bar: warm-gold flash → soft breath (don't touch enter CTA).
	_tick_dynasty_hint(_delta, t)
	# Thumbnail: idle drift, hover brightens + eases toward the eye.
	var want_push := 1.0 if _thumb_hover and not _thumb_locked else 0.0
	_thumb_push = lerpf(_thumb_push, want_push, clampf(_delta * 8.0, 0.0, 1.0))
	if _thumb:
		_thumb.pivot_offset = _thumb.size * 0.5
		var drift := Vector2(sin(t * 0.35) * 2.0, cos(t * 0.28) * 1.5)
		var shove := Vector2(-5.0, -3.5) * _thumb_push
		var teal_pop := clampf(_thumb_teal_t / 0.7, 0.0, 1.0)
		var gold_pop := clampf(_thumb_gold_t / 0.7, 0.0, 1.0)
		var sect_idle := 0.0
		var city_idle := 0.0
		if _selected_id == "sect" and not _thumb_locked:
			# Soft courtyard lift — teal air vs dynasty gold hover shove.
			sect_idle = 0.2 + 0.18 * (0.5 + 0.5 * sin(t * 1.15))
		elif _selected_id == "country" and not _thumb_locked:
			# Soft city gold lift — counterpart to courtyard teal.
			city_idle = 0.2 + 0.18 * (0.5 + 0.5 * sin(t * 1.25))
		var teal_n := maxf(teal_pop, sect_idle)
		var gold_n := maxf(gold_pop, city_idle)
		var lift_n := maxf(teal_n, gold_n)
		_thumb.position = _thumb_base + drift + shove + Vector2(0.0, -4.5 * lift_n)
		_thumb.scale = Vector2.ONE * (1.0 + 0.022 * _thumb_push + 0.035 * lift_n)
		var lift := 1.0 + 0.14 * _thumb_push
		var tm := Color(
			minf(_thumb_base_mod.r * lift, 1.15),
			minf(_thumb_base_mod.g * lift, 1.12),
			minf(_thumb_base_mod.b * lift * 0.98, 1.1),
			_thumb_base_mod.a
		)
		if gold_n > 0.0 and gold_n >= teal_n:
			tm = tm.lerp(Color(1.08, 0.92, 0.62, _thumb_base_mod.a), 0.22 + 0.28 * gold_n)
		elif teal_n > 0.0:
			tm = tm.lerp(Color(0.72, 1.08, 1.02, _thumb_base_mod.a), 0.22 + 0.28 * teal_n)
		_thumb.modulate = tm
		if has_node("Root/MapFrame") and _mapframe_lock_t <= 0.0:
			_tick_mapframe_identity(t)
	# Pulse uncleared early stages — first-clear desire on the list itself.
	for child in _list.get_children():
		if not (child is Button):
			continue
		var b := child as Button
		var sid := str(b.get_meta("stage_id", ""))
		if b.disabled:
			continue
		var row_a := clampf(_row_flash_t / 0.72, 0.0, 1.0)
		if sid == _row_flash_id and row_a > 0.0:
			_paint_focus_row_flash(b, row_a)
			continue
		if _dynasty_pull_ids.has(sid) or _dynasty_replay_ids.has(sid):
			_pulse_dynasty_row(b, t, sid == _selected_id)
			continue
		if _sect_replay_ids.has(sid):
			_pulse_sect_row(b, t, sid == _selected_id)
			continue
		if not _pulse_ids.has(sid) or sid == _selected_id:
			continue
		var acc := Color.from_string(str(b.get_meta("accent", "#c0c0c0")), Color(0.9, 0.9, 0.9))
		var g2 := 1.0 + 0.06 * sin(t * 1.6 + float(sid.hash() % 7))
		b.modulate = Color(
			minf(acc.r * g2, 1.0),
			minf(acc.g * g2 * 0.98, 1.0),
			minf(acc.b * g2 * 0.92, 1.0),
		)
	if _back_btn and _should_push_hub_spend():
		var g3 := 1.0 + 0.08 * sin(t * 2.4)
		_back_btn.modulate = Color(minf(g3 * 1.1, 1.35), minf(g3 * 0.98, 1.2), minf(g3 * 0.75, 1.0))
		var s := 1.0 + 0.03 * sin(t * 2.4)
		_back_btn.scale = Vector2(s, s)
		_back_btn.pivot_offset = _back_btn.size * 0.5
	elif _back_btn:
		_back_btn.scale = Vector2.ONE
		_back_btn.modulate = Color.WHITE

func _ready() -> void:
	_UiStyle.apply_panel(_left_panel)
	if has_node("Root/MapFrame"):
		_UiStyle.apply_panel($Root/MapFrame, Color(0.55, 0.78, 0.88, 0.45))
	_UiStyle.apply_cta_button(_enter_btn)
	_UiStyle.apply_button(_back_btn)
	_enter_btn.pressed.connect(_on_enter)
	if _thumb:
		_thumb_base = _thumb.position
		_thumb.mouse_filter = Control.MOUSE_FILTER_STOP
		_thumb.mouse_entered.connect(_on_thumb_hover.bind(true))
		_thumb.mouse_exited.connect(_on_thumb_hover.bind(false))
	_build_list()
	_refresh_hint()
	var stages := ContentDB.stages.all_stages()
	# Hub「王朝 · 首通」→ land on country row when still uncleared.
	var picked := false
	var focus := GameState.stage_select_focus_id
	GameState.stage_select_focus_id = ""
	if not focus.is_empty():
		var focus_st := ContentDB.get_stage(focus)
		if focus_st and GameState.can_enter(focus_st) and not GameState.is_stage_cleared(focus):
			_select_stage(focus)
			picked = true
	# Prefer an early uncleared stage so first-clear bait is selected by default.
	if not picked:
		for stage in stages:
			if stage.id in ["sect", "country"] and GameState.can_enter(stage) and not GameState.is_stage_cleared(stage.id):
				_select_stage(stage.id)
				picked = true
				break
	if not picked:
		for stage in stages:
			if GameState.can_enter(stage):
				_select_stage(stage.id)
				break
	if _selected_id.is_empty() and not stages.is_empty():
		_select_stage(stages[0].id)
	# Auto-landed dynasty flash fires from _select_stage — no double punch here.
	_arm_focus_row_flash(_selected_id)
	_arm_enter_land_flash(_selected_id)
	_arm_sect_thumb_lift()
	_arm_dynasty_thumb_lift()
	_arm_detail_title_flash(_selected_id)
	_arm_detail_stats_flash(_selected_id)
	# Hub challenge / 收刀回流 → tip on stage select.
	var shoudao_tip := GameState.hub_shoudao_enter
	GameState.hub_shoudao_enter = false
	if shoudao_tip and _selected_id != "country":
		# Prefer 王朝 row so 收刀 tip lands on the map that earned it.
		var country_st := ContentDB.get_stage("country")
		if country_st and GameState.can_enter(country_st):
			_select_stage("country")
			_arm_focus_row_flash("country")
			_arm_enter_land_flash("country")
			_arm_dynasty_thumb_lift()
	if GameState.hub_fight_enter:
		GameState.hub_fight_enter = false
		call_deferred("_flash_hub_fight_tip", shoudao_tip)
	elif shoudao_tip:
		call_deferred("_flash_hub_fight_tip", true)

## Hub challenge CTA land → tip + 开战 punch (宗门青绿 / 王朝暖金 / 收刀回流).
func _flash_hub_fight_tip(shoudao: bool = false) -> void:
	var teal := _selected_id == "sect" and not shoudao
	# 收刀回流 forces warm-gold sheath language (not courtyard teal).
	if shoudao:
		teal = false
	if _enter_btn and not _enter_btn.disabled:
		if teal:
			_enter_btn.add_theme_color_override("font_color", Color(0.42, 0.98, 0.9))
			_enter_btn.modulate = Color(0.7, 1.28, 1.15)
			_enter_land_teal = true
			_enter_land_t = maxf(_enter_land_t, 0.55)
		else:
			_enter_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
			_enter_btn.modulate = Color(1.55, 1.28, 0.72) if shoudao else Color(1.45, 1.2, 0.72)
			_enter_gold_pop_t = maxf(_enter_gold_pop_t, 0.62 if shoudao else 0.55)
		_enter_btn.pivot_offset = _enter_btn.size * 0.5
		_enter_btn.scale = Vector2(0.88, 0.88)
		var etw := create_tween()
		etw.tween_property(_enter_btn, "scale", Vector2(1.14, 1.14), 0.11).set_trans(Tween.TRANS_BACK)
		etw.tween_property(_enter_btn, "scale", Vector2.ONE, 0.16)
	# Soft rim on left panel — teal courtyard / gold dynasty / hotter 收刀.
	var left_flat: StyleBoxFlat = null
	var rim0 := Color(0.42, 0.98, 0.9, 1.0) if teal else Color(1.0, 0.88, 0.38, 1.0)
	var rim1 := Color(0.45, 0.82, 0.78, 0.75) if teal else Color(0.95, 0.78, 0.4, 0.75)
	if _left_panel:
		var sb = _left_panel.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			left_flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			_left_panel.add_theme_stylebox_override("panel", left_flat)
			left_flat.border_color = rim0
			left_flat.set_border_width_all(3 if shoudao else 2)
		_left_panel.modulate = Color(0.8, 1.18, 1.12) if teal else Color(1.35, 1.18, 0.78)
	# Don't clobber dynasty pull breath hint; still shout tip + enter.
	var saved_hint := ""
	var saved_hint_col := Color(0.75, 0.82, 0.86)
	var hint_shout := "收刀 · 点开战" if shoudao else "开战到手 · 点开战"
	if _hint and not _dynasty_hint:
		saved_hint = _hint.text
		saved_hint_col = _hint.get_theme_color("font_color")
		_hint.text = hint_shout
		_hint.add_theme_color_override("font_color", Color(0.45, 0.95, 0.88) if teal else Color(1.0, 0.9, 0.48))
		_hint.modulate = Color(1.15, 1.3, 1.2) if teal else Color(1.5, 1.25, 0.78)
	var tip := get_node_or_null("FightTip") as Label
	if tip == null:
		tip = Label.new()
		tip.name = "FightTip"
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.position = Vector2(220, 4)
		tip.size = Vector2(220, 28)
		tip.add_theme_font_size_override("font_size", 15)
		add_child(tip)
	tip.visible = true
	tip.text = "收刀到手 · 选关" if shoudao else "开战到手 · 选关"
	tip.add_theme_color_override("font_color", Color(0.42, 0.96, 0.88) if teal else Color(1.0, 0.9, 0.42))
	tip.modulate = Color(1.2, 1.4, 1.25, 1.0) if teal else Color(1.6, 1.35, 0.75, 1.0)
	tip.scale = Vector2(0.82, 0.82)
	tip.pivot_offset = tip.size * 0.5
	var tw := create_tween()
	tw.tween_property(tip, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(tip, "scale", Vector2.ONE, 0.14)
	if _left_panel:
		tw.parallel().tween_property(_left_panel, "modulate", Color.WHITE, 0.45)
	if left_flat:
		tw.parallel().tween_method(
			func(a: float) -> void:
				if left_flat:
					left_flat.border_color = rim0.lerp(rim1, a)
					left_flat.set_border_width_all((3 if shoudao else 2) if a < 0.6 else 1),
			0.0,
			1.0,
			0.5
		)
	tw.tween_interval(1.05 if shoudao else 1.0)
	tw.tween_property(tip, "modulate:a", 0.0, 0.28)
	if _hint and not _dynasty_hint:
		tw.parallel().tween_property(_hint, "modulate", Color.WHITE, 0.28)
	tw.tween_callback(func() -> void:
		if tip:
			tip.visible = false
			tip.modulate = Color.WHITE
		if _hint and not _dynasty_hint and (_hint.text.begins_with("开战到手") or _hint.text.begins_with("收刀")):
			_hint.text = saved_hint
			_hint.add_theme_color_override("font_color", saved_hint_col)
			_hint.modulate = Color.WHITE
		if _left_panel:
			_UiStyle.apply_panel(_left_panel)
	)

## Hint bar land — soft teal/gold pop (pairs left panel; skips dynasty pull breath).
func _arm_hint_land_flash(sid: String) -> void:
	if sid != "sect" and sid != "country":
		return
	if _hint == null:
		return
	# Dynasty pull tip already has warm-gold flash → breath; don't double.
	if _dynasty_hint:
		_hint_land_t = 0.0
		return
	_hint_land_teal = sid == "sect"
	_hint_land_t = 0.45

func _tick_hint_land() -> void:
	if _hint == null or _dynasty_hint:
		return
	var a := clampf(_hint_land_t / 0.45, 0.0, 1.0)
	if a <= 0.0:
		if _hint.modulate != Color.WHITE or _hint.scale != Vector2.ONE:
			_hint.modulate = Color.WHITE
			_hint.scale = Vector2.ONE
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.022)
	_hint.pivot_offset = _hint.size * 0.5
	_hint.scale = Vector2.ONE * (1.0 + 0.055 * a)
	if _hint_land_teal:
		_hint.modulate = Color(0.72 + 0.2 * pulse, 1.08 + 0.1 * pulse, 1.02 + 0.06 * pulse)
		_hint.add_theme_color_override(
			"font_color",
			Color(0.45, 0.95, 0.88).lerp(Color(0.75, 0.82, 0.86), 1.0 - a)
		)
	else:
		_hint.modulate = Color(1.18 + 0.15 * pulse, 1.0 + 0.08 * pulse, 0.68 + 0.08 * pulse)
		_hint.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9, 0.42).lerp(Color(1.0, 0.9, 0.55), 1.0 - a)
		)

## Left list panel — soft teal/gold rim glow on land (pairs detail text).
func _arm_left_panel_flash(sid: String) -> void:
	if sid != "sect" and sid != "country":
		return
	call_deferred("_flash_left_panel", sid == "sect")

func _flash_left_panel(teal: bool) -> void:
	if _left_panel == null:
		return
	var sb := _left_panel.get_theme_stylebox("panel")
	var flat: StyleBoxFlat = null
	if sb is StyleBoxFlat:
		flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		_left_panel.add_theme_stylebox_override("panel", flat)
	var punch := Color(0.42, 0.98, 0.9, 1.0) if teal else Color(1.0, 0.88, 0.4, 1.0)
	var settle := Color(0.45, 0.82, 0.78, 0.72) if teal else Color(0.95, 0.78, 0.4, 0.72)
	if flat:
		flat.border_color = punch
		flat.set_border_width_all(2)
	_left_panel.modulate = Color(0.8, 1.18, 1.12) if teal else Color(1.28, 1.12, 0.82)
	var tw := create_tween()
	tw.tween_property(_left_panel, "modulate", Color.WHITE, 0.42)
	if flat:
		tw.parallel().tween_method(
			func(a: float) -> void:
				if flat:
					flat.border_color = punch.lerp(settle, a)
					flat.set_border_width_all(2 if a < 0.55 else 1),
			0.0,
			1.0,
			0.45
		)

## Detail title land — courtyard teal vs city gold (pairs thumbnail lift).
func _arm_detail_title_flash(sid: String) -> void:
	if sid != "sect" and sid != "country":
		return
	if _detail_title == null:
		return
	_title_flash_teal = sid == "sect"
	_title_flash_t = 0.55
	call_deferred("_pop_detail_title")

func _pop_detail_title() -> void:
	if _detail_title == null:
		return
	_detail_title.pivot_offset = _detail_title.size * 0.5
	_detail_title.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.tween_property(_detail_title, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_detail_title, "scale", Vector2.ONE, 0.16)

func _tick_detail_title_flash() -> void:
	if _detail_title == null:
		return
	var a := clampf(_title_flash_t / 0.55, 0.0, 1.0)
	if a <= 0.0:
		if _detail_title.modulate != Color.WHITE:
			_detail_title.modulate = Color.WHITE
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02)
	_detail_title.pivot_offset = _detail_title.size * 0.5
	if _title_flash_teal:
		_detail_title.modulate = Color(0.7 + 0.15 * pulse, 1.1 + 0.1 * pulse, 1.05 + 0.08 * pulse)
		_detail_title.add_theme_color_override(
			"font_color",
			Color(0.42, 0.98, 0.9).lerp(Color(0.55, 0.88, 0.82), 1.0 - a)
		)
	else:
		_detail_title.modulate = Color(1.2 + 0.15 * pulse, 1.0 + 0.08 * pulse, 0.7 + 0.08 * pulse)
		_detail_title.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9, 0.42).lerp(Color(0.95, 0.82, 0.45), 1.0 - a)
		)

## Detail stats land — softer teal/gold echo under the title.
func _arm_detail_stats_flash(sid: String) -> void:
	if sid != "sect" and sid != "country":
		return
	if _detail_stats == null:
		return
	_stats_flash_teal = sid == "sect"
	_stats_flash_t = 0.48
	call_deferred("_pop_detail_stats")

func _pop_detail_stats() -> void:
	if _detail_stats == null:
		return
	_detail_stats.pivot_offset = _detail_stats.size * 0.5
	_detail_stats.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.tween_interval(0.04)
	tw.tween_property(_detail_stats, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_detail_stats, "scale", Vector2.ONE, 0.14)

func _tick_detail_stats_flash() -> void:
	if _detail_stats == null:
		return
	var a := clampf(_stats_flash_t / 0.48, 0.0, 1.0)
	if a <= 0.0:
		if _detail_stats.modulate != Color.WHITE:
			_detail_stats.modulate = Color.WHITE
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.018)
	_detail_stats.pivot_offset = _detail_stats.size * 0.5
	if _stats_flash_teal:
		_detail_stats.modulate = Color(0.75 + 0.12 * pulse, 1.05 + 0.08 * pulse, 1.0 + 0.06 * pulse)
		_detail_stats.add_theme_color_override(
			"font_color",
			Color(0.5, 0.95, 0.88).lerp(Color(0.72, 0.86, 0.88), 1.0 - a)
		)
	else:
		_detail_stats.modulate = Color(1.12 + 0.12 * pulse, 0.98 + 0.06 * pulse, 0.72 + 0.06 * pulse)
		_detail_stats.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9, 0.5).lerp(Color(0.88, 0.84, 0.72), 1.0 - a)
		)

## 开战 CTA land — courtyard teal vs city gold (pairs list-row flash).
func _arm_enter_land_flash(sid: String) -> void:
	if sid != "sect" and sid != "country":
		return
	if _enter_btn == null or _enter_btn.disabled:
		return
	_enter_land_teal = sid == "sect"
	_enter_land_t = 0.55
	if not _enter_land_teal:
		_enter_gold_pop_t = maxf(_enter_gold_pop_t, 0.45)
	call_deferred("_pop_enter_land")

func _pop_enter_land() -> void:
	if _enter_btn == null or _enter_btn.disabled:
		return
	_enter_btn.pivot_offset = _enter_btn.size * 0.5
	_enter_btn.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(_enter_btn, "scale", Vector2(1.08, 1.08), 0.11).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_enter_btn, "scale", Vector2.ONE, 0.16)

## Sect thumbnail — brief extra teal lift on land (not MapFrame flash).
func _arm_sect_thumb_lift() -> void:
	if _selected_id != "sect" or _thumb == null or _thumb_locked:
		return
	_thumb_teal_t = 0.7

## Dynasty thumbnail — brief extra gold lift on land (mirrors sect teal).
func _arm_dynasty_thumb_lift() -> void:
	if _selected_id != "country" or _thumb == null or _thumb_locked:
		return
	_thumb_gold_t = 0.7

## Focus list row: courtyard teal vs city gold — hub CTA echo on 选关.
func _arm_focus_row_flash(sid: String) -> void:
	if sid != "sect" and sid != "country":
		return
	_row_flash_teal = sid == "sect"
	_row_flash_id = sid
	_row_flash_t = 0.72
	call_deferred("_pop_focus_row")

func _pop_focus_row() -> void:
	var b := _find_row_button(_row_flash_id)
	if b == null:
		return
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(1.06, 1.06), 0.11).set_trans(Tween.TRANS_BACK)
	tw.tween_property(b, "scale", Vector2.ONE, 0.16)

func _find_row_button(sid: String) -> Button:
	if _list == null:
		return null
	for child in _list.get_children():
		if not (child is Button):
			continue
		if str((child as Button).get_meta("stage_id", "")) == sid:
			return child as Button
	return null

func _paint_focus_row_flash(b: Button, a: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
	if _row_flash_teal:
		b.modulate = Color(0.5 + 0.15 * pulse, 1.05 + 0.12 * pulse, 0.95 + 0.08 * pulse)
		b.add_theme_color_override("font_color", Color(0.4, 0.98, 0.9, 0.75 + 0.25 * a))
		var bar := _ensure_dynasty_side_bar(b)
		bar.color = Color(0.4, 0.95, 0.88, 0.55 + 0.45 * a)
	else:
		b.modulate = Color(1.25 + 0.2 * pulse, 0.98 + 0.1 * pulse, 0.5 + 0.08 * pulse)
		b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.42, 0.75 + 0.25 * a))
		var bar2 := _ensure_dynasty_side_bar(b)
		bar2.color = Color(1.0, 0.84, 0.38, 0.6 + 0.4 * a)
	b.queue_redraw()

## Preview MapFrame idle — courtyard teal rim breath vs soft generic/city gold.
func _tick_mapframe_identity(t: float) -> void:
	var frame := $Root/MapFrame as PanelContainer
	if frame == null:
		return
	var push := 0.08 * _thumb_push
	if _selected_id == "sect":
		# Soft courtyard teal border — identity while resting on 宗门.
		var breath := 0.5 + 0.5 * sin(t * 1.25)
		frame.modulate = Color(0.88 + 0.1 * breath + push, 1.06 + 0.12 * breath + push * 0.7, 1.02 + 0.1 * breath)
		var sb := frame.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var flat := sb as StyleBoxFlat
			flat.border_color = Color(0.38, 0.95, 0.88, 0.52 + 0.38 * breath)
			flat.set_border_width_all(2)
	elif _selected_id == "country":
		# Soft city gold border — mirror courtyard teal rim while resting on 王朝.
		var breath_g := 0.5 + 0.5 * sin(t * 1.35)
		frame.modulate = Color(1.06 + 0.1 * breath_g + push, 0.94 + 0.06 * breath_g + push * 0.5, 0.72 + 0.04 * breath_g)
		var sb_g := frame.get_theme_stylebox("panel")
		if sb_g is StyleBoxFlat:
			var flat_g := sb_g as StyleBoxFlat
			flat_g.border_color = Color(1.0, 0.84, 0.38, 0.52 + 0.38 * breath_g)
			flat_g.set_border_width_all(2)
	else:
		frame.modulate = Color(1.0 + push, 1.0 + push * 0.75, 1.0 + push * 0.25)

## Preview MapFrame: brief warm-gold border punch after hub dynasty focus / select.
func _flash_dynasty_preview_frame() -> void:
	if not has_node("Root/MapFrame"):
		return
	var frame := $Root/MapFrame as PanelContainer
	if frame == null:
		return
	_mapframe_lock_t = 0.52
	var sb := frame.get_theme_stylebox("panel")
	var flat: StyleBoxFlat = null
	if sb is StyleBoxFlat:
		flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		frame.add_theme_stylebox_override("panel", flat)
	# Hot city gold — louder land punch than idle rim breath (mirrors sect teal).
	var gold := Color(1.0, 0.9, 0.38, 1.0)
	var settle := Color(0.95, 0.78, 0.4, 0.78)
	if flat:
		flat.border_color = gold
		flat.set_border_width_all(4)
		flat.bg_color = Color(0.18, 0.12, 0.05, 0.55)
	frame.modulate = Color(1.48, 1.28, 0.78)
	var tw := create_tween()
	tw.tween_property(frame, "modulate", Color(1.08, 1.0, 0.88), 0.4)
	if flat:
		tw.parallel().tween_method(
			func(a: float) -> void:
				if flat:
					flat.border_color = gold.lerp(settle, a)
					flat.set_border_width_all(4 if a < 0.35 else 2),
			0.0,
			1.0,
			0.48
		)
	# Sync 开战 CTA punch with the preview flash (breath resumes after).
	_pop_enter_gold_with_preview()

## Preview MapFrame: courtyard teal border punch when landing on 宗门.
func _flash_sect_preview_frame() -> void:
	if not has_node("Root/MapFrame"):
		return
	var frame := $Root/MapFrame as PanelContainer
	if frame == null:
		return
	_mapframe_lock_t = 0.52
	var sb := frame.get_theme_stylebox("panel")
	var flat: StyleBoxFlat = null
	if sb is StyleBoxFlat:
		flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		frame.add_theme_stylebox_override("panel", flat)
	# Hot courtyard teal — louder land punch than idle rim breath.
	var teal := Color(0.35, 1.0, 0.92, 1.0)
	var settle := Color(0.4, 0.92, 0.86, 0.78)
	if flat:
		flat.border_color = teal
		flat.set_border_width_all(4)
		flat.bg_color = Color(0.08, 0.16, 0.15, 0.55)
	frame.modulate = Color(0.68, 1.35, 1.22)
	var tw := create_tween()
	tw.tween_property(frame, "modulate", Color(0.92, 1.08, 1.05), 0.4)
	if flat:
		tw.parallel().tween_method(
			func(a: float) -> void:
				if flat:
					flat.border_color = teal.lerp(settle, a)
					flat.set_border_width_all(4 if a < 0.35 else 2),
			0.0,
			1.0,
			0.48
		)
	# Sync 开战 teal pop with MapFrame — pairs dynasty gold preview punch.
	_pop_enter_teal_with_preview()

## One courtyard-teal land kick on 开战 — pairs MapFrame flash.
func _pop_enter_teal_with_preview() -> void:
	if _enter_btn == null or _enter_btn.disabled:
		return
	_enter_land_teal = true
	_enter_land_t = maxf(_enter_land_t, 0.42)
	_enter_btn.pivot_offset = _enter_btn.size * 0.5
	_enter_btn.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(_enter_btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_enter_btn, "scale", Vector2.ONE, 0.15)

## One warm-gold scale punch on 开战 — pairs MapFrame flash, then breath continues.
func _pop_enter_gold_with_preview() -> void:
	if _enter_btn == null or _enter_btn.disabled:
		return
	_enter_gold_pop_t = 0.38
	# Half-second label shout — hub CTA language lands on the fight button.
	_flash_enter_dynasty_label()

## 「王朝首通」/「王朝再战」for ~0.5s then settle back.
func _flash_enter_dynasty_label() -> void:
	if _enter_btn == null or _enter_btn.disabled:
		return
	if _selected_id != "country":
		return
	var cleared := GameState.is_stage_cleared("country")
	_enter_btn.text = "王朝再战" if cleared else "王朝首通"
	_enter_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	var restore := func() -> void:
		if _enter_btn == null or _enter_btn.disabled:
			return
		if _selected_id != "country":
			return
		var st := ContentDB.get_stage("country")
		if st == null or not GameState.can_enter(st):
			return
		if GameState.is_stage_cleared("country"):
			_enter_btn.text = "再战"
		else:
			_enter_btn.text = "首通"
	get_tree().create_timer(0.5, true).timeout.connect(restore)

## 「宗门再战」for ~0.5s then settle back to「再战」.
func _flash_enter_sect_replay_label() -> void:
	if _enter_btn == null or _enter_btn.disabled:
		return
	if _selected_id != "sect":
		return
	if not GameState.is_stage_cleared("sect"):
		return
	_enter_btn.text = "宗门再战"
	_enter_btn.add_theme_color_override("font_color", Color(0.42, 0.98, 0.9))
	var restore := func() -> void:
		if _enter_btn == null or _enter_btn.disabled:
			return
		if _selected_id != "sect":
			return
		if GameState.is_stage_cleared("sect"):
			_enter_btn.text = "再战"
	get_tree().create_timer(0.5, true).timeout.connect(restore)

func _should_push_hub_spend() -> bool:
	var stones := GameState.spirit_stones
	if stones < 5:
		return false
	# After clearing an early stage, pull back to hub shops.
	for sid in ["sect", "country"]:
		if GameState.is_stage_cleared(sid):
			return true
	return GameState.hub_celebrate_stones > 0 or GameState.last_clear_first

func _estimate_clear_stones(stage: StageDef) -> int:
	var g := ContentDB.section("growth")
	var stones := int(g.get("stage_clear_stones_base", 15)) + stage.order * int(g.get("stage_clear_stones_per_order", 8))
	stones += int(g.get("stage_clear_first_bonus", 8))
	if stage.id in ["sect", "country"]:
		stones += int(g.get("early_clear_stones_bonus", 8))
		stones += int(g.get("early_first_clear_extra", 10))
	return stones

func _pulse_dynasty_row(b: Button, t: float, selected: bool) -> void:
	# Warm-gold outline breath — half-beat snappier, matches hub dynasty CTA.
	var pulse := 0.55 + 0.45 * sin(t * 2.05)
	var gold := Color(1.0, 0.78 + 0.14 * pulse, 0.32, 0.75 + 0.25 * pulse)
	if selected:
		gold = Color(1.0, 0.9, 0.45, 0.95)
	for key in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(key)
		if sb is StyleBoxFlat:
			var flat := sb as StyleBoxFlat
			flat.border_color = gold
			flat.set_border_width_all(3 if selected else 2)
			flat.bg_color = Color(0.22, 0.16, 0.08, 0.96) if selected else Color(0.18, 0.14, 0.08, 0.94)
	var lift := 1.1 + 0.12 * pulse
	b.modulate = Color(minf(lift, 1.4), minf(lift * 0.9, 1.22), minf(lift * 0.65, 1.0))
	# Left rail breathes — short gold pip, not a full border rewrite.
	var bar := _ensure_dynasty_side_bar(b)
	var a := 0.55 + 0.4 * pulse
	if selected:
		a = 0.85 + 0.15 * pulse
	bar.color = Color(1.0, 0.82 + 0.12 * pulse, 0.32 + 0.1 * pulse, a)
	bar.offset_top = 7.0 - 2.0 * pulse
	bar.offset_bottom = -7.0 + 2.0 * pulse
	b.queue_redraw()

func _pulse_sect_row(b: Button, t: float, selected: bool) -> void:
	# Courtyard teal outline breath — mirrors dynasty gold 再战 row.
	var pulse := 0.55 + 0.45 * sin(t * 1.75)
	var teal := Color(0.38, 0.9 + 0.08 * pulse, 0.84, 0.7 + 0.25 * pulse)
	if selected:
		teal = Color(0.45, 0.98, 0.9, 0.95)
	for key in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(key)
		if sb is StyleBoxFlat:
			var flat := sb as StyleBoxFlat
			flat.border_color = teal
			flat.set_border_width_all(3 if selected else 2)
			flat.bg_color = Color(0.08, 0.2, 0.18, 0.96) if selected else Color(0.06, 0.16, 0.15, 0.94)
	var lift := 1.08 + 0.1 * pulse
	b.modulate = Color(0.7 + 0.15 * lift, minf(lift, 1.35), minf(lift * 0.95, 1.28))
	var bar := _ensure_sect_side_bar(b)
	var a := 0.5 + 0.35 * pulse
	if selected:
		a = 0.8 + 0.15 * pulse
	bar.color = Color(0.4, 0.95 + 0.04 * pulse, 0.88, a)
	bar.offset_top = 7.0 - 2.0 * pulse
	bar.offset_bottom = -7.0 + 2.0 * pulse
	b.queue_redraw()

func _is_dynasty_pull(stage: StageDef) -> bool:
	if stage == null or stage.id != "country":
		return false
	if not GameState.is_stage_cleared("sect"):
		return false
	if GameState.is_stage_cleared("country"):
		return false
	return GameState.can_enter(stage)

## Dynasty cleared — warm-gold「再战」bait (pairs 收刀回流, quieter than 首通).
func _is_dynasty_replay(stage: StageDef) -> bool:
	if stage == null or stage.id != "country":
		return false
	return GameState.can_enter(stage) and GameState.is_stage_cleared("country")

## Sect cleared — courtyard teal「再战」bait (mirrors dynasty gold replay).
func _is_sect_replay(stage: StageDef) -> bool:
	if stage == null or stage.id != "sect":
		return false
	return GameState.can_enter(stage) and GameState.is_stage_cleared("sect")

func _refresh_hint() -> void:
	var early_open := 0
	var early_done := 0
	for sid in ["sect", "country"]:
		var st := ContentDB.get_stage(sid)
		if st == null:
			continue
		if GameState.can_enter(st):
			early_open += 1
		if GameState.is_stage_cleared(sid):
			early_done += 1
	var country := ContentDB.get_stage("country")
	if _is_dynasty_pull(country):
		_hint.text = "外门已通 · 王朝首通"
		_hint.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		if not _dynasty_hint:
			_dynasty_hint = true
			_dynasty_hint_flash_t = 0.48
		if _back_btn:
			_back_btn.text = "回宗门"
			_UiStyle.apply_button(_back_btn)
	elif _is_dynasty_replay(country):
		# Soft gold hint — 再战 loop after 收刀, quieter than 首通 pull.
		_hint.text = "收刀已通 · 王朝再战"
		_hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
		if not _dynasty_hint:
			_dynasty_hint = true
			_dynasty_hint_flash_t = 0.36
		if _back_btn:
			_back_btn.text = "回宗门"
			_UiStyle.apply_button(_back_btn)
	elif _selected_id == "sect" and _is_sect_replay(ContentDB.get_stage("sect")):
		# Teal hint when focusing cleared 宗门 — doesn't steal dynasty bait copy.
		_clear_dynasty_hint_state()
		_hint.text = "庭院已通 · 宗门再战"
		_hint.add_theme_color_override("font_color", Color(0.45, 0.95, 0.88))
		if _back_btn:
			_back_btn.text = "回宗门"
			_UiStyle.apply_button(_back_btn)
	elif _should_push_hub_spend():
		_clear_dynasty_hint_state()
		_hint.text = "石 %d · 回宗花石" % GameState.spirit_stones
		_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		if _back_btn:
			_back_btn.text = "回宗花石"
			_UiStyle.apply_primary_button(_back_btn)
	elif early_done < early_open:
		_clear_dynasty_hint_state()
		_hint.text = "首通有石 · 开至第 %d 层" % GameState.unlocked_order
		_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		if _back_btn:
			_back_btn.text = "回宗门"
			_UiStyle.apply_button(_back_btn)
	else:
		_clear_dynasty_hint_state()
		_hint.text = "开至第 %d 层" % GameState.unlocked_order
		_hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.86))
		if _back_btn:
			_back_btn.text = "回宗门"
			_UiStyle.apply_button(_back_btn)
			_back_btn.modulate = Color.WHITE

func _clear_dynasty_hint_state() -> void:
	_dynasty_hint = false
	_dynasty_hint_flash_t = 0.0
	if _hint:
		_hint.scale = Vector2.ONE
		_hint.modulate = Color.WHITE

## Hint bar: one warm-gold pop, then soft breath (pairs hub 外门已通).
func _tick_dynasty_hint(delta: float, t: float) -> void:
	if _hint == null or not _dynasty_hint:
		return
	if _dynasty_hint_flash_t > 0.0:
		_dynasty_hint_flash_t = maxf(_dynasty_hint_flash_t - delta, 0.0)
	var flash := clampf(_dynasty_hint_flash_t / 0.48, 0.0, 1.0)
	var breath := 0.5 + 0.5 * sin(t * 2.05)
	var g := breath * (1.0 - flash * 0.35) + flash
	_hint.pivot_offset = _hint.size * 0.5
	_hint.modulate = Color(minf(1.15 + 0.35 * g, 1.55), minf(0.95 + 0.2 * g, 1.25), minf(0.55 + 0.15 * g, 1.0))
	_hint.scale = Vector2.ONE * (1.0 + 0.08 * flash + 0.03 * breath)
	_hint.add_theme_color_override(
		"font_color",
		Color(1.0, 0.82 + 0.14 * g, 0.35 + 0.18 * g)
	)

func _build_list() -> void:
	_pulse_ids.clear()
	_dynasty_pull_ids.clear()
	_dynasty_replay_ids.clear()
	_sect_replay_ids.clear()
	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.queue_free()
	for stage in ContentDB.stages.all_stages():
		_list.add_child(_make_map_button(stage))

func _make_map_button(stage: StageDef) -> Control:
	var unlocked := GameState.can_enter(stage)
	var cleared := GameState.is_stage_cleared(stage.id)
	var early := stage.id in ["sect", "country"]
	var dynasty_pull := _is_dynasty_pull(stage)
	var dynasty_replay := _is_dynasty_replay(stage)
	var sect_replay := _is_sect_replay(stage)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var mark := "·"
	if not unlocked:
		mark = "·"
	elif dynasty_pull:
		mark = "金"
		_pulse_ids[stage.id] = true
		_dynasty_pull_ids[stage.id] = true
	elif dynasty_replay:
		mark = "再"
		_dynasty_replay_ids[stage.id] = true
	elif sect_replay:
		mark = "再"
		_sect_replay_ids[stage.id] = true
	elif early and not cleared:
		mark = "首"
		_pulse_ids[stage.id] = true
	elif early and cleared:
		mark = "通"
	elif cleared:
		mark = "◆"
	else:
		mark = "○"
	btn.text = "%s  %s" % [mark, stage.display_name]
	if dynasty_pull:
		btn.text = "金  王朝 · 首通"
	elif dynasty_replay:
		btn.text = "再  王朝 · 再战"
	elif sect_replay:
		btn.text = "再  宗门 · 再战"
	btn.disabled = not unlocked
	btn.set_meta("stage_id", stage.id)
	var accent := stage.accent
	if dynasty_pull or dynasty_replay:
		accent = "#f0c45a"
	elif sect_replay:
		accent = "#55e8d0"
	btn.set_meta("accent", accent)
	btn.set_meta("dynasty_pull", dynasty_pull)
	btn.set_meta("dynasty_replay", dynasty_replay)
	btn.set_meta("sect_replay", sect_replay)
	_UiStyle.apply_button(btn)
	if dynasty_pull or dynasty_replay:
		_apply_dynasty_row_style(btn)
	elif sect_replay:
		_apply_sect_row_style(btn)
	elif unlocked and early and not cleared:
		_UiStyle.apply_primary_button(btn)
	if unlocked:
		btn.modulate = Color.from_string(str(btn.get_meta("accent")), Color(0.92, 0.88, 0.75))
	else:
		var acc := Color.from_string(stage.accent, Color(0.5, 0.55, 0.6))
		btn.modulate = Color(acc.r * 0.45, acc.g * 0.45, acc.b * 0.5, 0.85)
	var sid := stage.id
	btn.pressed.connect(func() -> void: _select_stage(sid))
	return btn

func _apply_dynasty_row_style(btn: Button) -> void:
	var n := _UiStyle.button_normal()
	n.bg_color = Color(0.2, 0.14, 0.07, 0.96)
	n.border_color = Color(1.0, 0.82, 0.38, 0.95)
	n.set_border_width_all(2)
	var h := _UiStyle.button_hover()
	h.bg_color = Color(0.28, 0.2, 0.1, 1.0)
	h.border_color = Color(1.0, 0.92, 0.5, 1.0)
	h.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.75))
	_ensure_dynasty_side_bar(btn)

## Courtyard teal row — 宗门再战 mirrors dynasty gold row.
func _apply_sect_row_style(btn: Button) -> void:
	var n := _UiStyle.button_normal()
	n.bg_color = Color(0.06, 0.16, 0.15, 0.96)
	n.border_color = Color(0.4, 0.95, 0.88, 0.95)
	n.set_border_width_all(2)
	var h := _UiStyle.button_hover()
	h.bg_color = Color(0.1, 0.22, 0.2, 1.0)
	h.border_color = Color(0.55, 1.0, 0.94, 1.0)
	h.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", Color(0.45, 0.98, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.95))
	_ensure_sect_side_bar(btn)

## Short warm-gold rail on the left — breathes with dynasty row pulse.
func _ensure_dynasty_side_bar(btn: Button) -> ColorRect:
	var bar := btn.get_node_or_null("DynastyBar") as ColorRect
	if bar:
		return bar
	bar = ColorRect.new()
	bar.name = "DynastyBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar.anchor_top = 0.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 3.0
	bar.offset_right = 6.0
	bar.offset_top = 7.0
	bar.offset_bottom = -7.0
	bar.color = Color(1.0, 0.84, 0.4, 0.9)
	bar.z_index = 1
	btn.add_child(bar)
	return bar

## Short teal rail — breathes with 宗门再战 row pulse.
func _ensure_sect_side_bar(btn: Button) -> ColorRect:
	var bar := btn.get_node_or_null("SectBar") as ColorRect
	if bar:
		return bar
	bar = ColorRect.new()
	bar.name = "SectBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar.anchor_top = 0.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 3.0
	bar.offset_right = 6.0
	bar.offset_top = 7.0
	bar.offset_bottom = -7.0
	bar.color = Color(0.4, 0.95, 0.88, 0.9)
	bar.z_index = 1
	btn.add_child(bar)
	return bar

func _select_stage(stage_id: String) -> void:
	_selected_id = stage_id
	var stage := ContentDB.get_stage(stage_id)
	if stage == null:
		return
	var accent_col := Color.from_string(stage.accent, Color(0.55, 0.78, 0.88))
	if has_node("Root/MapFrame"):
		# Courtyard teal / city gold panel base so idle rim reads as identity, not generic accent.
		if stage_id == "sect":
			_UiStyle.apply_panel($Root/MapFrame, Color(0.38, 0.9, 0.84, 0.58))
		elif stage_id == "country":
			_UiStyle.apply_panel($Root/MapFrame, Color(0.95, 0.78, 0.38, 0.58))
		else:
			_UiStyle.apply_panel($Root/MapFrame, Color(accent_col.r, accent_col.g, accent_col.b, 0.55))
	for child in _list.get_children():
		if not (child is Button):
			continue
		var b := child as Button
		var sid := str(b.get_meta("stage_id", ""))
		var accent := str(b.get_meta("accent", "#c0c0c0"))
		var acc := Color.from_string(accent, Color(0.9, 0.9, 0.9))
		if b.disabled:
			b.modulate = Color(acc.r * 0.45, acc.g * 0.45, acc.b * 0.5, 0.85)
		elif sid == stage_id:
			b.modulate = Color(
				minf(acc.r * 1.08 + 0.08, 1.0),
				minf(acc.g * 1.05 + 0.06, 1.0),
				minf(acc.b * 0.95 + 0.05, 1.0),
			)
		else:
			b.modulate = acc
	var unlocked := GameState.can_enter(stage)
	var cleared := GameState.is_stage_cleared(stage.id)
	var early := stage.id in ["sect", "country"]
	_detail_title.text = stage.display_name
	_detail_title.add_theme_color_override("font_color", accent_col.lightened(0.15))
	var boss_name := "—"
	if not stage.boss_id.is_empty():
		var boss := ContentDB.get_enemy(stage.boss_id)
		boss_name = boss.display_name if boss else stage.boss_id
	var status := "已通关"
	if not unlocked:
		status = "未解锁"
	elif early and not cleared:
		status = "首通 +%d石" % _estimate_clear_stones(stage)
	elif not cleared:
		status = "可进入"
	elif early and cleared:
		status = "已通 · 可花石"
	_detail_stats.text = "杀 %d · %s\n%s" % [stage.kill_target, boss_name, status]
	_detail_stats.add_theme_color_override(
		"font_color",
		Color(1.0, 0.92, 0.55) if (early and not cleared and unlocked) else Color(0.84, 0.88, 0.92, 0.95)
	)
	_enter_btn.tooltip_text = stage.description if not stage.description.is_empty() else stage.lore
	var bg_path := stage.background_path()
	_thumb_locked = not unlocked
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		_thumb.texture = load(bg_path)
		_thumb_base_mod = Color.WHITE if unlocked else Color(0.35, 0.35, 0.38)
	else:
		_thumb.texture = null
		_thumb_base_mod = Color(accent_col.r, accent_col.g, accent_col.b, 0.55)
	_thumb.modulate = _thumb_base_mod
	if has_node("Root/PreviewShade"):
		var shade := $Root/PreviewShade as ColorRect
		shade.color = Color(accent_col.r * 0.08, accent_col.g * 0.1, accent_col.b * 0.12, 0.68)
	if unlocked:
		_enter_btn.disabled = false
		if early and not cleared:
			_enter_btn.text = "首通"
		elif stage_id == "country" and cleared:
			# Warm-gold「再战」— dynasty clear loop CTA.
			_enter_btn.text = "再战"
			_enter_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
			_enter_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.7))
		elif stage_id == "sect" and cleared:
			# Courtyard teal「再战」— mirrors dynasty gold replay.
			_enter_btn.text = "再战"
			_enter_btn.add_theme_color_override("font_color", Color(0.42, 0.96, 0.88))
			_enter_btn.add_theme_color_override("font_hover_color", Color(0.65, 1.0, 0.95))
		elif cleared:
			_enter_btn.text = "再战"
		else:
			_enter_btn.text = "开战"
		_UiStyle.apply_cta_button(_enter_btn)
	else:
		_enter_btn.disabled = true
		_enter_btn.text = "锁定"
		_UiStyle.apply_cta_button(_enter_btn)
	_refresh_hint()
	if stage_id == "sect" and unlocked:
		_thumb_teal_t = maxf(_thumb_teal_t, 0.45)
		_arm_detail_title_flash("sect")
		_arm_detail_stats_flash("sect")
		_arm_left_panel_flash("sect")
		_arm_hint_land_flash("sect")
		# MapFrame courtyard teal punch every time 宗门 is focused.
		call_deferred("_flash_sect_preview_frame")
		# Cleared courtyard — shout「宗门再战」once on land.
		if GameState.is_stage_cleared("sect"):
			call_deferred("_flash_enter_sect_replay_label")
	elif stage_id == "country" and unlocked:
		_thumb_gold_t = maxf(_thumb_gold_t, 0.45)
		_arm_detail_title_flash("country")
		_arm_detail_stats_flash("country")
		_arm_left_panel_flash("country")
		_arm_hint_land_flash("country")
		# MapFrame city gold punch every time 王朝 is focused.
		call_deferred("_flash_dynasty_preview_frame")
		# Cleared dynasty — shout「王朝再战」once on land (pairs 收刀回流).
		if GameState.is_stage_cleared("country"):
			call_deferred("_flash_enter_dynasty_label")
	else:
		_title_flash_t = 0.0
		_stats_flash_t = 0.0
		_hint_land_t = 0.0
		if _detail_title:
			_detail_title.modulate = Color.WHITE
			_detail_title.scale = Vector2.ONE
		if _detail_stats:
			_detail_stats.modulate = Color.WHITE
			_detail_stats.scale = Vector2.ONE
		if _hint and not _dynasty_hint:
			_hint.modulate = Color.WHITE
			_hint.scale = Vector2.ONE
		if _left_panel:
			_left_panel.modulate = Color.WHITE
			_UiStyle.apply_panel(_left_panel)

func _on_thumb_hover(on: bool) -> void:
	_thumb_hover = on

func _on_enter() -> void:
	if _enter_handoff_busy:
		return
	if _selected_id.is_empty():
		return
	var stage := ContentDB.get_stage(_selected_id)
	if stage == null or not GameState.can_enter(stage):
		return
	_enter_handoff_busy = true
	# Carry teal/gold into combat start wipe — skip hub_fight tip redo.
	if _selected_id == "sect" or _selected_id == "country":
		GameState.combat_enter_handoff = _selected_id
	else:
		GameState.combat_enter_handoff = ""
	_play_enter_handoff(_selected_id)
	var sid := _selected_id
	var tw := create_tween()
	# Peak of wipe covers the cut — then combat greets with matching color.
	tw.tween_interval(0.13)
	tw.tween_callback(func() -> void:
		SceneManager.go_combat(sid)
	)

## Teal/gold sweep + 开战 punch before scene cut (pairs combat start wipe).
func _play_enter_handoff(sid: String) -> void:
	var teal := sid == "sect"
	var gold := sid == "country"
	if _enter_btn and not _enter_btn.disabled:
		_enter_btn.pivot_offset = _enter_btn.size * 0.5
		_enter_btn.scale = Vector2(0.9, 0.9)
		if teal:
			_enter_btn.modulate = Color(0.55, 1.15, 1.05)
			_enter_btn.add_theme_color_override("font_color", Color(0.4, 0.98, 0.9))
		elif gold:
			_enter_btn.modulate = Color(1.45, 1.2, 0.7)
			_enter_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
			_enter_gold_pop_t = maxf(_enter_gold_pop_t, 0.4)
		var etw := create_tween()
		etw.tween_property(_enter_btn, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
		etw.tween_property(_enter_btn, "scale", Vector2.ONE, 0.12)
	# Full-bleed wipe — same family as run_overlay `_wipe_teal/gold_flash`.
	if not teal and not gold:
		return
	var wipe := ColorRect.new()
	wipe.name = "EnterHandoffWipe"
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.color = Color(0.35, 0.92, 0.85, 0.5) if teal else Color(1.0, 0.82, 0.35, 0.55)
	wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	wipe.z_index = 80
	add_child(wipe)
	wipe.pivot_offset = Vector2(0, 180.0)
	wipe.scale = Vector2(0.08, 1.0)
	var wtw := wipe.create_tween()
	wtw.tween_property(wipe, "scale:x", 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Hold cover through the scene cut; combat continues the color.

func _on_back_pressed() -> void:
	SceneManager.go_hub()
