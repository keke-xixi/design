extends Control

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _hero: TextureRect = $HeroBleed
@onready var _tagline: Label = $Tagline
@onready var _status: Label = $StatusStrip
@onready var _stone_badge: Label = get_node_or_null("StoneBadge")
@onready var _spend_hint: Label = get_node_or_null("SpendHint")
@onready var _equip_hint: Label = $Footer/EquipHint
@onready var _challenge: Button = $ChallengeButton
@onready var _market_btn: Button = $SubNav/MarketButton
@onready var _alchemy_btn: Button = $SubNav/AlchemyButton
@onready var _equip_btn: Button = $SubNav/EquipmentButton
var _clear_hint: Label
## Sect first-clear → dynasty CTA (warm-gold pulse + 「外门已通」).
var _dynasty_pull := false
## Outer-sect still open → courtyard teal challenge CTA (vs dynasty gold).
var _sect_pull := false
var _dynasty_boost_t := 0.0  # Extra warm punch after「外门已通」toast.
var _gate_toast: Label
var _gate_flash_t := 0.0
var _gate_flash_teal := false
## MenuFrame stylebox — courtyard teal rim breath (pairs 宗门 · 首通).
var _menu_flat: StyleBoxFlat

func _ready() -> void:
	if has_node("MenuFrame"):
		# Cooler courtyard base — hub sits in 庭院 language, not generic cyan.
		_UiStyle.apply_panel($MenuFrame, Color(0.38, 0.88, 0.82, 0.55))
		var raw_sb = $MenuFrame.get_theme_stylebox("panel")
		if raw_sb is StyleBoxFlat:
			_menu_flat = (raw_sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			$MenuFrame.add_theme_stylebox_override("panel", _menu_flat)
			_menu_flat.border_color = Color(0.42, 0.9, 0.84, 0.55)
			_menu_flat.set_border_width_all(2)
	_UiStyle.apply_cta_button(_challenge)
	_UiStyle.apply_button(_equip_btn)
	_UiStyle.apply_button($Footer/QuitButton)
	_ensure_clear_hint()
	_load_hero_art()
	var tag := ContentDB.lore_tagline()
	# Soft ellipsis — keep brand line readable without hard-cutting mid-phrase.
	_tagline.text = tag if tag.length() <= 26 else tag.substr(0, 25) + "…"
	_refresh_status()
	EventBus.cultivation_broke_through.connect(func(_id): _refresh_status())
	EventBus.attack_gained.connect(func(_a, _t): _refresh_status())
	EventBus.item_gained.connect(func(_i, _a, _r): _refresh_status())
	EventBus.market_trade.connect(func(_a, _i, _q, _p): _refresh_status())
	EventBus.alchemy_crafted.connect(func(_r, _i, _q): _refresh_status())
	EventBus.gacha_rolled.connect(func(_p, _i, _q): _refresh_status())
	EventBus.equipment_changed.connect(_refresh_status)
	EventBus.stage_reward.connect(func(_s): _refresh_status())
	call_deferred("_maybe_celebrate_return")

func _maybe_celebrate_return() -> void:
	var gained := GameState.hub_celebrate_stones
	if gained <= 0:
		return
	var sect_return := GameState.last_clear_stage_id == "sect"
	var country_return := GameState.last_clear_stage_id == "country"
	GameState.hub_celebrate_stones = 0
	# Fresh purse flash — closes clear → hub spend loop without a modal.
	if _stone_badge:
		_stone_badge.text = "石 %d  +%d" % [GameState.spirit_stones, gained]
		_stone_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
		_stone_badge.modulate = Color(1.35, 1.2, 0.85)
		var tw := create_tween()
		tw.tween_property(_stone_badge, "modulate", Color.WHITE, 0.85)
		tw.tween_callback(_refresh_status)
	if _spend_hint:
		var alch := _cheapest_alchemy()
		var mkt := _cheapest_market()
		if country_return:
			_spend_hint.text = "收刀 · 花石 炼丹%d / 坊市%d" % [alch, mkt]
		else:
			_spend_hint.text = "石到手 · 炼丹%d / 坊市%d" % [alch, mkt]
		_spend_hint.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7) if not country_return else Color(1.0, 0.92, 0.55))
		_spend_hint.modulate = Color(1.2, 1.15, 0.95)
		var tw2 := create_tween()
		tw2.tween_property(_spend_hint, "modulate", Color.WHITE, 1.0)
	# Pulse spend buttons harder for a beat.
	if _market_btn and GameState.spirit_stones >= _cheapest_market():
		_UiStyle.apply_cta_button(_market_btn)
		_market_btn.text = "坊市 · 花"
	elif _alchemy_btn and GameState.spirit_stones >= _cheapest_alchemy():
		_UiStyle.apply_cta_button(_alchemy_btn)
		_alchemy_btn.text = "炼丹 · 花"
	# Outer-sect clear → shout once, then dynasty CTA stays warm-gold.
	if sect_return:
		_flash_outer_cleared_toast()
		# Kick challenge breath half a beat louder after 外门已通.
		_dynasty_boost_t = 1.4
		call_deferred("_flash_dynasty_waiting_tip")
		# Courtyard teal pop on the 选关 CTA — radar-clear echo, then gold bait.
		_flash_stage_gate(true)
	elif country_return:
		# Dynasty clear → 「收刀到手 · 花石」 celebrates the purse.
		_flash_shoudao_toast(gained)
		_flash_stage_gate(false)
		# Next stage-select visit echoes「收刀」on the fight tip.
		GameState.hub_shoudao_enter = true
	# Loud 1s spend CTA: market when affordable, else alchemy pills.
	if GameState.spirit_stones >= _cheapest_market():
		_highlight_market_if_can_buy()
	else:
		_highlight_alchemy_if_can_buy()
	get_tree().create_timer(2.2, true).timeout.connect(_refresh_status)
	_refresh_status()

