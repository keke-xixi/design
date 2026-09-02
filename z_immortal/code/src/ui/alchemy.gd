extends Control

@onready var _stones: Label = $Panel/Header/Stones
@onready var _recipes: VBoxContainer = $Panel/Body/RecipeCol/RecipeList
@onready var _gacha: VBoxContainer = $Panel/Body/GachaCol/GachaList
@onready var _status: Label = $Panel/Status


func _ready() -> void:
	_refresh()
	EventBus.alchemy_crafted.connect(func(_r, _i, _q): _refresh())
	EventBus.gacha_rolled.connect(func(_p, _i, _q): _refresh())
	EventBus.item_gained.connect(func(_i, _a, _r): _refresh())


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
		var row := _make_recipe_row(raw)
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
	var out: Variant = recipe.get("output", {})
	var out_item := ContentDB.get_item(str(out.get("item_id", "")))
	var out_name := out_item.display_name if out_item else str(out.get("item_id", ""))

	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "%s（%d 灵石）" % [name, cost]
	v.add_child(title)
	var need := Label.new()
	need.add_theme_font_size_override("font_size", 10)
	need.text = "材料：%s → %s×%d" % [", ".join(inputs), out_name, int(out.get("qty", 1))]
	v.add_child(need)
	var btn := Button.new()
	btn.text = "炼制"
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
		var h := HBoxContainer.new()
		panel.add_child(h)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s — %d 灵石" % [name, cost]
		h.add_child(lbl)
		var btn := Button.new()
		btn.text = "抽取"
		btn.pressed.connect(func() -> void: _pull(id))
		h.add_child(btn)
		_gacha.add_child(panel)


func _craft(recipe_id: String) -> void:
	var result := AlchemyService.craft(recipe_id)
	if bool(result.get("ok", false)):
		_status.text = "炼成 %s ×%d" % [result.get("item_id", ""), int(result.get("qty", 1))]
	else:
		_status.text = _fail_text(result)
	_refresh()


func _pull(pool_id: String) -> void:
	var result := AlchemyService.gacha_pull(pool_id)
	if bool(result.get("ok", false)):
		_status.text = "抽中 %s ×%d" % [result.get("item_id", ""), int(result.get("qty", 1))]
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
