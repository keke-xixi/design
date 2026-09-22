extends Control

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _title: Label = $Panel/Header/Title
@onready var _stones: Label = $Panel/Header/Stones
@onready var _recipes: VBoxContainer = $Panel/Body/RecipeCol/RecipeList
@onready var _gacha: VBoxContainer = $Panel/Body/GachaCol/GachaList
@onready var _status: Label = $Panel/Status

func _ready() -> void:
	_UiStyle.apply_button($Panel/Header/BackButton)
	_refresh()
	EventBus.alchemy_crafted.connect(func(_r, _i, _q): _refresh())
	EventBus.gacha_rolled.connect(func(_p, _i, _q): _refresh())
	EventBus.item_gained.connect(func(_i, _a, _r): _refresh())
	if GameState.alchemy_flower_enter:
		GameState.alchemy_flower_enter = false
		call_deferred("_flash_flower_alchemy_tip")

## Hub「炼丹 · 花」entry → warm-gold tip aligned with market「花石到手 · 坊市」。
func _flash_flower_alchemy_tip() -> void:
	if _title:
		_title.text = "花石炼丹"
		_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.48))
		_title.modulate = Color(1.45, 1.25, 0.78)
	# Stone badge punch — same family as market `_flash_flower_market_tip`.
	if _stones:
		_stones.text = "灵石 %d" % GameState.spirit_stones
		_stones.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		_stones.modulate = Color(1.55, 1.3, 0.8)
		_stones.pivot_offset = _stones.size * 0.5
		_stones.scale = Vector2(0.88, 0.88)
		var stw := create_tween()
		stw.tween_property(_stones, "scale", Vector2(1.16, 1.16), 0.1).set_trans(Tween.TRANS_BACK)
		stw.tween_property(_stones, "scale", Vector2.ONE, 0.16)
		stw.parallel().tween_property(_stones, "modulate", Color.WHITE, 0.55)
	if _status:
		_status.text = "花石到手 · 可炼"
		_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		_status.modulate = Color(1.4, 1.2, 0.78)
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
	# Mirror market toast — 花石到手 · 坊市 → 花石到手 · 炼丹.
	tip.text = "花石到手 · 炼丹"
	tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.48))
	tip.modulate = Color(1.55, 1.3, 0.78, 1.0)
	tip.scale = Vector2(0.82, 0.82)
	tip.pivot_offset = tip.size * 0.5
	# Soft gold rim on first recipe card — spend-loop echo (no BagPanel here).
	var recipe_col := get_node_or_null("Panel/Body/RecipeCol") as Control
	var recipe_panel: PanelContainer = null
	var recipe_flat: StyleBoxFlat = null
	if _recipes and _recipes.get_child_count() > 0:
		recipe_panel = _recipes.get_child(0) as PanelContainer
	if recipe_panel:
		var sb := recipe_panel.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			recipe_flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			recipe_panel.add_theme_stylebox_override("panel", recipe_flat)
			recipe_flat.border_color = Color(1.0, 0.86, 0.4, 1.0)
			recipe_flat.set_border_width_all(2)
		recipe_panel.modulate = Color(1.28, 1.12, 0.82)
	elif recipe_col:
		recipe_col.modulate = Color(1.28, 1.12, 0.82)
	var tw := create_tween()
	tw.tween_property(tip, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(tip, "scale", Vector2.ONE, 0.14)
	if _title:
		tw.parallel().tween_property(_title, "modulate", Color.WHITE, 0.4)
	if recipe_panel:
		tw.parallel().tween_property(recipe_panel, "modulate", Color.WHITE, 0.45)
	elif recipe_col:
		tw.parallel().tween_property(recipe_col, "modulate", Color.WHITE, 0.45)
	if recipe_flat:
		tw.parallel().tween_method(
			func(a: float) -> void:
				if recipe_flat:
					recipe_flat.border_color = Color(1.0, 0.86, 0.4, 1.0).lerp(Color(0.55, 0.78, 0.88, 0.75), a)
					recipe_flat.set_border_width_all(2 if a < 0.6 else 1),
			0.0,
			1.0,
			0.5
		)
	tw.tween_interval(1.0)
	tw.tween_property(tip, "modulate:a", 0.0, 0.28)
	if _status:
		tw.parallel().tween_property(_status, "modulate", Color.WHITE, 0.28)
	tw.tween_callback(func() -> void:
		if tip:
			tip.visible = false
			tip.modulate = Color.WHITE
		if _title:
			_title.text = "炼丹"
			_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
		if _status and (_status.text == "花石炼丹" or _status.text.begins_with("花石到手")):
			_status.text = ""
		if recipe_panel:
			_UiStyle.apply_panel(recipe_panel)
			recipe_panel.modulate = Color.WHITE
		elif recipe_col:
			recipe_col.modulate = Color.WHITE
	)

func _process(_delta: float) -> void:
	if has_node("Hero"):
		$Hero.position.y = 36.0 + sin(Time.get_ticks_msec() * 0.0018) * 3.0

func _refresh() -> void:
	_stones.text = "灵石 %d" % GameState.spirit_stones
	_build_recipes()
	_build_gacha()

func _build_recipes() -> void:
	while _recipes.get_child_count() > 0:
		var c := _recipes.get_child(0)
		_recipes.remove_child(c)
		c.free()
	for raw in ContentDB.alchemy_recipes():
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Control = _make_recipe_row(raw as Dictionary)
		_recipes.add_child(row)

func _make_recipe_row(recipe: Dictionary) -> Control:
	var id := str(recipe.get("id", ""))
	var name := str(recipe.get("name", id))
	var cost := int(recipe.get("cost_stones", 0))
	var inputs: PackedStringArray = []
	for raw in recipe.get("inputs", []):
		if typeof(raw) == TYPE_DICTIONARY:
			var item := ContentDB.get_item(str(raw.get("item_id", "")))
			var n := item.display_name if item else str(raw.get("item_id", ""))
			inputs.append("%s×%d" % [n, int(raw.get("qty", 1))])
	var out_raw: Variant = recipe.get("output", {})
	if typeof(out_raw) != TYPE_DICTIONARY:
		out_raw = {}
	var out: Dictionary = out_raw
	var out_item: ItemDef = ContentDB.get_item(str(out.get("item_id", "")))
	var out_name := out_item.display_name if out_item else str(out.get("item_id", ""))

	var panel := PanelContainer.new()
	_UiStyle.apply_panel(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "%s · %d石" % [name, cost]
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98))
	v.add_child(title)
	var need := Label.new()
	need.add_theme_font_size_override("font_size", 10)
	need.text = "%s → %s" % [", ".join(inputs), out_name]
	v.add_child(need)
	var btn := Button.new()
	btn.text = "炼制"
	_UiStyle.apply_button(btn)
	btn.pressed.connect(func() -> void: _craft(id))
	v.add_child(btn)
	return panel

