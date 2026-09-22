extends Control

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _title: Label = $Panel/Header/Title
@onready var _stones: Label = $Panel/Header/Stones
@onready var _list: VBoxContainer = $Panel/Body/Scroll/List
@onready var _bag: VBoxContainer = $Panel/Body/BagPanel/BagVBox/BagList
@onready var _status: Label = $Panel/Status
@onready var _sell_item: OptionButton = $Panel/SellRow/SellItem
@onready var _sell_qty: SpinBox = $Panel/SellRow/SellQty
@onready var _sell_price: SpinBox = $Panel/SellRow/SellPrice
@onready var _fight_btn: Button = get_node_or_null("Panel/ActionBar/FightButton")
@onready var _hub_btn: Button = get_node_or_null("Panel/ActionBar/HubButton")
@onready var _hint: Label = get_node_or_null("Panel/Hint")

var _bought_this_visit := false
var _last_buy_name := ""
var _last_buy_was_pill := false
var _fight_cta_hot := false  # Loud pulse after pill buy — 「买了就打」

func _ready() -> void:
	_UiStyle.apply_button($Panel/Header/BackButton)
	_UiStyle.apply_button($Panel/SellRow/ListButton)
	if _hub_btn:
		_UiStyle.apply_button(_hub_btn)
	if _fight_btn:
		_UiStyle.apply_cta_button(_fight_btn)
		_fight_btn.visible = false
	if has_node("Panel/Body/BagPanel"):
		_UiStyle.apply_panel($Panel/Body/BagPanel)
	MarketService.refresh_npc_listings()
	_refresh_header()
	_build_listings()
	_build_bag()
	_populate_sell_items()
	_update_fight_cta()
	EventBus.market_trade.connect(_on_market_trade)
	EventBus.item_gained.connect(func(_i, _a, _r): _refresh_all())
	if GameState.market_flower_enter:
		GameState.market_flower_enter = false
		call_deferred("_flash_flower_market_tip")

