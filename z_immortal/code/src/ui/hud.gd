extends CanvasLayer

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _stage_label: Label = $Root/TopBar/Panel/StageLabel
@onready var _hp_fill: ColorRect = $Root/TopBar/Panel/HpRow/HpBarBg/HpBarFill
@onready var _hp_bg: ColorRect = $Root/TopBar/Panel/HpRow/HpBarBg
@onready var _kill_label: Label = $Root/TopBar/Panel/KillLabel
@onready var _kill_fill: ColorRect = $Root/TopBar/Panel/KillBarBg/KillBarFill
@onready var _stone_label: Label = get_node_or_null("Root/TopBar/Panel/StoneLabel")
@onready var _combo_label: Label = $Root/ComboLabel
@onready var _hint_label: Label = $Root/HintLabel
@onready var _clear: Label = $Root/ClearBanner
@onready var _boss_bar: PanelContainer = $Root/BossBar
@onready var _boss_name: Label = $Root/BossBar/VBox/BossName
@onready var _boss_hp_fill: ColorRect = $Root/BossBar/VBox/BossHpBg/BossHpFill
@onready var _skill_l: Label = $Root/SkillDock/SkillBar/KeyL/Body/SkillStack/SkillL
@onready var _skill_u: Label = $Root/SkillDock/SkillBar/KeyU/Body/SkillStack/SkillU
@onready var _skill_i: Label = $Root/SkillDock/SkillBar/KeyI/Body/SkillStack/SkillI
@onready var _skill_o: Label = $Root/SkillDock/SkillBar/KeyO/Body/SkillStack/SkillO
@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _skill_dock: PanelContainer = $Root/SkillDock
@onready var _kill_bg: ColorRect = $Root/TopBar/Panel/KillBarBg

const _SKILL_IDS := ["dash", "ring_slash", "use_pill", "spirit_burst"]
const _SKILL_KEYS := ["L", "U", "I", "O"]
const _KEY_NODES := ["KeyL", "KeyU", "KeyI", "KeyO"]
# Per-skill rim: cyan / gold / jade / ember — readable at a glance.
const _SKILL_ACCENTS := [
	Color(0.45, 0.82, 0.95, 0.9),
	Color(0.92, 0.78, 0.4, 0.9),
	Color(0.45, 0.88, 0.58, 0.9),
	Color(0.95, 0.5, 0.38, 0.9),
]
const _HP_BAR_W := 152.0
const _KILL_BAR_W := 152.0
const _KEY_H := 38.0
## Match minimap yard frame Color(0.45, 0.88, 0.82) — sect HUD ↔ radar cohesion.
const _SECT_TEAL := Color(0.45, 0.88, 0.82)
const _SECT_TEAL_FILL := Color(0.4, 0.86, 0.78)
const _SECT_TEAL_NEAR := Color(0.55, 0.95, 0.86)
const _CITY_GOLD := Color(0.9, 0.75, 0.4)
const _CITY_NEAR := Color(1.0, 0.82, 0.35)
## Match player.CRISIS_PULSE_HZ — one clock for edges / HP / silhouette / minimap.
const _CRISIS_PULSE_HZ := 0.007

var _skill_was_ready: Array[bool] = [true, true, true, true] # edge-detect CD→ready flash
var _skill_max_cd: Array[float] = [2.3, 4.4, 1.2, 7.2]
## KeyI empty-pill grey — track so we restyle only on edge.
var _pill_was_empty := false
var _stone_base_col := Color(0.68, 0.82, 0.9, 0.82)
var _stone_flashing := false
var _hp_heal_flashing := false
var _stone_pivot_ready := false
var _skill_cast_flash: Dictionary = {} # key node name -> remaining ignore ticks for modulate stomp
## Deny-flash throttle — avoid spam when mashing CD keys.
var _skill_deny_cool: Dictionary = {}
## Boss bar land — 赤金 rim punch when the bar first appears.
var _boss_bar_land_t := 0.0
var _boss_bar_land_flat: StyleBoxFlat = null
var _boss_hp_ratio := 1.0
## Boss 破绽 window — bar gold breath aligned with edge + minimap pip.
var _boss_break_t := 0.0
var _boss_break_max := 0.0
var _boss_break_mid_flashed := false
var _was_crisis_hud := false
## Kill-bar boss phase — track enter for 赤金 transition.
var _was_boss_kill_phase := false
var _boss_kill_land_t := 0.0

func _style_skill_keys() -> void:
	for i in _KEY_NODES.size():
		var key := $Root/SkillDock/SkillBar.get_node_or_null(_KEY_NODES[i]) as PanelContainer
		if key == null:
			continue
		var accent: Color = _SKILL_ACCENTS[i]
		var s := _UiStyle.panel(Color(0.07, 0.1, 0.13, 0.94), accent, 5)
		s.set_border_width_all(2)
		s.content_margin_left = 2
		s.content_margin_right = 2
		s.content_margin_top = 2
		s.content_margin_bottom = 2
		key.add_theme_stylebox_override("panel", s)

func _ready() -> void:
	add_to_group("hud")
	# Quiet status cluster vs stronger skill dock — clear HUD hierarchy.
	_restyle_top_for_stage()
	var dock_sb := _UiStyle.panel(Color(0.05, 0.08, 0.11, 0.88), Color(0.78, 0.7, 0.42, 0.75), 6)
	dock_sb.set_border_width_all(2)
	dock_sb.content_margin_left = 10
	dock_sb.content_margin_right = 10
	dock_sb.content_margin_top = 5
	dock_sb.content_margin_bottom = 5
	_skill_dock.add_theme_stylebox_override("panel", dock_sb)
	_UiStyle.apply_panel(_boss_bar, Color(0.9, 0.45, 0.3, 0.55))
	_style_skill_keys()
	_cache_skill_max_cd()
	EventBus.cultivation_broke_through.connect(_on_any)
	EventBus.mystic_crossed.connect(_on_mystic)
	EventBus.attack_gained.connect(_on_any2)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.player_died.connect(_on_dead)
	EventBus.death_pity_gained.connect(_on_death_pity)
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
	EventBus.skill_denied.connect(_on_skill_denied)
	EventBus.spirit_stones_gained.connect(_on_spirit_stones_gained)
	_clear.visible = false
	_hint_label.visible = false
	if _stone_label:
		_stone_base_col = _stone_label.get_theme_color("font_color")
		_stone_label.pivot_offset = _stone_label.size * 0.5
		call_deferred("_ready_stone_pivot")
	_refresh()

func _map_pattern() -> String:
	var stage := GameState.current_stage()
	if stage == null:
		return "yard"
	return str(stage.map.get("pattern", "yard"))

func _is_sect_yard() -> bool:
	return _map_pattern() == "yard"

func _is_dynasty_city() -> bool:
	return GameState.stage_id == "country" or _map_pattern() == "city"

func _restyle_top_for_stage() -> void:
	# Top bar rim tracks stage radar: teal for 宗门, warm gold for 王朝.
	var yard := _is_sect_yard()
	var dynasty := _is_dynasty_city()
	var rim := _SECT_TEAL if yard else (_CITY_NEAR if dynasty else Color(0.78, 0.68, 0.42, 0.55))
	var fill := Color(0.04, 0.08, 0.08, 0.82) if yard else (Color(0.09, 0.06, 0.03, 0.84) if dynasty else Color(0.05, 0.07, 0.1, 0.78))
	var border_a := 0.72 if dynasty else 0.55
	var top_sb := _UiStyle.panel(fill, Color(rim.r, rim.g, rim.b, border_a), 5)
	if dynasty:
		top_sb.set_border_width_all(2)
	top_sb.content_margin_left = 6
	top_sb.content_margin_right = 6
	top_sb.content_margin_top = 4
	top_sb.content_margin_bottom = 4
	_top_bar.add_theme_stylebox_override("panel", top_sb)
	if _kill_bg:
		_kill_bg.color = Color(0.05, 0.1, 0.1, 0.94) if yard else (Color(0.14, 0.1, 0.05, 0.94) if dynasty else Color(0.08, 0.1, 0.12, 0.92))
	if _kill_label:
		_kill_label.add_theme_color_override(
			"font_color",
			Color(0.55, 0.85, 0.8, 0.9) if yard else (Color(1.0, 0.88, 0.5, 0.95) if dynasty else Color(0.78, 0.74, 0.58, 0.88))
		)
	if _stage_label:
		_stage_label.add_theme_color_override(
			"font_color",
			Color(0.72, 0.92, 0.9, 0.95) if yard else (Color(1.0, 0.9, 0.55, 0.98) if dynasty else Color(0.9, 0.86, 0.72, 0.92))
		)