func _flash_outer_cleared_toast() -> void:
	_ensure_gate_toast()
	if _gate_toast == null:
		return
	_gate_toast.visible = true
	_gate_toast.text = "外门已通"
	_gate_toast.modulate = Color(1.35, 1.15, 0.7)
	_gate_toast.scale = Vector2(0.86, 0.86)
	_gate_toast.pivot_offset = _gate_toast.size * 0.5
	var tw := create_tween()
	tw.tween_property(_gate_toast, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_gate_toast, "scale", Vector2.ONE, 0.16)
	tw.tween_interval(1.4)
	tw.tween_property(_gate_toast, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if _gate_toast:
			_gate_toast.visible = false
			_gate_toast.modulate = Color.WHITE
	)

## Beside选关 CTA — warm-gold「王朝在等」pops after 外门已通 return.
func _flash_dynasty_waiting_tip() -> void:
	_ensure_clear_hint()
	if _clear_hint == null:
		return
	if not _is_dynasty_pull():
		return
	_clear_hint.visible = true
	_clear_hint.text = "王朝在等"
	_clear_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48))
	_clear_hint.modulate = Color(1.5, 1.28, 0.75)
	_clear_hint.scale = Vector2(0.86, 0.86)
	_clear_hint.pivot_offset = _clear_hint.size * 0.5
	var tw := create_tween()
	tw.tween_property(_clear_hint, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_clear_hint, "scale", Vector2.ONE, 0.16)
	tw.parallel().tween_property(_clear_hint, "modulate", Color.WHITE, 0.45)

## 选关 CTA pop on hub return — sect teal / dynasty gold (pairs combat radar clear).
func _flash_stage_gate(teal: bool) -> void:
	if _challenge == null:
		return
	_gate_flash_teal = teal
	_gate_flash_t = 0.85
	_challenge.pivot_offset = _challenge.size * 0.5
	_challenge.scale = Vector2(0.88, 0.88)
	if teal:
		_challenge.modulate = Color(0.55, 1.15, 1.05)
		_challenge.add_theme_color_override("font_color", Color(0.45, 0.98, 0.9))
	else:
		_challenge.modulate = Color(1.4, 1.18, 0.7)
		_challenge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	var tw := create_tween()
	tw.tween_property(_challenge, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_challenge, "scale", Vector2.ONE, 0.18)