## Hub「坊市 · 花」entry → warm-gold tip aligned with hub「收刀到手 · 花石」。
func _flash_flower_market_tip() -> void:
	if _title:
		_title.text = "花石坊市"
		_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.48))
		_title.modulate = Color(1.45, 1.25, 0.78)
	# Stone badge punch — same family as hub `_flash_shoudao_spend_gold`.
	if _stones:
		_stones.text = "石 %d" % GameState.spirit_stones
		_stones.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		_stones.modulate = Color(1.55, 1.3, 0.8)
		_stones.pivot_offset = _stones.size * 0.5
		_stones.scale = Vector2(0.88, 0.88)
		var stw := create_tween()
		stw.tween_property(_stones, "scale", Vector2(1.16, 1.16), 0.1).set_trans(Tween.TRANS_BACK)
		stw.tween_property(_stones, "scale", Vector2.ONE, 0.16)
		stw.parallel().tween_property(_stones, "modulate", Color.WHITE, 0.55)
	if _status:
		_status.text = "花石到手 · 可买"
		_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		_status.modulate = Color(1.4, 1.2, 0.78)
	if _hint:
		_hint.text = "花石到手 · 买入可开战"
		_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		_hint.modulate = Color(1.35, 1.18, 0.8)
	var tip := get_node_or_null("FlowerTip") as Label
	if tip == null:
		tip = Label.new()
		tip.name = "FlowerTip"
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.position = Vector2(230, 4)
		tip.size = Vector2(200, 28)
		tip.add_theme_font_size_override("font_size", 15)
		add_child(tip)
	tip.visible = true
	# Mirror hub toast — 收刀到手 · 花石 → 花石到手 · 坊市.
	tip.text = "花石到手 · 坊市"
	tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48))
	tip.modulate = Color(1.55, 1.3, 0.78, 1.0)
	tip.scale = Vector2(0.82, 0.82)
	tip.pivot_offset = tip.size * 0.5
	# Soft gold rim on bag panel — spend-loop echo without a second card.
	var bag := get_node_or_null("Panel/Body/BagPanel") as PanelContainer
	var bag_flat: StyleBoxFlat = null
	if bag:
		var sb := bag.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			bag_flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			bag.add_theme_stylebox_override("panel", bag_flat)
			bag_flat.border_color = Color(1.0, 0.86, 0.4, 1.0)
			bag_flat.set_border_width_all(2)
		bag.modulate = Color(1.28, 1.12, 0.82)
	var tw := create_tween()
	tw.tween_property(tip, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(tip, "scale", Vector2.ONE, 0.14)
	if _title:
		tw.parallel().tween_property(_title, "modulate", Color.WHITE, 0.4)
	if bag:
		tw.parallel().tween_property(bag, "modulate", Color.WHITE, 0.45)
	if bag_flat:
		tw.parallel().tween_method(
			func(a: float) -> void:
				if bag_flat:
					bag_flat.border_color = Color(1.0, 0.86, 0.4, 1.0).lerp(Color(0.55, 0.78, 0.88, 0.75), a)
					bag_flat.set_border_width_all(2 if a < 0.6 else 1),
			0.0,
			1.0,
			0.5
		)
	tw.tween_interval(1.0)
	tw.tween_property(tip, "modulate:a", 0.0, 0.28)
	if _status:
		tw.parallel().tween_property(_status, "modulate", Color.WHITE, 0.28)
	if _hint:
		tw.parallel().tween_property(_hint, "modulate", Color.WHITE, 0.28)
	tw.tween_callback(func() -> void:
		if tip:
			tip.visible = false
			tip.modulate = Color.WHITE
		if _title:
			_title.text = "通玄坊"
			_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
		if _status and (_status.text == "花石坊市" or _status.text.begins_with("花石到手")):
			_status.text = ""
		if _hint and (_hint.text == "花石坊市" or _hint.text.begins_with("花石到手")):
			_hint.text = "买入后可直接开战"
			_hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		if bag:
			_UiStyle.apply_panel(bag)
	)

func _process(_delta: float) -> void:
	if has_node("Hero"):
		$Hero.position.y = 36.0 + sin(Time.get_ticks_msec() * 0.0018) * 3.0
	if _fight_btn and _fight_btn.visible:
		var t := Time.get_ticks_msec() * 0.001
		if _fight_cta_hot:
			# Pill buy: louder gold-jade breath + soft scale so the eye sticks on 开战.
			var g := 1.0 + 0.12 * sin(t * 5.4)
			_fight_btn.modulate = Color(minf(g * 1.05, 1.3), minf(g * 1.08, 1.28), minf(g * 0.85, 1.1))
			var s := 1.0 + 0.04 * sin(t * 5.4)
			_fight_btn.scale = Vector2(s, s)
			_fight_btn.pivot_offset = _fight_btn.size * 0.5
		else:
			var g2 := 1.0 + 0.06 * sin(t * 4.0)
			_fight_btn.modulate = Color(g2, g2 * 0.97, g2 * 0.9)
			_fight_btn.scale = Vector2.ONE

func _on_market_trade(action: String, _item_id: String, _qty: int, _price: int) -> void:
	_refresh_all()
	if action == "buy":
		_update_fight_cta()

func _refresh_all() -> void:
	_refresh_header()
	_build_listings()
	_build_bag()
	_populate_sell_items()
	_update_fight_cta()

func _refresh_header() -> void:
	_stones.text = "石 %d" % GameState.spirit_stones
	_stones.add_theme_color_override(
		"font_color",
		Color(1.0, 0.9, 0.5) if GameState.spirit_stones > 0 else Color(0.7, 0.68, 0.55)
	)

func _build_listings() -> void:
	while _list.get_child_count() > 0:
		var c := _list.get_child(0)
		_list.remove_child(c)
		c.free()
	for raw in MarketService.all_listings():
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		_list.add_child(_make_listing_row(raw))

func _make_listing_row(row: Dictionary) -> Control:
	var item_id := str(row.get("item_id", ""))
	var item := ContentDB.get_item(item_id)
	var name := item.display_name if item else item_id
	var qty := int(row.get("qty", 1))
	var price := int(row.get("price", 0))
	var listing_id := str(row.get("id", ""))
	var can_buy := GameState.spirit_stones >= price and price > 0

	var panel := PanelContainer.new()
	_UiStyle.apply_panel(panel, Color(0.85, 0.75, 0.4, 0.55) if can_buy else Color(0.55, 0.78, 0.88, 0.45))
	var h := HBoxContainer.new()
	panel.add_child(h)

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "%s ×%d · %d石" % [name, qty, price]
	if item:
		info.add_theme_color_override("font_color", LootService.rarity_color(item.rarity))
		info.add_theme_font_size_override("font_size", 11)
	h.add_child(info)

	var btn := Button.new()
	btn.text = "购买" if can_buy else "不足"
	btn.disabled = not can_buy
	if can_buy:
		_UiStyle.apply_primary_button(btn)
	else:
		_UiStyle.apply_button(btn)
	btn.pressed.connect(func() -> void: _on_buy(listing_id))
	h.add_child(btn)
	return panel

const _JADE := Color(0.45, 0.98, 0.7)  # Same as combat 服丹 float / heal rings.

func _on_buy(listing_id: String) -> void:
	var result := MarketService.buy_listing(listing_id)
	if bool(result.get("ok", false)):
		var item := ContentDB.get_item(str(result.get("item_id", "")))
		var n := item.display_name if item else str(result.get("item_id", ""))
		var qty := int(result.get("qty", 1))
		var price := int(result.get("price", 0))
		var heal := int(item.qi_restore) * qty if item else 0
		var is_pill := item != null and (item.kind == "pill" or item.qi_restore > 0)
		_last_buy_name = n
		_last_buy_was_pill = is_pill
		_bought_this_visit = true
		if is_pill:
			# Mirror HUD「服丹 +N」so buy reads as ready-to-use heal.
			_status.text = "服丹 +%d · 点开战试" % heal if heal > 0 else "丹入囊 · 点开战试"
			_status.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55))
		else:
			_status.text = "购入 %s×%d · 余石 %d" % [n, qty, GameState.spirit_stones]
			_status.add_theme_color_override("font_color", Color(0.85, 0.95, 0.65))
		_celebrate_buy(n, qty, price, is_pill, heal)
		_update_fight_cta()
		_flash_stones(is_pill)
		if is_pill:
			_flash_bag_jade()
			_punch_fight_cta()
	else:
		var reason := str(result.get("reason", ""))
		if reason == "no_money":
			_status.text = "灵石不足 · 需 %d" % int(result.get("need", 0))
		else:
			_status.text = "失败"
		_status.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))

