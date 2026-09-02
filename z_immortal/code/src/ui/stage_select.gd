extends Control

@onready var _list: VBoxContainer = $Panel/Scroll/List


func _ready() -> void:
	_build_list()
	_refresh_header()


func _refresh_header() -> void:
	var hint := $Panel/Hint
	if hint == null:
		return
	var c := GameState.cultivation
	var realm := ContentDB.realms.get_realm(c.attack_realm_id)
	var realm_name := realm.display_name if realm else c.attack_realm_id
	hint.text = "宗门 → 王朝 → 荒星 → 星域 → 界域 → 混沌星海\n当前 %s · %s · 已解锁第 %d 层" % [
		GameState.realm_band_name(),
		realm_name,
		GameState.unlocked_order,
	]


func _build_list() -> void:
	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.free()
	for stage in ContentDB.stages.all_stages():
		_list.add_child(_make_card(stage))


func _make_card(stage: StageDef) -> Control:
	var unlocked := GameState.can_enter(stage)
	var cleared := GameState.is_stage_cleared(stage.id)
	var kills := int(GameState.kills.get(stage.id, 0))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 78)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.82)
	style.border_color = Color.from_string(stage.accent, Color(0.83, 0.69, 0.22))
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if not unlocked:
		style.bg_color = Color(0.06, 0.06, 0.08, 0.75)
		style.border_color = Color(0.3, 0.3, 0.32)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(72, 42)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var bg_path := stage.background_path()
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		thumb.texture = load(bg_path)
	else:
		thumb.modulate = Color.from_string(stage.accent, Color.GRAY)
	if not unlocked:
		thumb.modulate = Color(0.4, 0.4, 0.4)
	row.add_child(thumb)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)

	var title := Label.new()
	var boss_hint := ""
	if not stage.boss_id.is_empty():
		var boss := ContentDB.get_enemy(stage.boss_id)
		if boss:
			boss_hint = " · Boss:%s" % boss.display_name
	title.text = "%d. %s%s" % [stage.order, stage.display_name, boss_hint if unlocked else ""]
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82) if unlocked else Color(0.55, 0.55, 0.55))
	texts.add_child(title)

	var info := Label.new()
	if not unlocked:
		info.text = "未解锁 · 先通关上一关"
	elif cleared:
		info.text = "%s\n已通关 %d/%d" % [stage.lore if not stage.lore.is_empty() else stage.description, kills, stage.kill_target]
	elif not stage.lore.is_empty():
		info.text = "%s\n进度 %d/%d" % [stage.lore, kills, stage.kill_target]
	else:
		info.text = "%s · 进度 %d/%d" % [stage.description, kills, stage.kill_target]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	texts.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 0)
	if unlocked:
		btn.text = "进入"
		btn.pressed.connect(func() -> void: SceneManager.go_combat(stage.id))
	else:
		btn.text = "锁定"
		btn.disabled = true
	row.add_child(btn)
	return card


func _on_back_pressed() -> void:
	SceneManager.go_hub()