## After dynasty「收刀」return — celebrate flower-stones into the spend loop.
func _flash_shoudao_toast(gained: int = 0) -> void:
	_ensure_gate_toast()
	if _gate_toast == null:
		return
	_gate_toast.visible = true
	_gate_toast.size = Vector2(220, 34)
	_gate_toast.position = Vector2(228, 146)
	_gate_toast.add_theme_font_size_override("font_size", 15)
	_gate_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48))
	_gate_toast.text = "收刀到手 · 花石"
	_gate_toast.modulate = Color(1.4, 1.2, 0.75)
	_gate_toast.scale = Vector2(0.82, 0.82)
	_gate_toast.pivot_offset = _gate_toast.size * 0.5
	var tw := create_tween()
	tw.tween_property(_gate_toast, "scale", Vector2(1.14, 1.14), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_gate_toast, "scale", Vector2.ONE, 0.16)
	tw.tween_interval(1.55)
	tw.tween_property(_gate_toast, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if _gate_toast:
			_gate_toast.visible = false
			_gate_toast.modulate = Color.WHITE
			_gate_toast.text = "收刀到手 · 花石"
	)
	# Brief spend-hint echo so the CTA language lands twice.
	if _spend_hint:
		_spend_hint.text = "收刀到手 · 花石"
		_spend_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_flash_shoudao_spend_gold()

## Stone badge + 花石 spend buttons kick warm-gold with the toast.
func _flash_shoudao_spend_gold() -> void:
	if _stone_badge:
		_stone_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		_stone_badge.modulate = Color(1.55, 1.3, 0.8)
		_stone_badge.pivot_offset = _stone_badge.size * 0.5
		_stone_badge.scale = Vector2(0.88, 0.88)
		var stw := create_tween()
		stw.tween_property(_stone_badge, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK)
		stw.tween_property(_stone_badge, "scale", Vector2.ONE, 0.16)
		stw.parallel().tween_property(_stone_badge, "modulate", Color.WHITE, 0.55)
	# Prefer affordable 花石 CTA: market first, else alchemy.
	var flower: Button = null
	if _market_btn and GameState.spirit_stones >= _cheapest_market():
		flower = _market_btn
		_UiStyle.apply_cta_button(_market_btn)
		_market_btn.text = "坊市 · 花"
	elif _alchemy_btn and GameState.spirit_stones >= _cheapest_alchemy():
		flower = _alchemy_btn
		_UiStyle.apply_cta_button(_alchemy_btn)
		_alchemy_btn.text = "炼丹 · 花"
	elif _market_btn:
		flower = _market_btn
		_market_btn.text = "坊市 · 花"
	elif _alchemy_btn:
		flower = _alchemy_btn
		_alchemy_btn.text = "炼丹 · 花"
	if flower == null:
		return
	flower.modulate = Color(1.5, 1.25, 0.75)
	flower.pivot_offset = flower.size * 0.5
	flower.scale = Vector2(0.9, 0.9)
	flower.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55))
	var ftw := create_tween()
	ftw.tween_property(flower, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	ftw.tween_property(flower, "scale", Vector2.ONE, 0.18)
	# Hold warm gold a beat, then settle so spend desire lingers.
	ftw.tween_interval(0.45)
	ftw.tween_property(flower, "modulate", Color.WHITE, 0.4)

## Enough stones for a pill → alchemy CTA highlights ~1s (花石→丹).
func _highlight_alchemy_if_can_buy() -> void:
	if _alchemy_btn == null:
		return
	var cost := _cheapest_alchemy()
	if GameState.spirit_stones < cost:
		return
	_UiStyle.apply_cta_button(_alchemy_btn)
	_alchemy_btn.text = "炼丹 · 花"
	_alchemy_btn.tooltip_text = "最低 %d 灵石 · 可炼丹" % cost
	_alchemy_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55))
	_alchemy_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.8))
	_alchemy_btn.modulate = Color(1.5, 1.3, 0.78)
	_alchemy_btn.pivot_offset = _alchemy_btn.size * 0.5
	_alchemy_btn.scale = Vector2(0.92, 0.92)
	# Soft dim market so the eye sticks on 炼丹.
	if _market_btn:
		_market_btn.modulate = Color(0.75, 0.78, 0.8, 0.85)
	if _spend_hint:
		_spend_hint.text = "可炼丹 · %d石起" % cost
		_spend_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	var tw := create_tween()
	tw.tween_property(_alchemy_btn, "scale", Vector2(1.14, 1.14), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_alchemy_btn, "scale", Vector2.ONE, 0.14)
	# Hold the highlight for about one second, then settle.
	tw.tween_interval(1.0)
	tw.tween_property(_alchemy_btn, "modulate", Color.WHITE, 0.28)
	if _market_btn:
		tw.parallel().tween_property(_market_btn, "modulate", Color.WHITE, 0.28)
	tw.tween_callback(_refresh_status)