func _celebrate_buy(name: String, qty: int, price: int, is_pill: bool = false, heal: int = 0) -> void:
	# Instant dopamine on the stall — pills reuse 服丹 jade copy + dual rings.
	if _hint:
		if is_pill:
			_hint.text = "丹到手 · 点开战去试"
			_hint.add_theme_color_override("font_color", Color(1.0, 0.94, 0.6))
		else:
			_hint.text = "装好了 · 去战场试试"
			_hint.add_theme_color_override("font_color", Color(0.85, 0.95, 0.7))
	var gold := Color(1.0, 0.92, 0.55)
	var pop := Label.new()
	if is_pill:
		pop.text = "服丹 +%d" % heal if heal > 0 else "丹×%d" % qty
		pop.add_theme_font_size_override("font_size", 18)
		pop.add_theme_color_override("font_color", _JADE)
	else:
		pop.text = "+%s×%d  -%d石" % [name, qty, price]
		pop.add_theme_font_size_override("font_size", 14)
		pop.add_theme_color_override("font_color", gold)
	pop.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	pop.add_theme_constant_override("shadow_offset_x", 1)
	pop.add_theme_constant_override("shadow_offset_y", 1)
	pop.position = Vector2(196, 36)
	pop.pivot_offset = Vector2(48, 10)
	add_child(pop)
	pop.modulate = Color(1.12, 1.28, 1.12) if is_pill else Color.WHITE
	pop.scale = Vector2(0.78, 0.78)
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.22, 1.22), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(pop, "position:y", pop.position.y - 34.0, 0.58)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.58).set_delay(0.14)
	tw.tween_callback(pop.queue_free)
	if is_pill:
		# Second beat — name×qty under the heal number (combat shows +N only).
		var tip := Label.new()
		tip.text = "%s×%d · I" % [name, qty]
		tip.add_theme_font_size_override("font_size", 12)
		tip.add_theme_color_override("font_color", Color(0.55, 1.0, 0.82))
		tip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		tip.add_theme_constant_override("shadow_offset_x", 1)
		tip.add_theme_constant_override("shadow_offset_y", 1)
		tip.position = Vector2(210, 58)
		tip.pivot_offset = Vector2(28, 8)
		add_child(tip)
		tip.scale = Vector2(0.75, 0.75)
		var tw2 := create_tween()
		tw2.tween_property(tip, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
		tw2.tween_property(tip, "position:y", tip.position.y - 20.0, 0.48)
		tw2.parallel().tween_property(tip, "modulate:a", 0.0, 0.48).set_delay(0.12)
		tw2.tween_callback(tip.queue_free)
		_spawn_pill_buy_ring(Vector2(268, 52))

func _spawn_pill_buy_ring(center: Vector2) -> void:
	# Dual Line2D rings — same silhouette language as player._spawn_pill_heal_fx.
	for ring_i in 2:
		var ring := Line2D.new()
		ring.width = 2.4 - float(ring_i) * 0.4
		ring.default_color = Color(0.35, 0.95, 0.68, 0.85 - float(ring_i) * 0.2)
		ring.z_index = 8
		var r0 := 10.0 + float(ring_i) * 5.0
		for i in 25:
			var a := TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(a), sin(a)) * r0)
		add_child(ring)
		ring.position = center
		var delay := float(ring_i) * 0.04
		var tw := ring.create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
		tw.tween_callback(ring.queue_free)