## Dynasty open beat — top bar + kill fill punch warm gold (pairs with wipe ritual).
func flash_dynasty_top() -> void:
	if not _is_dynasty_city() or _top_bar == null:
		return
	_restyle_top_for_stage()
	var hot := Color(1.0, 0.88, 0.42, 1.0)
	var panel_sb := _UiStyle.panel(Color(0.16, 0.1, 0.04, 0.92), hot, 5)
	panel_sb.set_border_width_all(2)
	panel_sb.content_margin_left = 6
	panel_sb.content_margin_right = 6
	panel_sb.content_margin_top = 4
	panel_sb.content_margin_bottom = 4
	_top_bar.add_theme_stylebox_override("panel", panel_sb)
	_top_bar.modulate = Color(1.35, 1.15, 0.8)
	if _kill_fill:
		_kill_fill.color = _CITY_NEAR
		_kill_fill.modulate = Color(1.4, 1.2, 0.85)
	if _kill_label:
		_kill_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	if _stage_label:
		_stage_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.7))
	var tw := create_tween()
	tw.tween_property(_top_bar, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	if _kill_fill:
		tw.parallel().tween_property(_kill_fill, "modulate", Color.WHITE, 0.4)
	tw.tween_callback(func() -> void:
		_restyle_top_for_stage()
		_refresh()
	)

## Sect open beat — top bar teal punch (pairs with courtyard wipe).
func flash_sect_top() -> void:
	if not _is_sect_yard() or _top_bar == null:
		return
	_restyle_top_for_stage()
	var hot := Color(0.45, 0.95, 0.88, 1.0)
	var panel_sb := _UiStyle.panel(Color(0.04, 0.1, 0.1, 0.92), hot, 5)
	panel_sb.set_border_width_all(2)
	panel_sb.content_margin_left = 6
	panel_sb.content_margin_right = 6
	panel_sb.content_margin_top = 4
	panel_sb.content_margin_bottom = 4
	_top_bar.add_theme_stylebox_override("panel", panel_sb)
	_top_bar.modulate = Color(0.85, 1.25, 1.2)
	if _kill_fill:
		_kill_fill.color = _SECT_TEAL
		_kill_fill.modulate = Color(0.85, 1.3, 1.2)
	if _kill_label:
		_kill_label.add_theme_color_override("font_color", Color(0.75, 0.98, 0.92))
	if _stage_label:
		_stage_label.add_theme_color_override("font_color", Color(0.8, 0.98, 0.94))
	var tw := create_tween()
	tw.tween_property(_top_bar, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	if _kill_fill:
		tw.parallel().tween_property(_kill_fill, "modulate", Color.WHITE, 0.4)
	tw.tween_callback(func() -> void:
		_restyle_top_for_stage()
		_refresh()
	)

func _ready_stone_pivot() -> void:
	if _stone_label:
		_stone_label.pivot_offset = Vector2(_stone_label.size.x * 0.5, _stone_label.size.y * 0.5)
		_stone_pivot_ready = true

func _on_spirit_stones_gained(amount: int) -> void:
	if amount <= 0 or _stone_label == null:
		return
	_stone_label.text = "石 %d  +%d" % [GameState.spirit_stones, amount]
	_stone_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	_stone_label.modulate = Color(1.35, 1.2, 0.85)
	if not _stone_pivot_ready:
		_ready_stone_pivot()
	_stone_label.scale = Vector2(0.85, 0.85)
	_stone_flashing = true
	var tw := create_tween()
	tw.tween_property(_stone_label, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_stone_label, "scale", Vector2.ONE, 0.14)
	tw.parallel().tween_property(_stone_label, "modulate", Color.WHITE, 0.28)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		if _stone_label == null:
			return
		_stone_label.text = "石 %d" % GameState.spirit_stones
		_stone_label.add_theme_color_override("font_color", _stone_base_col)
		_stone_flashing = false
	)

func _cache_skill_max_cd() -> void:
	for i in _SKILL_IDS.size():
		var cfg := ContentDB.get_skill(_SKILL_IDS[i])
		if not cfg.is_empty():
			_skill_max_cd[i] = maxf(float(cfg.get("cooldown", _skill_max_cd[i])), 0.1)

func _process(_delta: float) -> void:
	if _boss_bar_land_t > 0.0:
		_boss_bar_land_t = maxf(_boss_bar_land_t - _delta, 0.0)
	if _boss_break_t > 0.0:
		_boss_break_t = maxf(_boss_break_t - _delta, 0.0)
	if _boss_kill_land_t > 0.0:
		_boss_kill_land_t = maxf(_boss_kill_land_t - _delta, 0.0)
	_tick_boss_bar_land()
	_tick_boss_break_window()
	_tick_boss_hp_low_breath()
	_tick_boss_kill_bar_land()
	_update_skill_bar()
	_pulse_kill_bar_near_clear()
	# Don't stomp the gold jump mid-flash.
	if _stone_label and not _stone_flashing:
		_stone_label.text = "石 %d" % GameState.spirit_stones
	# Pulse crisis vignette when low HP — same clock as player silhouette.
	var crisis := GameState.hp > 0 and float(GameState.hp) / float(maxi(GameState.max_hp, 1)) <= 0.3 and not GameState.dead
	var world := get_tree().get_first_node_in_group("game_world")
	var zone_busy := false
	if world != null:
		var zt: Variant = world.get("_zone_edge_t")
		if typeof(zt) in [TYPE_FLOAT, TYPE_INT]:
			zone_busy = float(zt) > 0.0
	if crisis:
		_tick_crisis_pulse(zone_busy)
	else:
		if _was_crisis_hud:
			_was_crisis_hud = false
			_clear_crisis_hp_tint()
		elif not zone_busy and _dynasty_near_clear_active():
			_breath_dynasty_near_clear_edges()
			if not _hp_heal_flashing:
				_hp_fill.modulate = Color.WHITE
		elif not zone_busy and _sect_near_clear_active():
			_breath_sect_near_clear_edges()
			if not _hp_heal_flashing:
				_hp_fill.modulate = Color.WHITE
		elif not _hp_heal_flashing:
			_hp_fill.modulate = Color.WHITE

## Low-HP: edges + HP bar crest together (same CRISIS_PULSE_HZ as player / minimap).
func _tick_crisis_pulse(zone_busy: bool) -> void:
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * _CRISIS_PULSE_HZ)
	if not _was_crisis_hud:
		_was_crisis_hud = true
		# One louder rim kick when crossing into crisis — pairs「危机 · 伤↑」.
		_spawn_edge_flash(Color(0.95, 0.18, 0.12, 0.5), 14.0, 0.32)
		_spawn_edge_flash(Color(1.0, 0.4, 0.28, 0.22), 7.0, 0.2)
	# Edges yield briefly to zone enter flash; HP bar keeps the beat.
	if not zone_busy:
		# Stronger alpha swing — reads with silhouette outline crest.
		var pulse := 0.28 + 0.4 * breath
		var root := $Root
		for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
			var edge := root.get_node_or_null(edge_name) as ColorRect
			if edge:
				edge.color = Color(0.62, 0.06, 0.05, pulse)
	if not _hp_heal_flashing and _hp_fill:
		# Same-phase with edges: hotter when breath peaks (was inverted).
		_hp_fill.modulate = Color(
			1.0 + 0.35 * breath,
			0.55 + 0.2 * (1.0 - breath),
			0.5 + 0.2 * (1.0 - breath)
		)
		_hp_fill.color = Color(0.95, 0.28 + 0.12 * (1.0 - breath), 0.22)
	if _hp_bg and not _hp_heal_flashing:
		_hp_bg.modulate = Color(1.0, 0.7 + 0.3 * (1.0 - breath), 0.7 + 0.3 * (1.0 - breath))

func _clear_crisis_hp_tint() -> void:
	if _hp_fill and not _hp_heal_flashing:
		_hp_fill.modulate = Color.WHITE
	if _hp_bg:
		_hp_bg.modulate = Color.WHITE

## Near-clear ≥75% — dynasty gold or sect teal tension (before boss phase).
func _near_clear_active() -> bool:
	if GameState.dead:
		return false
	var stage := GameState.current_stage()
	if stage == null:
		return false
	var kills := GameState.stage_kills()
	var target := maxi(stage.kill_target, 1)
	var ratio := clampf(float(kills) / float(target), 0.0, 1.0)
	if ratio < 0.75 or kills >= stage.kill_target:
		return false
	if kills >= stage.boss_at_kill and not stage.boss_id.is_empty() and kills < stage.kill_target:
		return false
	return _is_dynasty_city() or _is_sect_yard()

## Dynasty kill bar ≥75% — soft warm-gold frame breath (lighter than 破绽 flash).
func _dynasty_near_clear_active() -> bool:
	return _near_clear_active() and _is_dynasty_city()

func _sect_near_clear_active() -> bool:
	return _near_clear_active() and _is_sect_yard()

func _breath_dynasty_near_clear_edges() -> void:
	var root := $Root
	# Short, slow gold wash — tension without spam.
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	var a := 0.1 + 0.14 * breath
	var gold := Color(0.95, 0.72, 0.28, a)
	for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
		var edge := root.get_node_or_null(edge_name) as ColorRect
		if edge:
			edge.color = gold

## Sect near-clear — calm teal wash (counterpart to dynasty gold, quieter than crisis).
func _breath_sect_near_clear_edges() -> void:
	var root := $Root
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
	var a := 0.08 + 0.12 * breath
	var teal := Color(0.32, 0.88, 0.8, a)
	for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
		var edge := root.get_node_or_null(edge_name) as ColorRect
		if edge:
			edge.color = teal

func _update_skill_bar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var labels := [_skill_l, _skill_u, _skill_i, _skill_o]
	var pill_empty := not _has_usable_pill()
	for i in _SKILL_IDS.size():
		var key: String = _SKILL_KEYS[i]
		var cd_left := 0.0
		if player and player.has_method("get_skill_cooldown"):
			cd_left = player.get_skill_cooldown(_SKILL_IDS[i])
		var key_panel := $Root/SkillDock/SkillBar.get_node_or_null(_KEY_NODES[i]) as CanvasItem
		var cd_fill := $Root/SkillDock/SkillBar.get_node_or_null("%s/Body/CdFill" % _KEY_NODES[i]) as ColorRect
		var ready := cd_left <= 0.05
		var max_cd := _skill_max_cd[i] if i < _skill_max_cd.size() else 1.0
		var cd_ratio := 0.0 if ready else clampf(cd_left / max_cd, 0.0, 1.0)
		var is_pill: bool = _SKILL_IDS[i] == "use_pill"
		# Empty 丹囊 (and off CD) — grey「空」; while CD after last pill still show timer.
		if is_pill and pill_empty and ready:
			if cd_fill:
				cd_fill.visible = false
			if i < _skill_was_ready.size():
				_skill_was_ready[i] = ready
			if not _pill_was_empty:
				_style_pill_empty(key_panel as PanelContainer)
				_pill_was_empty = true
			if labels[i]:
				labels[i].text = "空"
				labels[i].modulate = Color(0.52, 0.56, 0.58, 0.9)
			var casting_e: bool = int(_skill_cast_flash.get(_KEY_NODES[i], 0)) > 0
			if key_panel and not casting_e:
				key_panel.modulate = Color(0.62, 0.66, 0.68, 0.88)
			continue
		if is_pill and _pill_was_empty and (not pill_empty or not ready):
			# Stock restored or mid-CD after last dose — restore jade / CD look.
			_pill_was_empty = false
			_restyle_skill_key(i)
			if key_panel and ready:
				key_panel.modulate = Color.WHITE
		if cd_fill:
			cd_fill.offset_top = -_KEY_H * cd_ratio
			cd_fill.visible = cd_ratio > 0.02
		# Flash when a skill comes off cooldown — per-accent punch (闪青 / 环金 / 丹翠 / 爆火).
		if ready and i < _skill_was_ready.size() and not _skill_was_ready[i]:
			if not (is_pill and pill_empty):
				_flash_skill_ready(i, labels[i], key_panel)
		if i < _skill_was_ready.size():
			_skill_was_ready[i] = ready
		if not ready:
			labels[i].text = "%.0f" % ceil(cd_left)
			labels[i].modulate = Color(0.55, 0.6, 0.65, 0.95)
			var casting: bool = int(_skill_cast_flash.get(_KEY_NODES[i], 0)) > 0
			if key_panel and key_panel.modulate.r < 1.2 and not casting:
				key_panel.modulate = Color(0.72, 0.76, 0.8, 0.9)
		else:
			labels[i].text = key
			if labels[i].modulate.g < 0.9:
				labels[i].modulate = Color(0.98, 0.96, 0.9, 1.0)
			var casting2: bool = int(_skill_cast_flash.get(_KEY_NODES[i], 0)) > 0
			if key_panel and key_panel.modulate.r < 1.15 and not casting2:
				key_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	# Decay cast-flash locks.
	for k in _skill_cast_flash.keys():
		_skill_cast_flash[k] = int(_skill_cast_flash[k]) - 1
		if int(_skill_cast_flash[k]) <= 0:
			_skill_cast_flash.erase(k)

func _has_usable_pill() -> bool:
	var cfg := ContentDB.get_skill("use_pill")
	var priority: Array = []
	if typeof(cfg) == TYPE_DICTIONARY:
		priority = cfg.get("pill_priority", [])
	if priority.is_empty():
		priority = ["white_pill", "qi_pill_low"]
	for raw in priority:
		var item_id := str(raw)
		if GameState.inventory.count_of(item_id) < 1:
			continue
		var item := ContentDB.get_item(item_id)
		if item != null and item.qi_restore > 0:
			return true
	return false