## Enough stones for market goods → 「坊市 · 花」highlights ~1s (花石→货).
func _highlight_market_if_can_buy() -> void:
	if _market_btn == null:
		return
	var cost := _cheapest_market()
	if GameState.spirit_stones < cost:
		return
	_UiStyle.apply_cta_button(_market_btn)
	_market_btn.text = "坊市 · 花"
	_market_btn.tooltip_text = "最低 %d 灵石 · 可买入" % cost
	_market_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55))
	_market_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.8))
	_market_btn.modulate = Color(1.5, 1.3, 0.78)
	_market_btn.pivot_offset = _market_btn.size * 0.5
	_market_btn.scale = Vector2(0.92, 0.92)
	# Soft dim alchemy so the eye sticks on 坊市.
	if _alchemy_btn:
		_alchemy_btn.modulate = Color(0.75, 0.78, 0.8, 0.85)
	if _spend_hint:
		_spend_hint.text = "可买货 · %d石起" % cost
		_spend_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	var tw := create_tween()
	tw.tween_property(_market_btn, "scale", Vector2(1.14, 1.14), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_market_btn, "scale", Vector2.ONE, 0.14)
	tw.tween_interval(1.0)
	tw.tween_property(_market_btn, "modulate", Color.WHITE, 0.28)
	if _alchemy_btn:
		tw.parallel().tween_property(_alchemy_btn, "modulate", Color.WHITE, 0.28)
	tw.tween_callback(_refresh_status)

func _ensure_gate_toast() -> void:
	_gate_toast = get_node_or_null("GateToast") as Label
	if _gate_toast:
		return
	_gate_toast = Label.new()
	_gate_toast.name = "GateToast"
	_gate_toast.position = Vector2(248, 148)
	_gate_toast.size = Vector2(180, 32)
	_gate_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_toast.add_theme_font_size_override("font_size", 16)
	_gate_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_gate_toast.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.0, 0.85))
	_gate_toast.add_theme_constant_override("shadow_offset_x", 1)
	_gate_toast.add_theme_constant_override("shadow_offset_y", 1)
	_gate_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_toast.visible = false
	_gate_toast.z_index = 8
	add_child(_gate_toast)

func _ensure_clear_hint() -> void:
	_clear_hint = get_node_or_null("ClearHint") as Label
	if _clear_hint:
		return
	_clear_hint = Label.new()
	_clear_hint.name = "ClearHint"
	# Sit just right of ChallengeButton (26–226 × 178–218).
	_clear_hint.position = Vector2(234, 186)
	_clear_hint.size = Vector2(120, 28)
	_clear_hint.add_theme_font_size_override("font_size", 12)
	_clear_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_clear_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_clear_hint.add_theme_constant_override("shadow_offset_x", 1)
	_clear_hint.add_theme_constant_override("shadow_offset_y", 1)
	_clear_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clear_hint)

func _tick_menuframe_breath(t: float, gate_a: float) -> void:
	if not has_node("MenuFrame"):
		return
	var frame := $MenuFrame as CanvasItem
	var breath := 0.5 + 0.5 * sin(t * 1.15)
	if gate_a > 0.0 and _gate_flash_teal:
		# Return teal slap — louder rim for half a beat.
		frame.modulate = Color(0.82 + 0.12 * gate_a, 1.12 + 0.15 * gate_a, 1.08 + 0.1 * gate_a)
		if _menu_flat:
			_menu_flat.border_color = Color(0.35, 1.0, 0.92, 0.55 + 0.4 * gate_a)
			_menu_flat.set_border_width_all(3)
	elif _sect_pull:
		# Courtyard teal rim — pairs「宗门 · 首通」CTA breath.
		frame.modulate = Color(0.9 + 0.08 * breath, 1.06 + 0.1 * breath, 1.02 + 0.08 * breath)
		if _menu_flat:
			_menu_flat.border_color = Color(0.38, 0.96, 0.88, 0.48 + 0.38 * breath)
			_menu_flat.set_border_width_all(2)
	elif _dynasty_pull:
		# Soft gold rim while dynasty bait owns the CTA (don't keep teal fighting gold).
		frame.modulate = Color(1.06 + 0.06 * breath, 0.98 + 0.04 * breath, 0.82 + 0.02 * breath)
		if _menu_flat:
			_menu_flat.border_color = Color(1.0, 0.84, 0.4, 0.42 + 0.3 * breath)
			_menu_flat.set_border_width_all(2)
	else:
		# Quiet always-on courtyard teal — hub identity without shouting.
		frame.modulate = Color(0.97 + 0.03 * breath, 1.02 + 0.04 * breath, 1.0 + 0.03 * breath)
		if _menu_flat:
			_menu_flat.border_color = Color(0.45, 0.84, 0.8, 0.32 + 0.22 * breath)
			_menu_flat.set_border_width_all(1)