func _flash_bag_jade() -> void:
	# Bag panel pulses jade so 「入囊」is felt, not only the float number.
	var bag_panel: Control = get_node_or_null("Panel/Body/BagPanel") as Control
	if bag_panel == null:
		return
	bag_panel.modulate = Color(0.75, 1.35, 1.05)
	var tw := create_tween()
	tw.tween_property(bag_panel, "modulate", Color.WHITE, 0.42)

func _flash_stones(is_pill: bool = false) -> void:
	_stones.modulate = Color(0.7, 1.35, 1.05) if is_pill else Color(1.4, 1.2, 0.7)
	var tw := create_tween()
	tw.tween_property(_stones, "modulate", Color.WHITE, 0.35)

func _update_fight_cta() -> void:
	if _fight_btn == null:
		return
	var stage := _recommended_stage()
	if _bought_this_visit and stage != null:
		_fight_btn.visible = true
		_fight_cta_hot = _last_buy_was_pill
		if _last_buy_was_pill:
			_fight_btn.text = "开战试丹 · %s" % stage.display_name
			_fight_btn.tooltip_text = "丹已入手 · 开战按 I 服"
			_style_pill_fight_cta()
		else:
			_fight_btn.text = "开战 · %s" % stage.display_name
			_fight_btn.tooltip_text = "带着新货去挑战"
			_UiStyle.apply_cta_button(_fight_btn)
			_fight_btn.custom_minimum_size = Vector2(0, 34)
		_dim_hub_for_fight(_last_buy_was_pill)
	elif stage != null and GameState.spirit_stones < 18:
		# Broke after shopping — nudge back to combat to earn.
		_fight_cta_hot = false
		_fight_btn.visible = true
		_fight_btn.text = "去攒石 · %s" % stage.display_name
		_UiStyle.apply_primary_button(_fight_btn)
		_fight_btn.custom_minimum_size = Vector2(0, 34)
		_dim_hub_for_fight(false)
	else:
		_fight_cta_hot = false
		_fight_btn.visible = _bought_this_visit
		if _fight_btn.visible and stage:
			_fight_btn.text = "开战 · %s" % stage.display_name
		_dim_hub_for_fight(false)

func _style_pill_fight_cta() -> void:
	# Jade-gold hero — closes buy→fight loop louder than a normal CTA.
	_UiStyle.apply_cta_button(_fight_btn)
	_fight_btn.custom_minimum_size = Vector2(0, 40)
	_fight_btn.add_theme_font_size_override("font_size", 16)
	_fight_btn.add_theme_color_override("font_color", Color(0.95, 1.0, 0.82))
	_fight_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.92))
	var n := _UiStyle.button_normal()
	n.bg_color = Color(0.14, 0.32, 0.28, 0.98)
	n.border_color = Color(0.55, 0.95, 0.72, 1.0)
	n.set_border_width_all(3)
	n.set_corner_radius_all(5)
	n.content_margin_left = 16
	n.content_margin_right = 16
	n.content_margin_top = 9
	n.content_margin_bottom = 9
	var h := _UiStyle.button_hover()
	h.bg_color = Color(0.2, 0.4, 0.34, 1.0)
	h.border_color = Color(1.0, 0.94, 0.55, 1.0)
	h.set_border_width_all(3)
	h.set_corner_radius_all(5)
	h.content_margin_left = 16
	h.content_margin_right = 16
	h.content_margin_top = 9
	h.content_margin_bottom = 9
	_fight_btn.add_theme_stylebox_override("normal", n)
	_fight_btn.add_theme_stylebox_override("hover", h)
	_fight_btn.add_theme_stylebox_override("pressed", h)

