extends Control

## Game-like stage select: left map list, right full preview + fight CTA.

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _list: VBoxContainer = $Root/LeftPanel/LeftVBox/Scroll/List
@onready var _detail_title: Label = $Root/DetailTitle
@onready var _detail_stats: Label = $Root/DetailStats
@onready var _thumb: TextureRect = $Root/MapPreview
@onready var _enter_btn: Button = $Root/EnterButton
@onready var _hint: Label = $Root/LeftPanel/LeftVBox/Hint
@onready var _left_panel: PanelContainer = $Root/LeftPanel

var _selected_id: String = ""

func _process(_delta: float) -> void:
	if _enter_btn == null:
		return
	var t := Time.get_ticks_msec() * 0.002
	if not _enter_btn.disabled:
		var g := 1.0 + 0.04 * sin(t)
		_enter_btn.modulate = Color(g, g * 0.96, g * 0.88)
	else:
		_enter_btn.modulate = Color(0.55, 0.55, 0.58)

func _ready() -> void:
	_UiStyle.apply_panel(_left_panel)
	if has_node("Root/MapFrame"):
		_UiStyle.apply_panel($Root/MapFrame, Color(0.55, 0.78, 0.88, 0.45))
	_UiStyle.apply_primary_button(_enter_btn)
	_UiStyle.apply_button($Root/LeftPanel/LeftVBox/Header/BackButton)
	_enter_btn.pressed.connect(_on_enter)
	_build_list()
	_hint.text = "已开至第 %d 层" % GameState.unlocked_order
	var stages := ContentDB.stages.all_stages()
	for stage in stages:
		if GameState.can_enter(stage):
			_select_stage(stage.id)
			break
	if _selected_id.is_empty() and not stages.is_empty():
		_select_stage(stages[0].id)

func _build_list() -> void:
	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.queue_free()
	for stage in ContentDB.stages.all_stages():
		_list.add_child(_make_map_button(stage))

func _make_map_button(stage: StageDef) -> Control:
	var unlocked := GameState.can_enter(stage)
	var cleared := GameState.is_stage_cleared(stage.id)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 34)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var mark := "◆" if cleared else ("○" if unlocked else "·")
	btn.text = "%s %s" % [mark, stage.display_name]
	btn.disabled = not unlocked
	btn.set_meta("stage_id", stage.id)
	btn.set_meta("accent", stage.accent)
	if unlocked:
		_UiStyle.apply_button(btn)
		btn.modulate = Color.from_string(stage.accent, Color(0.92, 0.88, 0.75))
	else:
		btn.modulate = Color(0.45, 0.45, 0.48)
	var sid := stage.id
	btn.pressed.connect(func() -> void: _select_stage(sid))
	return btn

func _select_stage(stage_id: String) -> void:
	_selected_id = stage_id
	var stage := ContentDB.get_stage(stage_id)
	if stage == null:
		return
	for child in _list.get_children():
		if not (child is Button):
			continue
		var b := child as Button
		var sid := str(b.get_meta("stage_id", ""))
		var accent := str(b.get_meta("accent", "#c0c0c0"))
		if b.disabled:
			b.modulate = Color(0.45, 0.45, 0.48)
		elif sid == stage_id:
			b.modulate = Color(1.2, 1.15, 1.0)
		else:
			b.modulate = Color.from_string(accent, Color(0.9, 0.9, 0.9))
	var unlocked := GameState.can_enter(stage)
	var cleared := GameState.is_stage_cleared(stage.id)
	_detail_title.text = stage.display_name
	_detail_title.add_theme_color_override("font_color", Color.from_string(stage.accent, Color(0.95, 0.9, 0.7)))
	var boss_name := "—"
	if not stage.boss_id.is_empty():
		var boss := ContentDB.get_enemy(stage.boss_id)
		boss_name = boss.display_name if boss else stage.boss_id
	_detail_stats.text = "目标 %d  ·  Boss %s" % [stage.kill_target, boss_name]
	var bg_path := stage.background_path()
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		_thumb.texture = load(bg_path)
		_thumb.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.38)
	else:
		_thumb.texture = null
		_thumb.modulate = Color.from_string(stage.accent, Color.GRAY)
	if unlocked:
		_enter_btn.disabled = false
		_enter_btn.text = "再战" if cleared else "开战"
	else:
		_enter_btn.disabled = true
		_enter_btn.text = "锁定"

func _on_enter() -> void:
	if _selected_id.is_empty():
		return
	var stage := ContentDB.get_stage(_selected_id)
	if stage == null or not GameState.can_enter(stage):
		return
	SceneManager.go_combat(_selected_id)

func _on_back_pressed() -> void:
	SceneManager.go_hub()