func _estimate_clear_stones(stage: StageDef) -> int:
	var g := ContentDB.section("growth")
	var stones := int(g.get("stage_clear_stones_base", 15)) + stage.order * int(g.get("stage_clear_stones_per_order", 8))
	stones += int(g.get("stage_clear_first_bonus", 8))
	if stage.id in ["sect", "country"]:
		stones += int(g.get("early_clear_stones_bonus", 8))
		stones += int(g.get("early_first_clear_extra", 10))
	return stones

func _load_hero_art() -> void:
	var preferred := "res://assets/characters/hub_hero.png"
	var fallback := "res://assets/characters/player_clear.png"
	var path := preferred if ResourceLoader.exists(preferred) else fallback
	var tex: Texture2D = load(path)
	if tex:
		_hero.texture = tex

func _process(_delta: float) -> void:
	if _challenge == null:
		return
	if _dynasty_boost_t > 0.0:
		_dynasty_boost_t = maxf(_dynasty_boost_t - _delta, 0.0)
	if _gate_flash_t > 0.0:
		_gate_flash_t = maxf(_gate_flash_t - _delta, 0.0)
	var t := Time.get_ticks_msec() * 0.002
	var first_open := _next_first_clear_stage() != null
	var boost := clampf(_dynasty_boost_t / 1.4, 0.0, 1.0)
	var gate_a := clampf(_gate_flash_t / 0.85, 0.0, 1.0)
	if gate_a > 0.0:
		# Return pop wins the first beat — teal 宗门 / gold 王朝.
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.018)
		if _gate_flash_teal:
			_challenge.modulate = Color(0.5 + 0.2 * pulse, 1.05 + 0.15 * pulse, 0.95 + 0.1 * pulse)
			_challenge.add_theme_color_override("font_color", Color(0.42, 0.98, 0.9, 0.7 + 0.3 * gate_a))
		else:
			_challenge.modulate = Color(1.25 + 0.2 * pulse, 0.95 + 0.12 * pulse, 0.45 + 0.1 * pulse)
			_challenge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4, 0.7 + 0.3 * gate_a))
		_challenge.pivot_offset = _challenge.size * 0.5
	elif _dynasty_pull:
		# Half-beat snappier warm-gold — dynasty CTA matches 花石 spend pulse.
		var hz := 2.05
		var g := 1.0 + (0.16 + 0.08 * boost) * sin(t * hz)
		_challenge.modulate = Color(minf(g * 1.28, 1.55), minf(g * 0.92, 1.22), minf(g * 0.52, 0.92))
		var s := 1.0 + (0.045 + 0.03 * boost) * sin(t * hz)
		_challenge.scale = Vector2(s, s)
		_challenge.pivot_offset = _challenge.size * 0.5
		# Soft gold ink breath on the label itself.
		var ink := 0.55 + 0.45 * (0.5 + 0.5 * sin(t * hz))
		_challenge.add_theme_color_override(
			"font_color",
			Color(1.0, 0.86 + 0.1 * ink, 0.4 + 0.12 * ink)
		)
	elif _sect_pull:
		# Courtyard teal breath — 宗门 · 首通 vs dynasty warm-gold.
		var hz_t := 1.85
		var gt := 1.0 + 0.14 * sin(t * hz_t)
		_challenge.modulate = Color(0.55 + 0.12 * gt, minf(gt * 1.12, 1.4), minf(gt * 1.05, 1.28))
		var st := 1.0 + 0.04 * sin(t * hz_t)
		_challenge.scale = Vector2(st, st)
		_challenge.pivot_offset = _challenge.size * 0.5
		var ink_t := 0.55 + 0.45 * (0.5 + 0.5 * sin(t * hz_t))
		_challenge.add_theme_color_override(
			"font_color",
			Color(0.38 + 0.08 * ink_t, 0.95 + 0.04 * ink_t, 0.88 + 0.06 * ink_t)
		)
	elif first_open:
		# Soft warm pull for later-stage first clears (not 宗门/王朝).
		var g2 := 1.0 + 0.1 * sin(t * 1.35)
		_challenge.modulate = Color(minf(g2 * 1.12, 1.4), minf(g2 * 0.98, 1.2), minf(g2 * 0.72, 1.0))
		var s2 := 1.0 + 0.028 * sin(t * 1.35)
		_challenge.scale = Vector2(s2, s2)
		_challenge.pivot_offset = _challenge.size * 0.5
	else:
		var glow := 1.0 + 0.05 * sin(t)
		_challenge.modulate = Color(glow, glow * 0.97, glow * 0.9)
		_challenge.scale = Vector2.ONE
	# Soft hero float + glow/shadow breathe with the CTA pulse.
	if _hero:
		_hero.position.y = -18.0 + sin(t * 0.8) * 4.0
	if has_node("HeroGlow"):
		var hg := $HeroGlow as ColorRect
		if gate_a > 0.0:
			if _gate_flash_teal:
				hg.color = Color(0.35, 0.9, 0.85, 0.12 + 0.16 * gate_a)
			else:
				hg.color = Color(0.95, 0.72, 0.32, 0.12 + 0.16 * gate_a)
		elif _dynasty_pull:
			# Warm wash under hero when dynasty is the bait.
			var hw := 1.2 + 0.35 * boost
			hg.color = Color(0.95, 0.72, 0.35, (0.1 + 0.08 * (0.5 + 0.5 * sin(t * 1.6))) * hw)
		elif _sect_pull:
			# Cool courtyard wash — pairs MapFrame teal / 选关庭院.
			hg.color = Color(0.35, 0.88, 0.82, 0.1 + 0.08 * (0.5 + 0.5 * sin(t * 1.5)))
		else:
			hg.color = Color(0.45, 0.75, 0.95, 0.1 + 0.06 * (0.5 + 0.5 * sin(t * 0.9)))
	if has_node("HeroShadow"):
		var hs := $HeroShadow as ColorRect
		var w := 100.0 + 12.0 * sin(t * 0.8)
		hs.offset_left = 460.0 - w
		hs.offset_right = 460.0 + w
		hs.color.a = 0.28 + 0.1 * (0.5 + 0.5 * sin(t * 0.8 + 0.4))
	if has_node("Brand"):
		$Brand.modulate = Color(1.0, 1.0, 1.0, 0.92 + 0.08 * sin(t * 0.6))
	_tick_menuframe_breath(t, gate_a)
	# First-clear hint breathes with the challenge CTA.
	if _clear_hint and _clear_hint.visible and (_dynasty_pull or _sect_pull or first_open):
		var g0 := 1.0 + (0.12 + 0.06 * boost) * sin(t * 2.0)
		if _dynasty_pull:
			_clear_hint.modulate = Color(minf(g0 * 1.2, 1.45), minf(g0 * 0.94, 1.22), minf(g0 * 0.55, 1.0))
		elif _sect_pull:
			_clear_hint.modulate = Color(0.55 + 0.15 * g0, minf(g0 * 1.1, 1.35), minf(g0 * 1.02, 1.25))
		else:
			_clear_hint.modulate = Color(minf(g0 * 1.08, 1.3), minf(g0 * 0.96, 1.15), minf(g0 * 0.75, 1.0))
	elif _clear_hint:
		_clear_hint.modulate = Color.WHITE
	# Stone badge breathes when you can afford a spend loop action.
	if _stone_badge and GameState.spirit_stones >= _cheapest_spend():
		var g2 := 1.0 + 0.05 * sin(t * 1.4)
		_stone_badge.modulate = Color(g2, g2 * 0.95, g2 * 0.85)
	elif _stone_badge:
		_stone_badge.modulate = Color.WHITE
	_pulse_spend_buttons(t)