func _dim_hub_for_fight(hot: bool) -> void:
	if _hub_btn == null:
		return
	if hot:
		_hub_btn.modulate = Color(0.7, 0.74, 0.78, 0.75)
		_hub_btn.add_theme_font_size_override("font_size", 11)
	else:
		_hub_btn.modulate = Color.WHITE
		_hub_btn.add_theme_font_size_override("font_size", 12)

func _punch_fight_cta() -> void:
	if _fight_btn == null or not _fight_btn.visible:
		return
	_fight_btn.grab_focus()
	_fight_btn.pivot_offset = _fight_btn.size * 0.5
	_fight_btn.scale = Vector2(0.82, 0.82)
	var tw := create_tween()
	tw.tween_property(_fight_btn, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_fight_btn, "scale", Vector2.ONE, 0.14)
	if _hint:
		_hint.modulate = Color(1.25, 1.15, 0.85)
		var htw := create_tween()
		htw.tween_property(_hint, "modulate", Color.WHITE, 0.45)

func _recommended_stage() -> StageDef:
	var best: StageDef = null
	for stage in ContentDB.stages.all_stages():
		if stage == null or not GameState.can_enter(stage):
			continue
		if best == null or stage.order > best.order:
			best = stage
	return best

func _build_bag() -> void:
	while _bag.get_child_count() > 0:
		var c := _bag.get_child(0)
		_bag.remove_child(c)
		c.free()
	var counts := GameState.inventory.all_counts()
	if counts.is_empty():
		var empty := Label.new()
		empty.text = "背包为空"
		_bag.add_child(empty)
		return
	for item_id in counts.keys():
		var item := ContentDB.get_item(str(item_id))
		var name := item.display_name if item else str(item_id)
		var qty := int(counts[item_id])
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s ×%d" % [name, qty]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item:
			lbl.add_theme_color_override("font_color", LootService.rarity_color(item.rarity))
			lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)
		if item and item.tradeable:
			var sell_btn := Button.new()
			sell_btn.text = "回收"
			_UiStyle.apply_button(sell_btn)
			sell_btn.pressed.connect(func() -> void: _on_quick_sell(str(item_id), 1))
			row.add_child(sell_btn)
		var wrap := PanelContainer.new()
		_UiStyle.apply_panel(wrap, Color(0.55, 0.78, 0.88, 0.3))
		wrap.add_child(row)
		_bag.add_child(wrap)

func _populate_sell_items() -> void:
	_sell_item.clear()
	for item_id in GameState.inventory.all_counts().keys():
		var item := ContentDB.get_item(str(item_id))
		if item and item.tradeable:
			_sell_item.add_item(item.display_name, _sell_item.item_count)
			_sell_item.set_item_metadata(_sell_item.item_count - 1, str(item_id))
	_sell_qty.min_value = 1
	_sell_qty.max_value = 99
	_sell_price.min_value = 1
	_sell_price.max_value = 99999
	_sell_price.value = 50

func _on_quick_sell(item_id: String, qty: int) -> void:
	var result := MarketService.sell_to_npc(item_id, qty)
	if bool(result.get("ok", false)):
		_status.text = "回收得 %d 灵石" % int(result.get("payout", 0))
		_status.add_theme_color_override("font_color", Color(0.85, 0.95, 0.65))
		_flash_stones()
		_refresh_all()
	else:
		_status.text = "无法回收"

func _on_list_pressed() -> void:
	if _sell_item.item_count <= 0:
		_status.text = "没有可上架物品"
		return
	var idx := _sell_item.selected
	var item_id := str(_sell_item.get_item_metadata(idx))
	var qty := int(_sell_qty.value)
	var price := int(_sell_price.value)
	var result := MarketService.list_item(item_id, qty, price)
	if bool(result.get("ok", false)):
		_status.text = "已上架"
		_refresh_all()
	else:
		_status.text = "上架失败"

func _on_fight_pressed() -> void:
	var stage := _recommended_stage()
	if stage:
		SceneManager.go_combat(stage.id)
	else:
		SceneManager.go_stage_select()

func _on_back_pressed() -> void:
	SceneManager.go_hub()