func _style_pill_empty(kp: PanelContainer) -> void:
	if kp == null:
		return
	# Cool ash rim — empty 丹囊, opposite of jade stocked accent.
	var ash := _UiStyle.panel(Color(0.08, 0.09, 0.1, 0.96), Color(0.42, 0.46, 0.48, 0.7), 5)
	ash.set_border_width_all(2)
	ash.content_margin_left = 2
	ash.content_margin_right = 2
	ash.content_margin_top = 2
	ash.content_margin_bottom = 2
	kp.add_theme_stylebox_override("panel", ash)

## CD→ready short flash — accent rim + scale so each skill's return reads.
func _flash_skill_ready(idx: int, label: Label, key_panel: CanvasItem) -> void:
	if idx < 0 or idx >= _SKILL_ACCENTS.size():
		return
	# Dash KeyL — dedicated teal/cyan punch (iframe language), louder than generic ready.
	if idx == 0:
		_flash_dash_ready(label, key_panel)
		return
	var accent: Color = _SKILL_ACCENTS[idx]
	# Ring gold / pill jade / burst ember — not one warm-gold for all.
	var bright := Color(
		minf(accent.r * 1.35 + 0.25, 1.5),
		minf(accent.g * 1.3 + 0.2, 1.4),
		minf(accent.b * 1.25 + 0.15, 1.35)
	)
	if key_panel is PanelContainer:
		var kp := key_panel as PanelContainer
		var rim := _UiStyle.panel(Color(0.1, 0.12, 0.14, 0.98), accent.lightened(0.25), 5)
		rim.set_border_width_all(3)
		rim.content_margin_left = 2
		rim.content_margin_right = 2
		rim.content_margin_top = 2
		rim.content_margin_bottom = 2
		kp.add_theme_stylebox_override("panel", rim)
		kp.pivot_offset = kp.size * 0.5
		kp.scale = Vector2(0.88, 0.88)
		kp.modulate = bright
		# Lock out CD-dim stomp while the ready pop plays.
		_skill_cast_flash[_KEY_NODES[idx]] = 20
		var tw := create_tween()
		tw.tween_property(kp, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
		tw.tween_property(kp, "scale", Vector2.ONE, 0.14)
		tw.parallel().tween_property(kp, "modulate", Color.WHITE, 0.32)
		tw.tween_callback(func() -> void:
			if is_instance_valid(kp):
				_restyle_skill_key(idx)
		)
	elif key_panel:
		key_panel.modulate = bright
		var tw2 := create_tween()
		tw2.tween_property(key_panel, "modulate", Color.WHITE, 0.32)
	if label:
		label.modulate = Color(
			minf(accent.r + 0.4, 1.0),
			minf(accent.g + 0.35, 1.0),
			minf(accent.b + 0.3, 1.0),
			1.0
		)
	# Soft dock wash — whole bar notices a skill returned.
	if _skill_dock:
		_skill_dock.modulate = Color(
			minf(1.0 + accent.r * 0.18, 1.28),
			minf(1.0 + accent.g * 0.14, 1.22),
			minf(1.0 + accent.b * 0.12, 1.2)
		)
		var dtw := create_tween()
		dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.34)

## Dash CD→ready — cyan-teal KeyL + soft rim, pairs iframe ghost / minimap moon.
func _flash_dash_ready(label: Label, key_panel: CanvasItem) -> void:
	var teal := Color(0.4, 0.92, 0.95, 1.0)
	if key_panel is PanelContainer:
		var kp := key_panel as PanelContainer
		var rim := _UiStyle.panel(Color(0.05, 0.12, 0.16, 0.98), teal, 5)
		rim.set_border_width_all(3)
		rim.content_margin_left = 2
		rim.content_margin_right = 2
		rim.content_margin_top = 2
		rim.content_margin_bottom = 2
		kp.add_theme_stylebox_override("panel", rim)
		kp.pivot_offset = kp.size * 0.5
		kp.scale = Vector2(0.82, 0.82)
		kp.modulate = Color(0.75, 1.35, 1.45)
		_skill_cast_flash["KeyL"] = 24
		var tw := create_tween()
		tw.tween_property(kp, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK)
		tw.tween_property(kp, "scale", Vector2.ONE, 0.16)
		tw.parallel().tween_property(kp, "modulate", Color.WHITE, 0.36)
		tw.tween_callback(func() -> void:
			if is_instance_valid(kp):
				_restyle_skill_key(0)
		)
	elif key_panel:
		key_panel.modulate = Color(0.7, 1.3, 1.4)
		var tw2 := create_tween()
		tw2.tween_property(key_panel, "modulate", Color.WHITE, 0.36)
	if label:
		label.modulate = Color(0.55, 0.98, 1.0, 1.0)
	if _skill_dock:
		_skill_dock.modulate = Color(0.82, 1.18, 1.28)
		var dtw := create_tween()
		dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.38)
	# Quiet cyan edge — ready cue without stealing fight focus.
	_spawn_edge_flash(Color(0.4, 0.9, 1.0, 0.32), 10.0, 0.26)
	_spawn_edge_flash(Color(0.65, 1.0, 1.0, 0.14), 5.0, 0.16)

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

## Pill / heal pop — jade flash so I-key reads like heal-zone language.
func pulse_hp_heal(healed: int = 0) -> void:
	if _hp_fill == null:
		return
	_refresh()
	_hp_heal_flashing = true
	_hp_fill.modulate = Color(0.55, 1.25, 0.85)
	_hp_fill.color = Color(0.4, 0.95, 0.62)
	var target_w := _hp_fill.size.x
	_hp_fill.size.x = maxf(target_w - 10.0, 4.0)
	var tw := create_tween()
	tw.tween_property(_hp_fill, "size:x", minf(target_w + 8.0, _HP_BAR_W), 0.09).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_hp_fill, "size:x", target_w, 0.12)
	tw.parallel().tween_property(_hp_fill, "modulate", Color.WHITE, 0.28)
	if _hp_bg:
		_hp_bg.modulate = Color(0.7, 1.2, 0.95)
		tw.parallel().tween_property(_hp_bg, "modulate", Color.WHITE, 0.32)
	tw.tween_callback(func() -> void:
		_hp_heal_flashing = false
		_refresh()
	)
	# 服丹翠缘 — louder than 愈地 enter, pairs body jade window.
	_spawn_edge_flash(Color(0.35, 0.98, 0.72, 0.5), 14.0, 0.38)
	_spawn_edge_flash(Color(0.65, 1.0, 0.88, 0.22), 7.0, 0.24)
	# Top bar jade wash — 「出囊入体」reads on the status cluster.
	if _top_bar:
		_top_bar.modulate = Color(0.78, 1.22, 1.05)
		var ttw := create_tween()
		ttw.tween_property(_top_bar, "modulate", Color.WHITE, 0.36)
	if healed > 0:
		show_clear("服丹 +%d" % healed)

## 愈地 enter — calm teal rim kick (mirrors crisis red enter flash).
func flash_heal_enter_edges() -> void:
	_spawn_edge_flash(Color(0.35, 0.95, 0.78, 0.46), 13.0, 0.36)
	_spawn_edge_flash(Color(0.55, 1.0, 0.88, 0.2), 6.0, 0.22)
	# Soft HP jade wash — quieter than 服丹, opposite of crisis 赤条.
	if _hp_fill and not _hp_heal_flashing:
		_hp_heal_flashing = true
		_hp_fill.modulate = Color(0.65, 1.2, 0.95)
		if _hp_bg:
			_hp_bg.modulate = Color(0.75, 1.1, 0.95)
		var tw := create_tween()
		tw.tween_property(_hp_fill, "modulate", Color.WHITE, 0.32)
		if _hp_bg:
			tw.parallel().tween_property(_hp_bg, "modulate", Color.WHITE, 0.32)
		tw.tween_callback(func() -> void:
			_hp_heal_flashing = false
		)

## Soft revive / 再起 — jade rim (hopeful, quieter than 破绽 gold).
func flash_revive_edges() -> void:
	_spawn_edge_flash(Color(0.4, 0.98, 0.85, 0.5), 14.0, 0.4)
	_spawn_edge_flash(Color(0.7, 1.0, 0.92, 0.22), 7.0, 0.24)
	if _hp_fill and not _hp_heal_flashing:
		_hp_heal_flashing = true
		_hp_fill.modulate = Color(0.55, 1.25, 1.0)
		if _hp_bg:
			_hp_bg.modulate = Color(0.7, 1.15, 0.98)
		var tw := create_tween()
		tw.tween_property(_hp_fill, "modulate", Color.WHITE, 0.4)
		if _hp_bg:
			tw.parallel().tween_property(_hp_bg, "modulate", Color.WHITE, 0.4)
		tw.tween_callback(func() -> void:
			_hp_heal_flashing = false
		)

func _on_dead() -> void:
	_hint_label.visible = true
	var pity := GameState.last_death_pity
	var early := GameState.stage_id in ["sect", "country"]
	if pity > 0 and early:
		_hint_label.text = "抚恤 +%d石 · 回宗花石 / R再战" % pity
		_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	elif pity > 0:
		_hint_label.text = "抚恤 +%d石 · R再战" % pity
		_hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	else:
		_hint_label.text = "气散 · R再战 / 回宗花石"
		_hint_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.7))
	_refresh()

func _on_death_pity(amount: int) -> void:
	if amount <= 0:
		return
	# Loud compensation read — death must not feel empty.
	var early := GameState.stage_id in ["sect", "country"]
	show_clear("抚恤 +%d石" % amount)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var pos := player.global_position + Vector2(0, -40) if player else Vector2(320, 160)
	FloatTextManager.show_message(pos, "抚恤 +%d" % amount, Color(1.0, 0.92, 0.45))
	if early:
		FloatTextManager.show_message(pos + Vector2(0, -14), "回宗可花", Color(1.0, 0.94, 0.65))
	else:
		FloatTextManager.show_message(pos + Vector2(0, -14), "再战不亏", Color(0.85, 0.95, 0.7))
	flash_recover_edges()

func _on_stage(_stage_id: String) -> void:
	_clear.visible = false
	_boss_bar.visible = false
	_hint_label.visible = false
	_was_boss_kill_phase = false
	_boss_kill_land_t = 0.0
	if _kill_fill:
		_kill_fill.scale = Vector2.ONE
		_kill_fill.modulate = Color.WHITE
	if _kill_bg:
		_kill_bg.modulate = Color.WHITE
	if _kill_label:
		_kill_label.modulate = Color.WHITE
	_restyle_top_for_stage()
	_refresh()

func _on_wave(hint: String) -> void:
	show_clear(hint)