func _pulse_spend_buttons(t: float) -> void:
	var stones := GameState.spirit_stones
	var can_alch := stones >= _cheapest_alchemy()
	var can_mkt := stones >= _cheapest_market()
	if _alchemy_btn and can_alch and not can_mkt:
		var g := 1.0 + 0.06 * sin(t * 1.6)
		_alchemy_btn.modulate = Color(g, g * 0.98, g * 0.9)
	elif _alchemy_btn:
		_alchemy_btn.modulate = Color.WHITE
	if _market_btn and can_mkt:
		var g2 := 1.0 + 0.06 * sin(t * 1.5 + 0.3)
		_market_btn.modulate = Color(g2, g2 * 0.98, g2 * 0.9)
	elif _market_btn:
		_market_btn.modulate = Color.WHITE

func _cheapest_alchemy() -> int:
	var best := 99999
	for raw in ContentDB.alchemy_recipes():
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		best = mini(best, int(raw.get("cost_stones", 99999)))
	for raw in ContentDB.alchemy_gacha_pools():
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		best = mini(best, int(raw.get("cost_stones", 99999)))
	return best if best < 99999 else 5

func _cheapest_market() -> int:
	var best := 99999
	if MarketService:
		for raw in MarketService.all_listings():
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var price := int(raw.get("price", 0))
			if price > 0:
				best = mini(best, price)
	return best if best < 99999 else 18

