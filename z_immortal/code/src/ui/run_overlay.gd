extends CanvasLayer

## Slim combat ceremony: start + clear result only (no wave modal).

enum Kind { NONE, START, RESULT }

const _UiStyle := preload("res://src/ui/ui_style.gd")

var _kind: int = Kind.NONE
var _root: Control
var _panel: PanelContainer
var _title: Label
var _desc: Label
var _buttons: VBoxContainer

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	dim.color = Color(0.02, 0.03, 0.06, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -150
	_panel.offset_top = -78
	_panel.offset_right = 150
	_panel.offset_bottom = 78
	_UiStyle.apply_panel(_panel, Color(0.55, 0.78, 0.88, 0.8))
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.92, 0.97, 0.98))
	v.add_child(_title)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(250, 24)
	_desc.add_theme_font_size_override("font_size", 11)
	_desc.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9))
	v.add_child(_desc)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
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
	var accent := Color.from_string(stage.accent, Color(0.55, 0.78, 0.88))
	_UiStyle.apply_panel(_panel, Color(accent.r, accent.g, accent.b, 0.85))
	_title.add_theme_color_override("font_color", accent.lightened(0.25))
	_open_panel(stage.display_name, "击杀 %d" % stage.kill_target, [["开战", _close]])
	# Soft panel pop.
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size * 0.5
	var pop := create_tween()
	pop.tween_property(_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	get_tree().create_timer(1.15, true).timeout.connect(func() -> void:
		if _kind == Kind.START:
			_close()
	)

func _show_result(stage_id: String, stones: int) -> void:
	if DisplayServer.get_name() == "headless":
		_close()
		return
	var stage := ContentDB.get_stage(stage_id)
	var name := stage.display_name if stage else stage_id
	var desc := ""
	if stones >= 0:
		desc = "+%d 灵石" % stones
	_kind = Kind.RESULT
	var actions: Array = [["选关", _leave]]
	if stage and not stage.next_id.is_empty():
		var nxt := ContentDB.get_stage(stage.next_id)
		if nxt and GameState.can_enter(nxt):
			var nid := nxt.id
			actions.append(["下一层", func() -> void: SceneManager.go_combat(nid)])
	actions.append(["留下", _close])
	_open_panel("%s" % name, ("通关 · " + desc) if not desc.is_empty() else "通关", actions)

func _open_panel(title: String, desc: String, actions: Array) -> void:
	visible = true
	_title.text = title
	_desc.text = desc
	_desc.visible = not desc.is_empty()
	_clear_buttons()
	for raw in actions:
		if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 26)
		b.text = str(raw[0])
		if str(raw[0]) in ["下一层", "开战"]:
			_UiStyle.apply_primary_button(b)
		else:
			_UiStyle.apply_button(b)
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