func _on_combo_milestone(count: int) -> void:
	_combo_label.visible = true
	_refresh_combo_label(true)
	_combo_label.scale = Vector2(0.75, 0.75)
	var punch := 1.18 if count >= 8 else (1.14 if count >= 5 else 1.1)
	if GameState.early_kill_hook():
		punch += 0.06
	if count == 2:
		punch = maxf(punch, 1.16)
	var tw := create_tween()
	tw.tween_property(_combo_label, "scale", Vector2(punch, punch), 0.09).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.14)
	# Dense shout copy — early milestones must feel like a hit, not a counter tick.
	var shout := "%d连" % count
	var shout_col := Color(1.0, 0.92, 0.55, 1.0)
	var yard := _is_sect_yard()
	var dynasty := _is_dynasty_city()
	match count:
		2:
			shout = "二连"
			# Sect teal vs dynasty gold — pairs first-kill 斩 / 市斩 language.
			if yard:
				shout_col = Color(0.5, 0.98, 0.9, 1.0)
				_combo_label.modulate = Color(0.55, 0.98, 0.92)
			elif dynasty:
				shout_col = Color(1.0, 0.88, 0.42, 1.0)
				_combo_label.modulate = Color(1.0, 0.9, 0.48)
			else:
				shout_col = Color(1.0, 0.96, 0.72, 1.0)
		3:
			shout = "三连"
			shout_col = Color(1.0, 0.94, 0.6, 1.0)
		5:
			shout = "五连 · 伤↑"
			shout_col = Color(1.0, 0.86, 0.4, 1.0)
		8:
			# 疯斩 赤金 — same family as boss drop / minimap 8-combo hot rim.
			shout = "八连 · 疯斩"
			shout_col = Color(1.0, 0.55, 0.26, 1.0)
			_combo_label.modulate = Color(1.0, 0.58, 0.28)
		_:
			if count >= 15:
				shout = "%d连 · 通杀" % count
				shout_col = Color(1.0, 0.5, 0.28, 1.0)
			elif count >= 10:
				shout = "%d连" % count
				shout_col = Color(1.0, 0.75, 0.35, 1.0)
	_show_combo_shout(shout, shout_col)
	_flash_combo_edges(count)
	# Gold 斩 kick — every milestone shakes a little; bigger stacks hit harder.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("pulse_camera"):
		var kick := 0.07
		if count >= 8:
			kick = 0.14
		elif count >= 5:
			kick = 0.1
		elif count == 2:
			kick = 0.08
		player.pulse_camera(kick)
	if count >= 8:
		var world := get_tree().get_first_node_in_group("game_world")
		if world and world.has_method("hitstop"):
			world.hitstop(0.03)
	elif count == 2:
		var world2 := get_tree().get_first_node_in_group("game_world")
		if world2 and world2.has_method("hitstop"):
			world2.hitstop(0.02)

func _show_combo_shout(text: String, col: Color) -> void:
	_clear.text = text
	_clear.visible = true
	_clear.modulate = col
	# 疯斩 banner punches bigger / holds longer than early milestone ticks.
	var mad := "疯斩" in text
	_clear.scale = Vector2(0.72, 0.72) if mad else Vector2(0.82, 0.82)
	var peak := 1.22 if mad else 1.08
	var hold := 0.9 if mad else (0.55 if text.length() <= 4 else 0.7)
	var tw := create_tween()
	tw.tween_property(_clear, "scale", Vector2(peak, peak), 0.11).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_clear, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(hold)
	tw.tween_property(_clear, "modulate:a", 0.0, 0.32 if mad else 0.28)
	tw.tween_callback(func() -> void: _clear.visible = false)

func _flash_combo_edges(count: int) -> void:
	# Screen-edge flash — dopamine without covering the fight.
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	# 二连: sect teal / dynasty gold short dual rim (pairs 斩 / 市斩).
	if count == 2:
		if _is_sect_yard():
			_spawn_edge_flash(Color(0.4, 0.95, 0.88, 0.4), 11.0, 0.26)
			_spawn_edge_flash(Color(0.65, 1.0, 0.95, 0.18), 5.0, 0.16)
		elif _is_dynasty_city():
			_spawn_edge_flash(Color(1.0, 0.84, 0.38, 0.4), 11.0, 0.26)
			_spawn_edge_flash(Color(1.0, 0.94, 0.6, 0.18), 5.0, 0.16)
		else:
			_spawn_edge_flash(Color(1.0, 0.9, 0.55, 0.32), 10.0, 0.24)
		return
	# 疯斩 赤金 dual rim — hotter than 五连 gold, same family as boss 赤金 land.
	if count >= 8:
		_spawn_edge_flash(Color(1.0, 0.52, 0.22, 0.58), 16.0, 0.44)
		_spawn_edge_flash(Color(1.0, 0.78, 0.35, 0.3), 8.0, 0.3)
		return
	var intensity := 0.28 if count < 5 else 0.4
	var gold := Color(1.0, 0.82, 0.35, intensity)
	if count >= 5:
		gold = Color(1.0, 0.72, 0.32, intensity)
	_spawn_edge_flash(gold, 10.0, 0.28)

## Boss recover punish window — soft gold rim, same family as combo flash.
func flash_recover_edges() -> void:
	_spawn_edge_flash(Color(1.0, 0.88, 0.4, 0.36), 11.0, 0.34)

## Sect elder 破绽 — louder gold so the punish beat can't be missed.
func flash_recover_edges_loud() -> void:
	_spawn_edge_flash(Color(1.0, 0.92, 0.45, 0.52), 16.0, 0.42)
	# Second thinner inner flash for a double-kick read.
	_spawn_edge_flash(Color(1.0, 0.98, 0.7, 0.28), 8.0, 0.28)

## Arm boss-bar gold breath for the full 破绽 window (pairs minimap break pip).
func arm_boss_break_window(duration: float = 0.7) -> void:
	_boss_break_max = maxf(duration, 0.35)
	_boss_break_t = _boss_break_max
	_boss_break_mid_flashed = false
	if _boss_bar == null or not _boss_bar.visible:
		return
	# Ensure we have a stylebox to tint during the window.
	if _boss_bar_land_flat == null:
		var sb := _boss_bar.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			_boss_bar_land_flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			_boss_bar.add_theme_stylebox_override("panel", _boss_bar_land_flat)
	_boss_bar.pivot_offset = _boss_bar.size * 0.5
	_boss_bar.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.tween_property(_boss_bar, "scale", Vector2(1.06, 1.06), 0.09).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_boss_bar, "scale", Vector2.ONE, 0.14)

func _tick_boss_break_window() -> void:
	if _boss_bar == null or not _boss_bar.visible:
		return
	if _boss_break_t <= 0.0 or _boss_break_max <= 0.0:
		return
	# Prefer 破绽 gold over land punch / low-HP 赤金 while the window is open.
	var a := clampf(_boss_break_t / _boss_break_max, 0.0, 1.0)
	# Same clock as recover FX breathe (~0.012 on mob).
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
	_boss_bar.modulate = Color(
		minf(1.15 + 0.35 * pulse, 1.55),
		minf(0.95 + 0.2 * pulse, 1.25),
		minf(0.45 + 0.15 * pulse, 0.85)
	)
	_boss_bar.pivot_offset = _boss_bar.size * 0.5
	_boss_bar.scale = Vector2.ONE * (1.0 + 0.02 * pulse * a)
	if _boss_bar_land_flat:
		var punch := Color(1.0, 0.9, 0.38, 1.0)
		var settle := Color(1.0, 0.78, 0.35, 0.75)
		_boss_bar_land_flat.border_color = punch.lerp(settle, 1.0 - pulse)
		_boss_bar_land_flat.set_border_width_all(3 if pulse > 0.55 else 2)
	if _boss_hp_fill:
		_boss_hp_fill.modulate = Color(1.2 + 0.2 * pulse, 1.05 + 0.1 * pulse, 0.7)
	if _boss_name:
		_boss_name.modulate = Color(1.0, 0.92 + 0.06 * pulse, 0.5 + 0.15 * pulse)
	# One mid-window edge tick — HUD stays synced with radar pip linger.
	if not _boss_break_mid_flashed and a <= 0.55:
		_boss_break_mid_flashed = true
		_spawn_edge_flash(Color(1.0, 0.92, 0.45, 0.28), 9.0, 0.22)

## Kill during 破绽 — sect teal / dynasty gold short rim (not window-open gold).
func flash_break_kill_edges(teal: bool = false) -> void:
	if teal:
		_spawn_edge_flash(Color(0.4, 0.95, 0.88, 0.46), 12.0, 0.26)
		_spawn_edge_flash(Color(0.7, 1.0, 0.95, 0.2), 6.0, 0.16)
	else:
		_spawn_edge_flash(Color(1.0, 0.86, 0.38, 0.46), 12.0, 0.26)
		_spawn_edge_flash(Color(1.0, 0.95, 0.65, 0.2), 6.0, 0.16)

## Elite drop — warm-gold rim (quieter than 破绽 / boss 赤金, louder than minimap pip).
func flash_elite_spawn_edges() -> void:
	_spawn_edge_flash(Color(1.0, 0.84, 0.4, 0.4), 11.0, 0.28)
	_spawn_edge_flash(Color(1.0, 0.94, 0.62, 0.18), 5.0, 0.18)

## 愈后外门近身 — warm steel rim (cooler than 破绽 gold, hotter than 愈地 green).
func flash_steel_edges() -> void:
	_spawn_edge_flash(Color(0.95, 0.72, 0.38, 0.44), 12.0, 0.32)
	_spawn_edge_flash(Color(1.0, 0.85, 0.55, 0.22), 6.0, 0.22)

## Chest open — warm-gold loot rim (pairs radar diamond ping).
func flash_chest_edges() -> void:
	_spawn_edge_flash(Color(1.0, 0.86, 0.4, 0.48), 13.0, 0.36)
	_spawn_edge_flash(Color(1.0, 0.95, 0.65, 0.22), 6.0, 0.22)

## Boss 突斩 connect — hot orange dual rim (pairs slash burst / directional hurt).
func flash_dash_strike_edges(dir: Vector2 = Vector2.ZERO) -> void:
	_spawn_edge_flash(Color(1.0, 0.48, 0.22, 0.55), 15.0, 0.34)
	_spawn_edge_flash(Color(1.0, 0.82, 0.4, 0.28), 7.0, 0.22)
	if dir.length_squared() > 0.01:
		flash_hurt_directional(dir)

## Player hurt sting biased to the impact side — loud dual bar so direction reads at a glance.
func flash_hurt_directional(dir: Vector2) -> void:
	var root := get_node_or_null("Root") as Control
	if root == null or dir.length_squared() < 0.01:
		return
	var n := dir.normalized()
	var w := maxf(root.size.x, 640.0)
	var h := maxf(root.size.y, 360.0)
	# Outer slap + hot inner — stronger than single thin strip.
	_spawn_hurt_side_bar(root, n, w, h, 22.0, Color(1.0, 0.22, 0.16, 0.72), 0.34)
	_spawn_hurt_side_bar(root, n, w, h, 9.0, Color(1.0, 0.55, 0.35, 0.45), 0.22)
	# Soft bleed on the two corners of that edge — anchors direction vs full-rim flashes.
	_spawn_hurt_corner_bleed(root, n, w, h)

