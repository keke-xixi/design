extends Control

@onready var _list: VBoxContainer = $Panel/Scroll/List


func _ready() -> void:
	_build_list()


func _build_list() -> void:
	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.free()
	for stage in ContentDB.stages.all_stages():
		_list.add_child(_make_row(stage))


func _make_row(stage: StageDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var unlocked := GameState.can_enter(stage)
	var cleared := GameState.is_stage_cleared(stage.id)
	var kills := int(GameState.kills.get(stage.id, 0))
	var title := Label.new()
	title.text = "%d. %s" % [stage.order, stage.display_name]
	title.add_theme_font_size_override("font_size", 16)
	if not unlocked:
		title.modulate = Color(0.55, 0.55, 0.55)
	row.add_child(title)
	var info := Label.new()
	var desc := stage.description
	if not desc.is_empty():
		info.text = desc
	elif not unlocked:
		info.text = "未解锁"
	elif cleared:
		info.text = "已通关  %d/%d" % [kills, stage.kill_target]
	else:
		info.text = "进度  %d/%d" % [kills, stage.kill_target]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(info)
	var btn := Button.new()
	if unlocked:
		btn.text = "进入"
		btn.pressed.connect(func() -> void: SceneManager.go_combat(stage.id))
	else:
		btn.text = "锁定"
		btn.disabled = true
	row.add_child(btn)
	return row


func _on_back_pressed() -> void:
	SceneManager.go_hub()
