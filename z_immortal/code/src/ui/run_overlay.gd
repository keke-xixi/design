extends CanvasLayer

## Compact ceremony UI for 640x360: start + clear result.

enum Kind { NONE, START, RESULT }

var _kind: int = Kind.NONE
var _root: Control
var _panel: PanelContainer
var _title: Label
var _desc: Label
var _buttons: VBoxContainer

func _ready() -> void:
	layer = 20
	_build()
	visible = false
	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.stage_reward.connect(_on_stage_reward)
	call_deferred("_show_start")

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _kind != Kind.START:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -170
	_panel.offset_top = -90
	_panel.offset_right = 170
	_panel.offset_bottom = 90
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	v.add_child(_title)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(300, 48)
	_desc.add_theme_font_size_override("font_size", 11)
	_desc.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9))
	v.add_child(_desc)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	v.add_child(_buttons)

func _on_dim_input(event: InputEvent) -> void:
	if _kind == Kind.START and event is InputEventMouseButton and event.pressed:
		_close()

func _on_stage_cleared(stage_id: String) -> void:
	call_deferred("_show_result", stage_id, -1)

func _on_stage_reward(stones: int) -> void:
	call_deferred("_show_result", GameState.stage_id, stones)

func _show_start() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stage := GameState.current_stage()
	if stage == null:
		return
	_kind = Kind.START
	var boss_line := ""
	if not stage.boss_id.is_empty():
		var boss := ContentDB.get_enemy(stage.boss_id)
		if boss:
			boss_line = "\n守关 %s · %d 杀后降临" % [boss.display_name, stage.boss_at_kill]
	_open_panel(
		"开战 · %s" % stage.display_name,
		"击杀目标 %d%s\n点击或按确认进入" % [stage.kill_target, boss_line],
		[["踏入战场", _close]]
	)

func _show_result(stage_id: String, stones: int) -> void:
	if DisplayServer.get_name() == "headless":
		_close()
		return
	var stage := ContentDB.get_stage(stage_id)
	var name := stage.display_name if stage else stage_id
	var stone_line := ""
	if stones >= 0:
		stone_line = "灵石 +%d\n" % stones
	var next_line := "可返回选关继续。"
	if stage and not stage.next_id.is_empty():
		var nxt := ContentDB.get_stage(stage.next_id)
		if nxt and GameState.can_enter(nxt):
			next_line = "已解锁：%s" % nxt.display_name
	_kind = Kind.RESULT
	var actions: Array = [["返回选关", _leave]]
	if stage and not stage.next_id.is_empty():
		var nxt2 := ContentDB.get_stage(stage.next_id)
		if nxt2 and GameState.can_enter(nxt2):
			var nid := nxt2.id
			actions.append(["挑战下一层", func() -> void: SceneManager.go_combat(nid)])
	actions.append(["继续本关", _close])
	_open_panel("%s · 已破" % name, "%s%s" % [stone_line, next_line], actions)

func _open_panel(title: String, desc: String, actions: Array) -> void:
	visible = true
	_title.text = title
	_desc.text = desc
	_clear_buttons()
	for raw in actions:
		if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 28)
		b.text = str(raw[0])
		var cb: Callable = raw[1]
		b.pressed.connect(func() -> void:
			_close()
			cb.call()
		)
		_buttons.add_child(b)

func _clear_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()

func _close() -> void:
	_kind = Kind.NONE
	visible = false
	_clear_buttons()

func _leave() -> void:
	SceneManager.go_stage_select()