func _spawn_hurt_side_bar(root: Control, n: Vector2, w: float, h: float, thick: float, col: Color, fade_s: float) -> void:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = col
	r.z_index = 41
	if absf(n.x) >= absf(n.y):
		r.size = Vector2(thick, h)
		r.position = Vector2(w - thick if n.x > 0.0 else 0.0, 0.0)
	else:
		r.size = Vector2(w, thick)
		r.position = Vector2(0.0, h - thick if n.y > 0.0 else 0.0)
	root.add_child(r)
	var fade := create_tween()
	fade.tween_interval(0.04)
	fade.tween_property(r, "modulate:a", 0.0, fade_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_callback(r.queue_free)

func _spawn_hurt_corner_bleed(root: Control, n: Vector2, w: float, h: float) -> void:
	var pad := 28.0
	var col := Color(1.0, 0.3, 0.2, 0.38)
	var corners: Array[Vector2] = []
	if absf(n.x) >= absf(n.y):
		var x := (w - pad) if n.x > 0.0 else 0.0
		corners = [Vector2(x, 0.0), Vector2(x, h - pad)]
	else:
		var y := (h - pad) if n.y > 0.0 else 0.0
		corners = [Vector2(0.0, y), Vector2(w - pad, y)]
	for cpos in corners:
		var c := ColorRect.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.color = col
		c.z_index = 40
		c.size = Vector2(pad, pad)
		c.position = cpos
		root.add_child(c)
		var ctw := create_tween()
		ctw.tween_property(c, "modulate:a", 0.0, 0.26)
		ctw.tween_callback(c.queue_free)

func _spawn_edge_flash(gold: Color, thick: float, fade_s: float) -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	var w := maxf(root.size.x, 640.0)
	var h := maxf(root.size.y, 360.0)
	var intensity := gold.a
	var edges: Array[ColorRect] = []
	var specs := [
		[Vector2(0, 0), Vector2(w, thick)],
		[Vector2(0, h - thick), Vector2(w, thick)],
		[Vector2(0, 0), Vector2(thick, h)],
		[Vector2(w - thick, 0), Vector2(thick, h)],
	]
	for spec in specs:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.color = gold
		r.position = spec[0]
		r.size = spec[1]
		r.z_index = 40
		root.add_child(r)
		edges.append(r)
	var fade := create_tween()
	fade.tween_method(func(a: float) -> void:
		for e in edges:
			if is_instance_valid(e):
				e.color.a = a
	, intensity, 0.0, fade_s)
	fade.tween_callback(func() -> void:
		for e in edges:
			if is_instance_valid(e):
				e.queue_free()
	)

func _refresh_combo_label(force_show: bool = false) -> void:
	var c := GameState.combo
	var early_one := GameState.early_kill_hook() and c >= 1
	if c < 2 and not force_show and not early_one:
		_combo_label.visible = false
		return
	_combo_label.visible = true
	var per := float(ContentDB.section("combat").get("combo_damage_per_stack", 0.03))
	var bonus_pct := int(round(per * float(c) * 100.0))
	if c == 1:
		_combo_label.text = "市斩" if _is_dynasty_city() and GameState.early_kill_hook() else "斩"
	elif bonus_pct > 0 and c >= 3:
		_combo_label.text = "%d连 · 伤+%d%%" % [c, bonus_pct]
	else:
		_combo_label.text = "%d连" % c
	if c >= 8:
		# 疯斩 赤金 — hold the banner language on the live counter.
		_combo_label.modulate = Color(1.0, 0.58, 0.28, 1.0)
	elif c >= 6:
		_combo_label.modulate = Color(1.0, 0.82, 0.4, 1.0)
	else:
		_combo_label.modulate = Color(1.0, 0.92, 0.6, 1.0)

func _on_enemy_killed(_enemy_id = null, _stage_id = null) -> void:
	_refresh()
	_refresh_combo_label(GameState.early_kill_hook())
	_check_boss_kill_phase_enter()
	# Boss 赤金 land owns the bar — skip teal/gold tick that would bleach it.
	if _was_boss_kill_phase and _boss_kill_land_t > 0.0:
		if GameState.early_kill_hook():
			_punch_early_kill()
		return
	# Kill-bar tick — teal flash on 宗门 so HUD matches radar spawn pips.
	if _is_sect_yard():
		_kill_fill.modulate = Color(0.85, 1.35, 1.25)
	else:
		_kill_fill.modulate = Color(1.35, 1.2, 0.75)
	var tw := create_tween()
	tw.tween_property(_kill_fill, "modulate", Color.WHITE, 0.18)
	if GameState.early_kill_hook():
		_punch_early_kill()

func _check_boss_kill_phase_enter() -> void:
	var stage := GameState.current_stage()
	if stage == null or stage.boss_id.is_empty():
		_was_boss_kill_phase = false
		return
	var kills := GameState.stage_kills()
	var boss_phase := kills >= stage.boss_at_kill and kills < stage.kill_target
	if boss_phase and not _was_boss_kill_phase:
		_arm_boss_kill_bar_land()
	elif not boss_phase:
		_was_boss_kill_phase = false
		_boss_kill_land_t = 0.0

func _punch_early_kill() -> void:
	# Opening minute: sect teal「斩」vs dynasty warm「市斩」.
	var dynasty := _is_dynasty_city()
	if _is_sect_yard():
		_kill_fill.modulate = Color(1.35, 1.7, 1.6)
	else:
		_kill_fill.modulate = Color(1.7, 1.65, 1.45)
	_combo_label.visible = true
	_combo_label.scale = Vector2(0.82, 0.82)
	var ctw := create_tween()
	ctw.tween_property(_combo_label, "scale", Vector2(1.16, 1.16), 0.08).set_trans(Tween.TRANS_BACK)
	ctw.tween_property(_combo_label, "scale", Vector2.ONE, 0.12)
	var c := GameState.combo
	if c == 1:
		if dynasty:
			_combo_label.text = "市斩"
			_combo_label.modulate = Color(1.0, 0.88, 0.45)
			show_clear("市斩")
			_spawn_edge_flash(Color(1.0, 0.82, 0.35, 0.48), 13.0, 0.3)
			_spawn_edge_flash(Color(1.0, 0.92, 0.55, 0.22), 7.0, 0.2)
			_punch_shizhan_kill_bar()
		elif _is_sect_yard():
			# Sect first「斩」— teal dual rim + kill-bar kick (pairs 市斩 gold, no redo).
			_combo_label.text = "斩"
			_combo_label.modulate = Color(0.55, 0.98, 0.9)
			show_clear("斩")
			_spawn_edge_flash(Color(0.4, 0.95, 0.88, 0.48), 13.0, 0.3)
			_spawn_edge_flash(Color(0.65, 1.0, 0.95, 0.22), 7.0, 0.2)
			_punch_sect_zhan_kill_bar()
		else:
			show_clear("斩")
			_spawn_edge_flash(Color(1.0, 0.98, 0.88, 0.42), 12.0, 0.26)
	elif c <= 4:
		if _is_sect_yard():
			_spawn_edge_flash(Color(0.45, 0.9, 0.85, 0.2), 8.0, 0.18)
		elif dynasty:
			_spawn_edge_flash(Color(1.0, 0.84, 0.4, 0.24), 8.0, 0.18)
		else:
			_spawn_edge_flash(Color(1.0, 0.96, 0.82, 0.22), 8.0, 0.18)

## Dynasty first「市斩」— kill bar jumps a warm-gold tick so progress pops.
func _punch_shizhan_kill_bar() -> void:
	if _kill_fill == null:
		return
	var target_w := _kill_fill.size.x
	var from_w := maxf(target_w - 10.0, 2.0)
	_kill_fill.size.x = from_w
	_kill_fill.color = _CITY_NEAR
	_kill_fill.modulate = Color(1.55, 1.3, 0.85)
	if _kill_bg:
		_kill_bg.modulate = Color(1.4, 1.15, 0.7)
	_kill_fill.pivot_offset = Vector2(0, _kill_fill.size.y * 0.5)
	_kill_fill.scale = Vector2(1.0, 1.35)
	var tw := create_tween()
	tw.tween_property(_kill_fill, "size:x", target_w + 4.0, 0.09).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_kill_fill, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_property(_kill_fill, "size:x", target_w, 0.1).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_kill_fill, "modulate", Color.WHITE, 0.22)
	if _kill_bg:
		tw.parallel().tween_property(_kill_bg, "modulate", Color.WHITE, 0.22)
	tw.tween_callback(func() -> void:
		if _kill_fill:
			_kill_fill.color = _CITY_GOLD
			_refresh()
	)

## Sect first「斩」— kill bar teal kick (mirror of 市斩 gold jump).
func _punch_sect_zhan_kill_bar() -> void:
	if _kill_fill == null:
		return
	var target_w := _kill_fill.size.x
	var from_w := maxf(target_w - 10.0, 2.0)
	_kill_fill.size.x = from_w
	_kill_fill.color = _SECT_TEAL_NEAR
	_kill_fill.modulate = Color(0.85, 1.55, 1.4)
	if _kill_bg:
		_kill_bg.modulate = Color(0.7, 1.25, 1.15)
	_kill_fill.pivot_offset = Vector2(0, _kill_fill.size.y * 0.5)
	_kill_fill.scale = Vector2(1.0, 1.35)
	var tw := create_tween()
	tw.tween_property(_kill_fill, "size:x", target_w + 4.0, 0.09).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_kill_fill, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_property(_kill_fill, "size:x", target_w, 0.1).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_kill_fill, "modulate", Color.WHITE, 0.22)
	if _kill_bg:
		tw.parallel().tween_property(_kill_bg, "modulate", Color.WHITE, 0.22)
	tw.tween_callback(func() -> void:
		if _kill_fill:
			_refresh()
	)

func _on_growth_ping(stat: String, _value: int) -> void:
	# Brief top-bar flash so kill-growth is felt even if float text is missed.
	var tip := "悟性↑" if stat == "wisdom" else "体魄↑"
	show_clear(tip)

func _on_skill_denied(skill_id: String, reason: String) -> void:
	var idx := _SKILL_IDS.find(skill_id)
	if idx < 0:
		return
	var key_name: String = _KEY_NODES[idx]
	# Throttle mash — ~0.22s between denies on the same key.
	var now := Time.get_ticks_msec()
	var last := int(_skill_deny_cool.get(key_name, 0))
	if now - last < 220:
		return
	_skill_deny_cool[key_name] = now
	_flash_skill_deny(idx, reason)
	# Ash tick with grey dock flash — empty pill / CD mash (throttled above).
	if SfxService:
		SfxService.play_deny()