func _cheapest_spend() -> int:
	return mini(_cheapest_alchemy(), _cheapest_market())

func _refresh_status() -> void:
	var c := GameState.cultivation
	var realm := ContentDB.realms.get_realm(c.attack_realm_id)
	var realm_name := realm.display_name if realm else c.attack_realm_id
	var bonus := GameState.equipment_bonus()
	_status.text = "%s  ·  攻 %d" % [
		realm_name,
		c.attack + int(bonus.get("attack", 0)),
	]
	var stones := GameState.spirit_stones
	if _stone_badge:
		_stone_badge.text = "石 %d" % stones
		_stone_badge.add_theme_color_override(
			"font_color",
			Color(1.0, 0.92, 0.55) if stones >= _cheapest_spend() else Color(0.85, 0.82, 0.7)
		)
	var alch_cost := _cheapest_alchemy()
	var mkt_cost := _cheapest_market()
	var can_alch := stones >= alch_cost
	var can_mkt := stones >= mkt_cost
	if _spend_hint:
		if can_alch or can_mkt:
			var bits: Array[String] = []
			if can_alch:
				bits.append("炼丹%d起" % alch_cost)
			if can_mkt:
				bits.append("坊市%d起" % mkt_cost)
			_spend_hint.text = "可花 · " + " / ".join(bits)
			_spend_hint.add_theme_color_override("font_color", Color(0.75, 0.95, 0.7))
		elif stones > 0:
			_spend_hint.text = "再攒 · 炼丹%d / 坊市%d" % [alch_cost, mkt_cost]
			_spend_hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.78, 0.9))
		else:
			_spend_hint.text = "出战攒石 · 再回花"
			_spend_hint.add_theme_color_override("font_color", Color(0.7, 0.76, 0.8, 0.88))
	# Spend CTAs light up when affordable — closes the hub loop.
	if _alchemy_btn:
		_alchemy_btn.text = "炼丹 ✓" if can_alch else "炼丹"
		if can_alch:
			_UiStyle.apply_primary_button(_alchemy_btn)
		else:
			_UiStyle.apply_button(_alchemy_btn)
		_alchemy_btn.tooltip_text = "最低 %d 灵石" % alch_cost
	if _market_btn:
		_market_btn.text = "坊市 ✓" if can_mkt else "坊市"
		if can_mkt:
			_UiStyle.apply_primary_button(_market_btn)
		else:
			_UiStyle.apply_button(_market_btn)
		_market_btn.tooltip_text = "最低 %d 灵石" % mkt_cost
	var next_stage := _recommended_stage()
	var first_target := _next_first_clear_stage()
	_dynasty_pull = _is_dynasty_pull()
	_sect_pull = first_target != null and first_target.id == "sect" and GameState.can_enter(first_target)
	if _dynasty_pull and first_target and first_target.id == "country":
		var est := _estimate_clear_stones(first_target)
		_challenge.text = "王朝 · 首通"
		_challenge.tooltip_text = "外门已通 · 首通约 +%d 灵石" % est
		_challenge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48))
		_challenge.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.7))
		_UiStyle.apply_cta_button(_challenge)
		if _clear_hint:
			_clear_hint.visible = true
			# Short bait beside CTA — toast already shouted「外门已通」.
			_clear_hint.text = "王朝在等"
			_clear_hint.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	elif _sect_pull and first_target:
		var est_s := _estimate_clear_stones(first_target)
		_challenge.text = "宗门 · 首通"
		_challenge.tooltip_text = "庭院首通约 +%d 灵石" % est_s
		_challenge.add_theme_color_override("font_color", Color(0.42, 0.96, 0.88))
		_challenge.add_theme_color_override("font_hover_color", Color(0.65, 1.0, 0.95))
		_UiStyle.apply_cta_button(_challenge)
		if _clear_hint:
			_clear_hint.visible = true
			_clear_hint.text = "庭院待战 · ~%d石" % est_s
			_clear_hint.add_theme_color_override("font_color", Color(0.45, 0.95, 0.88))
	elif first_target:
		var est := _estimate_clear_stones(first_target)
		_challenge.text = "首通 · %s" % first_target.display_name
		_challenge.tooltip_text = "首通约 +%d 灵石" % est
		_challenge.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62))
		_challenge.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.8))
		if _clear_hint:
			_clear_hint.visible = true
			_clear_hint.text = "首通 ~%d石" % est
			_clear_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	elif next_stage:
		_challenge.text = "进入 · %s" % next_stage.display_name
		_challenge.tooltip_text = "推荐挑战：%s" % next_stage.display_name
		_challenge.remove_theme_color_override("font_color")
		_challenge.remove_theme_color_override("font_hover_color")
		if _clear_hint:
			_clear_hint.visible = true
			_clear_hint.text = "再战攒石"
			_clear_hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.86, 0.9))
	else:
		_challenge.text = "进入战场"
		_challenge.tooltip_text = ""
		_challenge.remove_theme_color_override("font_color")
		_challenge.remove_theme_color_override("font_hover_color")
		if _clear_hint:
			_clear_hint.visible = false
	var eq := GameState.equipment
	_equip_hint.text = "武 %s · 甲 %s · 饰 %s" % [_name(eq.weapon), _name(eq.armor), _name(eq.accessory)]