func _build_gacha() -> void:
	while _gacha.get_child_count() > 0:
		var c := _gacha.get_child(0)
		_gacha.remove_child(c)
		c.free()
	for raw in ContentDB.alchemy_gacha_pools():
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var id := str(raw.get("id", ""))
		var name := str(raw.get("name", id))
		var cost := int(raw.get("cost_stones", 10))
		var panel := PanelContainer.new()
		_UiStyle.apply_panel(panel)
		var h := HBoxContainer.new()
		panel.add_child(h)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s · %d石" % [name, cost]
		lbl.add_theme_color_override("font_color", Color(0.9, 0.94, 0.96))
		h.add_child(lbl)
		var btn := Button.new()
		btn.text = "抽取"
		_UiStyle.apply_button(btn)
		btn.pressed.connect(func() -> void: _pull(id))
		h.add_child(btn)
		_gacha.add_child(panel)

func _craft(recipe_id: String) -> void:
	var result := AlchemyService.craft(recipe_id)
	if bool(result.get("ok", false)):
		var item := ContentDB.get_item(str(result.get("item_id", "")))
		var n := item.display_name if item else str(result.get("item_id", ""))
		_status.text = "炼成 %s ×%d" % [n, int(result.get("qty", 1))]
	else:
		_status.text = _fail_text(result)
	_refresh()

func _pull(pool_id: String) -> void:
	var result := AlchemyService.gacha_pull(pool_id)
	if bool(result.get("ok", false)):
		var item := ContentDB.get_item(str(result.get("item_id", "")))
		var n := item.display_name if item else str(result.get("item_id", ""))
		_status.text = "抽中 %s ×%d" % [n, int(result.get("qty", 1))]
	else:
		_status.text = _fail_text(result)
	_refresh()

func _fail_text(result: Dictionary) -> String:
	match str(result.get("reason", "")):
		"no_money":
			return "灵石不足，需要 %d" % int(result.get("need", 0))
		"no_material":
			return "材料不足"
		_:
			return "失败"

func _on_back_pressed() -> void:
	SceneManager.go_hub()