## Empty press / CD mash — short ash dock flash (not accent cast colors).
func _flash_skill_deny(idx: int, reason: String) -> void:
	if idx < 0 or idx >= _KEY_NODES.size():
		return
	var key_name: String = _KEY_NODES[idx]
	var key_panel := $Root/SkillDock/SkillBar.get_node_or_null(key_name) as PanelContainer
	if key_panel == null:
		return
	var ash := Color(0.55, 0.58, 0.62, 1.0)
	var rim := _UiStyle.panel(Color(0.1, 0.11, 0.12, 0.98), ash, 5)
	rim.set_border_width_all(2)
	rim.content_margin_left = 2
	rim.content_margin_right = 2
	rim.content_margin_top = 2
	rim.content_margin_bottom = 2
	key_panel.add_theme_stylebox_override("panel", rim)
	key_panel.pivot_offset = key_panel.size * 0.5
	key_panel.scale = Vector2(0.92, 0.92)
	key_panel.modulate = Color(0.7, 0.72, 0.75)
	_skill_cast_flash[key_name] = 14
	var labels := [_skill_l, _skill_u, _skill_i, _skill_o]
	if idx < labels.size() and labels[idx]:
		# Keep「空」readable on empty pill; otherwise grey the key glyph.
		if reason == "empty" and _SKILL_IDS[idx] == "use_pill":
			labels[idx].text = "空"
			labels[idx].modulate = Color(0.55, 0.58, 0.6, 0.95)
		else:
			labels[idx].modulate = Color(0.6, 0.62, 0.65, 0.95)
	if _skill_dock:
		_skill_dock.modulate = Color(0.82, 0.84, 0.86)
		var dtw := create_tween()
		dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.22)
	var tw := create_tween()
	tw.tween_property(key_panel, "scale", Vector2(1.06, 1.06), 0.06)
	tw.tween_property(key_panel, "scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(key_panel, "modulate", Color(0.72, 0.76, 0.8, 0.9), 0.18)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(key_panel):
			return
		# Empty pill stays ash-styled; others restore accent rim.
		if reason == "empty" and _SKILL_IDS[idx] == "use_pill" and not _has_usable_pill():
			_style_pill_empty(key_panel)
			_pill_was_empty = true
		else:
			_restyle_skill_key(idx)
	)

func _on_skill_used(skill_id: String, _cooldown: float) -> void:
	var idx := _SKILL_IDS.find(skill_id)
	if idx < 0:
		return
	var key_name: String = _KEY_NODES[idx]
	var key_panel := $Root/SkillDock/SkillBar.get_node_or_null(key_name) as PanelContainer
	if key_panel == null:
		return
	var flash: Color = _SKILL_ACCENTS[idx]
	# U / O get loud rims — ring-slash whiff stays cool; 灵爆 uses fire-ember (not ring gold).
	var ring_hit := true
	if skill_id == "ring_slash":
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			ring_hit = bool(player.get("last_ring_connected"))
	var is_burst_cast := skill_id == "spirit_burst"
	var is_pill_cast := skill_id == "use_pill"
	var is_gold_cast := (skill_id == "ring_slash" and ring_hit)
	var is_miss_cast := skill_id == "ring_slash" and not ring_hit
	if is_pill_cast:
		# KeyI 丹囊翠闪 — bag slot pops with body / HUD jade window.
		flash = Color(0.4, 0.95, 0.65, 1.0)
		var jade := _UiStyle.panel(Color(0.06, 0.14, 0.1, 0.98), flash, 5)
		jade.set_border_width_all(3)
		jade.content_margin_left = 2
		jade.content_margin_right = 2
		jade.content_margin_top = 2
		jade.content_margin_bottom = 2
		key_panel.add_theme_stylebox_override("panel", jade)
		key_panel.pivot_offset = key_panel.size * 0.5
		key_panel.scale = Vector2(0.86, 0.86)
		key_panel.modulate = Color(0.85, 1.4, 1.1)
		if _skill_dock:
			_skill_dock.modulate = Color(0.85, 1.22, 1.05)
			var dtw := create_tween()
			dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.34)
		_skill_cast_flash[key_name] = 20
		var labels_p := [_skill_l, _skill_u, _skill_i, _skill_o]
		if idx < labels_p.size() and labels_p[idx]:
			labels_p[idx].modulate = Color(0.55, 1.0, 0.78, 1.0)
		var ptw := create_tween()
		ptw.tween_property(key_panel, "scale", Vector2(1.14, 1.14), 0.1).set_trans(Tween.TRANS_BACK)
		ptw.tween_property(key_panel, "scale", Vector2.ONE, 0.16)
		ptw.parallel().tween_property(key_panel, "modulate", Color(0.75, 0.9, 0.82, 0.95), 0.28)
		ptw.tween_callback(func() -> void:
			if is_instance_valid(key_panel):
				_restyle_skill_key(idx)
				key_panel.modulate = Color(0.72, 0.76, 0.8, 0.9)
		)
		return
	if is_burst_cast:
		# Fire-ember — matches player gold-orange outline / nova, hotter than 环斩 gold.
		flash = Color(1.0, 0.55, 0.28, 1.0)
		var ember := _UiStyle.panel(Color(0.2, 0.08, 0.04, 0.98), flash, 5)
		ember.set_border_width_all(3)
		ember.content_margin_left = 2
		ember.content_margin_right = 2
		ember.content_margin_top = 2
		ember.content_margin_bottom = 2
		key_panel.add_theme_stylebox_override("panel", ember)
		key_panel.pivot_offset = key_panel.size * 0.5
		key_panel.scale = Vector2(0.86, 0.86)
		key_panel.modulate = Color(1.55, 1.05, 0.65)
		if _skill_dock:
			_skill_dock.modulate = Color(1.35, 0.95, 0.7)
			var dtw := create_tween()
			dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.34)
		# Soft HUD ember rim — cast lands with the body outline window.
		_spawn_edge_flash(Color(1.0, 0.55, 0.28, 0.4), 12.0, 0.3)
		_spawn_edge_flash(Color(1.0, 0.85, 0.45, 0.18), 6.0, 0.2)
		show_clear("灵爆")
		# Hold cast lock ~outline flash (0.26s) so CD dim doesn't stomp ember.
		_skill_cast_flash[key_name] = 22
		var labels_b := [_skill_l, _skill_u, _skill_i, _skill_o]
		if idx < labels_b.size() and labels_b[idx]:
			labels_b[idx].modulate = Color(1.0, 0.78, 0.45, 1.0)
		var btw := create_tween()
		btw.tween_property(key_panel, "scale", Vector2(1.14, 1.14), 0.1).set_trans(Tween.TRANS_BACK)
		btw.tween_property(key_panel, "scale", Vector2.ONE, 0.16)
		btw.parallel().tween_property(key_panel, "modulate", Color(0.85, 0.55, 0.4, 0.95), 0.28)
		btw.tween_callback(func() -> void:
			if is_instance_valid(key_panel):
				_restyle_skill_key(idx)
				key_panel.modulate = Color(0.72, 0.76, 0.8, 0.9)
		)
		return
	if is_miss_cast:
		# KeyU 空挥 — cool cyan-ash, never gold; quieter than deny ash, cooler than hit.
		flash = Color(0.48, 0.62, 0.72, 1.0)
		var cool := _UiStyle.panel(Color(0.07, 0.09, 0.12, 0.98), flash, 5)
		cool.set_border_width_all(2)
		cool.content_margin_left = 2
		cool.content_margin_right = 2
		cool.content_margin_top = 2
		cool.content_margin_bottom = 2
		key_panel.add_theme_stylebox_override("panel", cool)
		key_panel.pivot_offset = key_panel.size * 0.5
		key_panel.scale = Vector2(0.9, 0.9)
		key_panel.modulate = Color(0.78, 0.88, 0.98)
		if _skill_dock:
			_skill_dock.modulate = Color(0.78, 0.84, 0.9)
			var dtw_m := create_tween()
			dtw_m.tween_property(_skill_dock, "modulate", Color.WHITE, 0.26)
		_skill_cast_flash[key_name] = 16
		var labels_m := [_skill_l, _skill_u, _skill_i, _skill_o]
		if idx < labels_m.size() and labels_m[idx]:
			labels_m[idx].modulate = Color(0.65, 0.78, 0.88, 1.0)
		var mtw := create_tween()
		mtw.tween_property(key_panel, "scale", Vector2(1.08, 1.08), 0.08)
		mtw.tween_property(key_panel, "scale", Vector2.ONE, 0.14)
		mtw.parallel().tween_property(key_panel, "modulate", Color(0.72, 0.76, 0.8, 0.9), 0.2)
		mtw.tween_callback(func() -> void:
			if is_instance_valid(key_panel):
				_restyle_skill_key(idx)
		)
		return
	if is_gold_cast:
		flash = Color(1.0, 0.88, 0.4, 1.0)
		var gold := _UiStyle.panel(Color(0.18, 0.14, 0.06, 0.98), flash, 5)
		gold.set_border_width_all(3)
		gold.content_margin_left = 2
		gold.content_margin_right = 2
		gold.content_margin_top = 2
		gold.content_margin_bottom = 2
		key_panel.add_theme_stylebox_override("panel", gold)
		key_panel.pivot_offset = key_panel.size * 0.5
		key_panel.scale = Vector2(0.86, 0.86)
		# Soft dock rim ping so the whole bar notices the big skills.
		if _skill_dock:
			_skill_dock.modulate = Color(1.2, 1.1, 0.85)
			var dtw := create_tween()
			dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.28)
		key_panel.modulate = Color(1.45, 1.25, 0.85)
		_skill_cast_flash[key_name] = 18
		var labels_g := [_skill_l, _skill_u, _skill_i, _skill_o]
		if idx < labels_g.size() and labels_g[idx]:
			labels_g[idx].modulate = Color(1.0, 0.95, 0.7, 1.0)
		var gtw := create_tween()
		gtw.tween_property(key_panel, "scale", Vector2(1.14, 1.14), 0.1).set_trans(Tween.TRANS_BACK)
		gtw.tween_property(key_panel, "scale", Vector2.ONE, 0.14)
		gtw.parallel().tween_property(key_panel, "modulate", Color(0.72, 0.76, 0.8, 0.9), 0.22)
		gtw.tween_callback(func() -> void:
			if is_instance_valid(key_panel):
				_restyle_skill_key(idx)
		)
		return
	key_panel.modulate = Color(flash.r + 0.2, flash.g + 0.15, flash.b + 0.1, 1.0)
	_skill_cast_flash[key_name] = 18 # ~0.3s at 60fps — block CD dim stomp
	var labels := [_skill_l, _skill_u, _skill_i, _skill_o]
	if idx < labels.size() and labels[idx]:
		labels[idx].modulate = Color(1.0, 0.95, 0.7, 1.0)
	var tw := create_tween()
	tw.tween_property(key_panel, "modulate", Color(0.72, 0.76, 0.8, 0.9), 0.16)

func _restyle_skill_key(idx: int) -> void:
	if idx < 0 or idx >= _KEY_NODES.size():
		return
	var key := $Root/SkillDock/SkillBar.get_node_or_null(_KEY_NODES[idx]) as PanelContainer
	if key == null:
		return
	var accent: Color = _SKILL_ACCENTS[idx]
	var s := _UiStyle.panel(Color(0.07, 0.1, 0.13, 0.94), accent, 5)
	s.set_border_width_all(2)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	key.add_theme_stylebox_override("panel", s)

func _on_boss_hp(name: String, hp: int, max_hp: int) -> void:
	var first_show := _boss_bar != null and not _boss_bar.visible
	_boss_bar.visible = true
	_boss_name.text = name
	var ratio := 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_boss_hp_ratio = ratio
	var bar_w := 220.0
	_boss_hp_fill.size.x = bar_w * ratio
	# Base fill — low HP hotter 赤金; breath tick adds accelerate pulse.
	if ratio > 0.35:
		_boss_hp_fill.color = Color(1.0, 0.45, 0.3)
	elif ratio > 0.18:
		_boss_hp_fill.color = Color(1.0, 0.38, 0.22)
	else:
		_boss_hp_fill.color = Color(1.0, 0.28, 0.16)
	if first_show:
		call_deferred("_arm_boss_bar_land")