func _is_dynasty_pull() -> bool:
	if not GameState.is_stage_cleared("sect"):
		return false
	if GameState.is_stage_cleared("country"):
		return false
	var country := ContentDB.get_stage("country")
	return country != null and GameState.can_enter(country)

func _next_first_clear_stage() -> StageDef:
	# Prefer early uncleared, then any unlocked uncleared by order.
	for sid in ["sect", "country"]:
		var st := ContentDB.get_stage(sid)
		if st and GameState.can_enter(st) and not GameState.is_stage_cleared(st.id):
			return st
	var best: StageDef = null
	for stage in ContentDB.stages.all_stages():
		if stage == null or not GameState.can_enter(stage):
			continue
		if GameState.is_stage_cleared(stage.id):
			continue
		if best == null or stage.order < best.order:
			best = stage
	return best

func _recommended_stage() -> StageDef:
	# Prefer first-clear bait so Hub CTA pulls toward unfinished maps.
	var first := _next_first_clear_stage()
	if first:
		return first
	var best: StageDef = null
	for stage in ContentDB.stages.all_stages():
		if stage == null or not GameState.can_enter(stage):
			continue
		if best == null or stage.order > best.order:
			best = stage
	return best

func _name(item_id: String) -> String:
	if item_id.is_empty():
		return "—"
	var item := ContentDB.get_item(item_id)
	return item.display_name if item else item_id

func _on_challenge_pressed() -> void:
	# Carry fight CTA into stage select —「开战到手 · 选关」tip.
	GameState.hub_fight_enter = true
	# 「王朝 · 首通」→ 王朝 row；「宗门 · 首通」→ 庭院 row.
	if _dynasty_pull or (_challenge and "王朝" in _challenge.text):
		GameState.stage_select_focus_id = "country"
	elif _sect_pull or (_challenge and "宗门" in _challenge.text):
		GameState.stage_select_focus_id = "sect"
	SceneManager.go_stage_select()

func _on_market_pressed() -> void:
	# Carry flower CTA into market so the page can greet with「花石坊市」.
	if _market_btn and "花" in _market_btn.text:
		GameState.market_flower_enter = true
	SceneManager.go_market()

func _on_equipment_pressed() -> void:
	SceneManager.go_equipment()

func _on_alchemy_pressed() -> void:
	# Carry flower CTA into alchemy so the page can greet with「花石炼丹」.
	if _alchemy_btn and "花" in _alchemy_btn.text:
		GameState.alchemy_flower_enter = true
	SceneManager.go_alchemy()

func _on_quit_pressed() -> void:
	SaveService.save_game()
	get_tree().quit()