func _on_boss_hp_cleared() -> void:
	_boss_bar_land_t = 0.0
	_boss_bar_land_flat = null
	_boss_break_t = 0.0
	_boss_break_max = 0.0
	_boss_hp_ratio = 1.0
	if _boss_bar:
		_boss_bar.modulate = Color.WHITE
		_boss_bar.scale = Vector2.ONE
		_UiStyle.apply_panel(_boss_bar, Color(0.9, 0.45, 0.3, 0.55))
	if _boss_hp_fill:
		_boss_hp_fill.modulate = Color.WHITE
	if _boss_name:
		_boss_name.modulate = Color.WHITE
	_boss_bar.visible = false

## Boss bar entrance — 赤金 rim + fill kick (pairs minimap boss drop).
func _arm_boss_bar_land() -> void:
	if _boss_bar == null or not _boss_bar.visible:
		return
	_boss_bar_land_t = 0.55
	_boss_bar.pivot_offset = _boss_bar.size * 0.5
	var sb := _boss_bar.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		_boss_bar_land_flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		_boss_bar.add_theme_stylebox_override("panel", _boss_bar_land_flat)
	else:
		_boss_bar_land_flat = null
	_boss_bar.modulate = Color(1.35, 0.95, 0.55)
	_boss_bar.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.tween_property(_boss_bar, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_boss_bar, "scale", Vector2.ONE, 0.18)

func _tick_boss_bar_land() -> void:
	if _boss_bar == null or not _boss_bar.visible:
		return
	# 破绽 bar breath takes over once armed.
	if _boss_break_t > 0.0:
		return
	var a := clampf(_boss_bar_land_t / 0.55, 0.0, 1.0)
	if a <= 0.0:
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.024)
	# 赤金 — hotter than dynasty gold, matches minimap boss frame.
	_boss_bar.modulate = Color(
		minf(1.1 + 0.35 * a * pulse, 1.55),
		minf(0.7 + 0.25 * a * pulse, 1.15),
		minf(0.35 + 0.15 * a, 0.75)
	)
	if _boss_bar_land_flat:
		var punch := Color(1.0, 0.58, 0.28, 1.0)
		var settle := Color(0.9, 0.45, 0.3, 0.7)
		_boss_bar_land_flat.border_color = punch.lerp(settle, 1.0 - a)
		_boss_bar_land_flat.set_border_width_all(3 if a > 0.35 else 2)
	if _boss_hp_fill:
		_boss_hp_fill.modulate = Color(1.15 + 0.35 * a, 0.85 + 0.15 * a, 0.65 + 0.1 * a)
	if _boss_name:
		_boss_name.modulate = Color(1.0, 0.85 + 0.15 * a, 0.55 + 0.2 * a)

## Low boss HP — 赤金 breath speeds up as the bar drains (after land settles).
func _tick_boss_hp_low_breath() -> void:
	if _boss_bar == null or not _boss_bar.visible:
		return
	if _boss_bar_land_t > 0.0:
		return
	# 破绽 window owns the gold language — don't fight it with 赤金.
	if _boss_break_t > 0.0:
		return
	if _boss_hp_ratio > 0.35:
		if _boss_bar.modulate != Color.WHITE:
			_boss_bar.modulate = Color.WHITE
		if _boss_bar.scale != Vector2.ONE:
			_boss_bar.scale = Vector2.ONE
		if _boss_hp_fill and _boss_hp_fill.modulate != Color.WHITE:
			_boss_hp_fill.modulate = Color.WHITE
		if _boss_name and _boss_name.modulate != Color.WHITE:
			_boss_name.modulate = Color.WHITE
		if _boss_bar_land_flat:
			_boss_bar_land_flat.border_color = Color(0.9, 0.45, 0.3, 0.7)
			_boss_bar_land_flat.set_border_width_all(2)
		return
	# Faster clock as HP drops: 0.35→0.014, critical ≤0.18→0.028.
	var urgency := clampf((0.35 - _boss_hp_ratio) / 0.35, 0.0, 1.0)
	var hz := 0.014 + 0.016 * urgency
	if _boss_hp_ratio <= 0.18:
		hz = 0.028 + 0.01 * clampf((0.18 - _boss_hp_ratio) / 0.18, 0.0, 1.0)
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * hz)
	var amp := 0.12 + 0.22 * urgency
	_boss_bar.modulate = Color(
		minf(1.08 + amp * breath, 1.45),
		minf(0.72 + 0.15 * breath * urgency, 1.05),
		minf(0.4 + 0.08 * breath, 0.7)
	)
	_boss_bar.pivot_offset = _boss_bar.size * 0.5
	_boss_bar.scale = Vector2.ONE * (1.0 + 0.012 * breath * (0.6 + urgency))
	if _boss_bar_land_flat:
		var punch := Color(1.0, 0.55, 0.25, 0.95)
		var settle := Color(0.95, 0.4, 0.22, 0.75)
		_boss_bar_land_flat.border_color = settle.lerp(punch, breath)
		_boss_bar_land_flat.set_border_width_all(3 if breath > 0.55 and urgency > 0.5 else 2)
	if _boss_hp_fill:
		_boss_hp_fill.modulate = Color(
			1.05 + 0.35 * breath * (0.5 + urgency),
			0.7 + 0.15 * (1.0 - breath),
			0.5 + 0.1 * (1.0 - breath)
		)
		_boss_hp_fill.color = Color(
			1.0,
			0.22 + 0.12 * (1.0 - urgency) + 0.06 * breath,
			0.14 + 0.06 * (1.0 - urgency)
		)
	if _boss_name:
		_boss_name.modulate = Color(1.0, 0.7 + 0.2 * breath, 0.4 + 0.15 * breath)

func _on_boss(enemy_id: String) -> void:
	var enemy := ContentDB.get_enemy(enemy_id)
	show_clear(enemy.display_name if enemy else enemy_id)
	# Boss drop → kill bar shifts to 赤金 (pairs boss HP bar land).
	_arm_boss_kill_bar_land()

## Enter boss phase — kill bar 赤金 punch from teal/gold progress.
func _arm_boss_kill_bar_land() -> void:
	if _kill_fill == null:
		return
	_was_boss_kill_phase = true
	_boss_kill_land_t = 0.55
	# Hotter than near-clear gold — matches minimap boss 赤金 frame.
	_kill_fill.color = Color(1.0, 0.58, 0.28)
	_kill_fill.modulate = Color(1.45, 1.05, 0.7)
	if _kill_bg:
		_kill_bg.modulate = Color(1.35, 0.85, 0.55)
	if _kill_label:
		_kill_label.modulate = Color(1.0, 0.75, 0.45)
	_kill_fill.pivot_offset = Vector2(0, _kill_fill.size.y * 0.5)
	_kill_fill.scale = Vector2(1.0, 0.88)
	var tw := create_tween()
	tw.tween_property(_kill_fill, "scale", Vector2(1.0, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_kill_fill, "scale", Vector2.ONE, 0.16)
	_spawn_edge_flash(Color(1.0, 0.55, 0.28, 0.36), 10.0, 0.26)
	_spawn_edge_flash(Color(1.0, 0.72, 0.4, 0.16), 5.0, 0.16)

func _tick_boss_kill_bar_land() -> void:
	if _kill_fill == null:
		return
	var a := clampf(_boss_kill_land_t / 0.55, 0.0, 1.0)
	var stage := GameState.current_stage()
	var kills := GameState.stage_kills()
	var boss_phase := false
	if stage and not stage.boss_id.is_empty():
		boss_phase = kills >= stage.boss_at_kill and kills < stage.kill_target
	if not boss_phase:
		_was_boss_kill_phase = false
		_boss_kill_land_t = 0.0
		return
	if a > 0.0:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.028)
		_kill_fill.color = Color(1.0, 0.52 + 0.12 * a, 0.22 + 0.08 * a)
		_kill_fill.modulate = Color(
			minf(1.15 + 0.35 * a * pulse, 1.55),
			minf(0.7 + 0.25 * a * pulse, 1.15),
			minf(0.4 + 0.15 * a, 0.8)
		)
		if _kill_bg:
			_kill_bg.modulate = Color(1.1 + 0.2 * a, 0.75 + 0.1 * a, 0.5 + 0.1 * a)
		if _kill_label:
			_kill_label.modulate = Color(1.0, 0.7 + 0.2 * a, 0.4 + 0.15 * a)
	else:
		# Soft 赤金 hold while boss lives — quieter than enter punch.
		var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		_kill_fill.color = Color(1.0, 0.48 + 0.08 * breath, 0.28)
		_kill_fill.modulate = Color(1.0 + 0.08 * breath, 0.85 + 0.05 * breath, 0.7)
		if _kill_bg and _kill_bg.modulate != Color.WHITE:
			_kill_bg.modulate = Color(1.05, 0.82, 0.65).lerp(Color.WHITE, 0.35)
		if _kill_label:
			_kill_label.modulate = Color(1.0, 0.78 + 0.1 * breath, 0.5)

## Dynasty「收刀」— skill-dock warm-gold settle with minimap sheath / HUD edges.
func _flash_sheath_dock() -> void:
	if not _skill_dock:
		return
	var hot := _UiStyle.panel(Color(0.16, 0.1, 0.04, 0.94), Color(1.0, 0.86, 0.38, 0.95), 6)
	hot.set_border_width_all(3)
	hot.content_margin_left = 10
	hot.content_margin_right = 10
	hot.content_margin_top = 5
	hot.content_margin_bottom = 5
	_skill_dock.add_theme_stylebox_override("panel", hot)
	_skill_dock.modulate = Color(1.48, 1.2, 0.7)
	var dtw := create_tween()
	# ~0.55s sits between edge punch and minimap 0.82 sheath window.
	dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.55)
	dtw.tween_callback(_restore_skill_dock_style)

## Sect「通关」— courtyard-teal dock settle; quieter mirror of dynasty 收刀 gold.
func _flash_sect_dock() -> void:
	if not _skill_dock:
		return
	var hot := _UiStyle.panel(Color(0.04, 0.12, 0.12, 0.94), Color(0.42, 0.98, 0.9, 0.95), 6)
	hot.set_border_width_all(3)
	hot.content_margin_left = 10
	hot.content_margin_right = 10
	hot.content_margin_top = 5
	hot.content_margin_bottom = 5
	_skill_dock.add_theme_stylebox_override("panel", hot)
	_skill_dock.modulate = Color(0.78, 1.35, 1.28)
	var dtw := create_tween()
	# ~0.5s — pairs minimap sect clear 0.62, softer than sheath dock.
	dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.5)
	dtw.tween_callback(_restore_skill_dock_style)

## Boss telegraph start — coral dock flash with play_telegraph (not 破绽 gold / clear teal).
func flash_telegraph_dock() -> void:
	if not _skill_dock:
		return
	var coral := Color(1.0, 0.55, 0.3, 0.95)
	var hot := _UiStyle.panel(Color(0.18, 0.07, 0.04, 0.94), coral, 6)
	hot.set_border_width_all(3)
	hot.content_margin_left = 10
	hot.content_margin_right = 10
	hot.content_margin_top = 5
	hot.content_margin_bottom = 5
	_skill_dock.add_theme_stylebox_override("panel", hot)
	_skill_dock.modulate = Color(1.4, 0.95, 0.7)
	var dtw := create_tween()
	# Short warn punch — matches telegraph beep window, not full cast hold.
	dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.32)
	dtw.tween_callback(_restore_skill_dock_style)
	_spawn_edge_flash(Color(1.0, 0.52, 0.28, 0.38), 11.0, 0.26)
	_spawn_edge_flash(Color(1.0, 0.78, 0.4, 0.16), 5.0, 0.16)

## Boss 破绽 open — warm-gold dock with play_break / recover edges (not telegraph coral).
func flash_break_dock() -> void:
	if not _skill_dock:
		return
	var gold := Color(1.0, 0.9, 0.38, 0.95)
	var hot := _UiStyle.panel(Color(0.16, 0.11, 0.04, 0.94), gold, 6)
	hot.set_border_width_all(3)
	hot.content_margin_left = 10
	hot.content_margin_right = 10
	hot.content_margin_top = 5
	hot.content_margin_bottom = 5
	_skill_dock.add_theme_stylebox_override("panel", hot)
	_skill_dock.modulate = Color(1.45, 1.22, 0.72)
	var dtw := create_tween()
	# ~0.4s — pairs play_break triple + recover edge punch, not full window hold.
	dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.4)
	dtw.tween_callback(_restore_skill_dock_style)

## Elite land — warm-gold dock with play_elite_land / spawn edges (quieter than 破绽).
func flash_elite_dock() -> void:
	if not _skill_dock:
		return
	var gold := Color(1.0, 0.84, 0.4, 0.9)
	var hot := _UiStyle.panel(Color(0.14, 0.1, 0.04, 0.92), gold, 6)
	hot.set_border_width_all(3)
	hot.content_margin_left = 10
	hot.content_margin_right = 10
	hot.content_margin_top = 5
	hot.content_margin_bottom = 5
	_skill_dock.add_theme_stylebox_override("panel", hot)
	_skill_dock.modulate = Color(1.35, 1.15, 0.75)
	var dtw := create_tween()
	# ~0.3s — crown drop beep + edge punch; softer/shorter than 破绽 dock.
	dtw.tween_property(_skill_dock, "modulate", Color.WHITE, 0.3)
	dtw.tween_callback(_restore_skill_dock_style)

func _restore_skill_dock_style() -> void:
	if not is_instance_valid(_skill_dock):
		return
	var dock_sb := _UiStyle.panel(Color(0.05, 0.08, 0.11, 0.88), Color(0.78, 0.7, 0.42, 0.75), 6)
	dock_sb.set_border_width_all(2)
	dock_sb.content_margin_left = 10
	dock_sb.content_margin_right = 10
	dock_sb.content_margin_top = 5
	dock_sb.content_margin_bottom = 5
	_skill_dock.add_theme_stylebox_override("panel", dock_sb)

func _on_cleared(_stage_id: String) -> void:
	if _stage_id == "country" or _is_dynasty_city():
		# Clear blow banner — pairs with world「收刀」float.
		show_clear("收刀")
		_spawn_edge_flash(Color(1.0, 0.84, 0.38, 0.5), 14.0, 0.34)
		_spawn_edge_flash(Color(1.0, 0.94, 0.6, 0.24), 7.0, 0.22)
		_flash_sheath_dock()
		if _kill_fill:
			_kill_fill.color = _CITY_NEAR
			_kill_fill.modulate = Color(1.5, 1.25, 0.85)
			var tw := create_tween()
			# Same settle as dock — kill bar + 坞 share one 收刀 gold beat.
			tw.tween_property(_kill_fill, "modulate", Color.WHITE, 0.55)
		if _combo_label:
			_combo_label.visible = true
			_combo_label.text = "收刀"
			_combo_label.modulate = Color(1.0, 0.88, 0.45)
			_combo_label.scale = Vector2(0.8, 0.8)
			var ctw := create_tween()
			ctw.tween_property(_combo_label, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK)
			ctw.tween_property(_combo_label, "scale", Vector2.ONE, 0.14)
	elif _stage_id == "sect" or _is_sect_yard():
		# Courtyard clear — teal dock / edges / kill bar with minimap teal frame.
		show_clear("通关")
		_spawn_edge_flash(Color(0.4, 0.95, 0.88, 0.45), 14.0, 0.32)
		_spawn_edge_flash(Color(0.65, 1.0, 0.94, 0.2), 7.0, 0.2)
		_flash_sect_dock()
		if _kill_fill:
			_kill_fill.color = _SECT_TEAL_NEAR
			_kill_fill.modulate = Color(0.85, 1.4, 1.25)
			var tw2 := create_tween()
			tw2.tween_property(_kill_fill, "modulate", Color.WHITE, 0.5)
		if _combo_label:
			_combo_label.visible = true
			_combo_label.text = "通关"
			_combo_label.modulate = Color(0.55, 0.98, 0.9)
			_combo_label.scale = Vector2(0.82, 0.82)
			var ctw2 := create_tween()
			ctw2.tween_property(_combo_label, "scale", Vector2(1.16, 1.16), 0.1).set_trans(Tween.TRANS_BACK)
			ctw2.tween_property(_combo_label, "scale", Vector2.ONE, 0.14)
	else:
		show_clear("通关")
	_refresh()

func _on_stage_reward(stones: int) -> void:
	if GameState.last_clear_first:
		show_clear("首通 +%d石" % stones)
	else:
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
		_apply_kill_fill_color(kills, stage, ratio)
	else:
		_kill_label.text = "—"
		_kill_fill.size.x = 0.0

func _apply_kill_fill_color(kills: int, stage: StageDef, ratio: float) -> void:
	# Boss phase stays warm danger; sect progress = minimap teal, dynasty = gold.
	var near_clear := ratio >= 0.75 and kills < stage.kill_target
	var boss_phase := kills >= stage.boss_at_kill and not stage.boss_id.is_empty() and kills < stage.kill_target
	var yard := _is_sect_yard()
	var dynasty := _is_dynasty_city()
	if boss_phase:
		# 赤金 owned by land punch + soft breath tick — don't flatten to static red.
		if not _was_boss_kill_phase:
			_arm_boss_kill_bar_land()
	elif near_clear:
		# Dynasty breathes faster gold; sect calm teal lift — shared near-clear language.
		var hz := 0.018 if dynasty else 0.01
		var pulse := 0.5 + 0.45 * sin(Time.get_ticks_msec() * hz)
		if yard:
			_kill_fill.color = Color(_SECT_TEAL_NEAR.r, _SECT_TEAL_NEAR.g, _SECT_TEAL_NEAR.b, 0.6 + 0.4 * pulse)
			var lift := 1.0 + 0.16 * pulse
			_kill_fill.modulate = Color(lift * 0.85, lift, lift * 0.95)
			if _kill_bg:
				_kill_bg.modulate = Color(0.85 + 0.1 * pulse, 1.05 + 0.12 * pulse, 1.0 + 0.08 * pulse)
			if _kill_label:
				_kill_label.modulate = Color(0.55 + 0.15 * pulse, 0.95 + 0.05 * pulse, 0.88 + 0.1 * pulse)
		else:
			_kill_fill.color = Color(_CITY_NEAR.r, _CITY_NEAR.g, _CITY_NEAR.b, 0.55 + 0.45 * pulse)
			var lift2 := 1.0 + 0.2 * pulse
			_kill_fill.modulate = Color(lift2, lift2 * 0.92, lift2 * 0.72)
			if _kill_bg:
				_kill_bg.modulate = Color(1.0 + 0.14 * pulse, 0.95 + 0.06 * pulse, 0.8)
			if _kill_label and dynasty:
				_kill_label.modulate = Color(1.0, 0.9 + 0.08 * pulse, 0.55 + 0.2 * pulse)
	elif yard:
		_kill_fill.color = _SECT_TEAL_FILL
		_kill_fill.modulate = Color.WHITE
		if _kill_bg:
			_kill_bg.modulate = Color.WHITE
		if _kill_label:
			_kill_label.modulate = Color.WHITE
	else:
		_kill_fill.color = _CITY_GOLD
		_kill_fill.modulate = Color.WHITE
		if _kill_bg:
			_kill_bg.modulate = Color.WHITE
		if _kill_label:
			_kill_label.modulate = Color.WHITE

func _pulse_kill_bar_near_clear() -> void:
	var stage := GameState.current_stage()
	if stage == null or GameState.dead:
		return
	var kills := GameState.stage_kills()
	var target := maxi(stage.kill_target, 1)
	var ratio := clampf(float(kills) / float(target), 0.0, 1.0)
	var near_clear := ratio >= 0.75 and kills < stage.kill_target
	var boss_phase := kills >= stage.boss_at_kill and not stage.boss_id.is_empty() and kills < stage.kill_target
	if near_clear and not boss_phase:
		_apply_kill_fill_color(kills, stage, ratio)
		# Tiny vertical throb — dynasty hotter, sect softer but still readable.
		if _kill_fill and (_is_dynasty_city() or _is_sect_yard()):
			var hz := 0.02 if _is_dynasty_city() else 0.014
			var amp := 0.06 if _is_dynasty_city() else 0.045
			var throb := 1.0 + amp * sin(Time.get_ticks_msec() * hz)
			_kill_fill.pivot_offset = Vector2(0, _kill_fill.size.y * 0.5)
			_kill_fill.scale = Vector2(1.0, throb)
	elif _kill_fill and _kill_fill.scale != Vector2.ONE:
		_kill_fill.scale = Vector2.ONE
	if _stone_label and not _stone_flashing:
		_stone_label.text = "石 %d" % GameState.spirit_stones
	if GameState.combo >= 2 or (GameState.early_kill_hook() and GameState.combo >= 1):
		_refresh_combo_label()
	else:
		_combo_label.visible = false
	var root := $Root
	var crisis := GameState.hp > 0 and float(GameState.hp) / float(maxi(GameState.max_hp, 1)) <= 0.3
	# Leave edge color to _process when in crisis / near-clear breath.
	if not crisis and not _dynasty_near_clear_active() and not _sect_near_clear_active():
		for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
			var edge := root.get_node_or_null(edge_name) as ColorRect
			if edge:
				edge.color = Color(0.02, 0.03, 0.05, 0.26)
	if GameState.dead:
		_hint_label.visible = true
		var pity := GameState.last_death_pity
		var early := GameState.stage_id in ["sect", "country"]
		if pity > 0 and early:
			_hint_label.text = "抚恤 +%d石 · 回宗花石 / R再战" % pity
			_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		elif pity > 0:
			_hint_label.text = "抚恤 +%d石 · R再战" % pity
			_hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		else:
			_hint_label.text = "气散 · R再战 / 回宗花石"
			_hint_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.7))
	elif GameState.is_stage_cleared():
		_hint_label.visible = true
		_hint_label.text = "通关 · 回宗花石 / Esc选关"
	else:
		_hint_label.visible = false
