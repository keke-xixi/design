extends Control

## Map-select UI for 640x360: list + detail, enter always on-screen.

@onready var _list: VBoxContainer = $Root/Panel/Body/MapList/Scroll/List
@onready var _detail_title: Label = $Root/Panel/Body/Detail/Title
@onready var _detail_lore: Label = $Root/Panel/Body/Detail/Lore
@onready var _detail_stats: Label = $Root/Panel/Body/Detail/Stats
@onready var _detail_mobs: Label = $Root/Panel/Body/Detail/Mobs
@onready var _thumb: TextureRect = $Root/Panel/Body/Detail/Thumb
@onready var _enter_btn: Button = $Root/Panel/Body/Detail/EnterButton
@onready var _hint: Label = $Root/Panel/Hint

var _selected_id: String = ""

func _ready() -> void:
	_enter_btn.pressed.connect(_on_enter)
	_build_list()
	_refresh_header()
	var stages := ContentDB.stages.all_stages()
	for stage in stages:
		if GameState.can_enter(stage):
			_select_stage(stage.id)
			break
	if _selected_id.is_empty() and not stages.is_empty():
		_select_stage(stages[0].id)

func _refresh_header() -> void:
	var c := GameState.cultivation
	var realm := ContentDB.realms.get_realm(c.attack_realm_id)
	var realm_name := realm.display_name if realm else c.attack_realm_id
	_hint.text = "%s · %s · 解锁至第 %d 层" % [
		GameState.realm_band_name(),
		realm_name,
		GameState.unlocked_order,
	]

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
	btn.custom_minimum_size = Vector2(0, 28)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var mark := "◆" if cleared else ("○" if unlocked else "·")
	btn.text = "%s %s" % [mark, stage.display_name]
	btn.disabled = not unlocked
	if unlocked:
		btn.modulate = Color.from_string(stage.accent, Color(0.92, 0.88, 0.75))
	else:
		btn.modulate = Color(0.5, 0.5, 0.52)
	var sid := stage.id
	btn.pressed.connect(func() -> void: _select_stage(sid))
	return btn

func _select_stage(stage_id: String) -> void:
	_selected_id = stage_id
	var stage := ContentDB.get_stage(stage_id)
	if stage == null:
		return
	var unlocked := GameState.can_enter(stage)
	var cleared := GameState.is_stage_cleared(stage.id)
	var kills := int(GameState.kills.get(stage.id, 0))
	_detail_title.text = "%d. %s" % [stage.order, stage.display_name]
	_detail_title.add_theme_color_override("font_color", Color.from_string(stage.accent, Color(0.95, 0.9, 0.7)))
	var lore := stage.lore if not stage.lore.is_empty() else stage.description
	if lore.length() > 70:
		lore = lore.substr(0, 70) + "…"
	_detail_lore.text = lore
	var boss_name := "—"
	if not stage.boss_id.is_empty():
		var boss := ContentDB.get_enemy(stage.boss_id)
		boss_name = boss.display_name if boss else stage.boss_id
	_detail_stats.text = "目标 %d 杀  ·  进度 %d/%d\n间隔 %.2fs  ·  同屏 %d\nBoss %s @%d" % [
		stage.kill_target, kills, stage.kill_target,
		stage.spawn_interval, stage.max_alive,
		boss_name, stage.boss_at_kill,
	]
	_detail_mobs.text = _format_mobs(stage)
	var bg_path := stage.background_path()
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		_thumb.texture = load(bg_path)
		_thumb.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.38)
	else:
		_thumb.texture = null
		_thumb.modulate = Color.from_string(stage.accent, Color.GRAY)
	if unlocked:
		_enter_btn.disabled = false
		_enter_btn.text = "再次挑战" if cleared else "进入战场"
	else:
		_enter_btn.disabled = true
		_enter_btn.text = "未解锁"

func _format_mobs(stage: StageDef) -> String:
	var parts: PackedStringArray = []
	var seen: Dictionary = {}
	for raw in stage.spawns:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var eid := str(raw.get("enemy_id", ""))
		if eid.is_empty() or seen.has(eid):
			continue
		seen[eid] = true
		var enemy := ContentDB.get_enemy(eid)
		parts.append(enemy.display_name if enemy else eid)
	if not stage.boss_id.is_empty():
		var boss := ContentDB.get_enemy(stage.boss_id)
		if boss:
			parts.append("Boss·" + boss.display_name)
	return "出没：" + "、".join(parts)

func _on_enter() -> void:
	if _selected_id.is_empty():
		return
	var stage := ContentDB.get_stage(_selected_id)
	if stage == null or not GameState.can_enter(stage):
		return
	SceneManager.go_combat(_selected_id)

func _on_back_pressed() -> void:
	SceneManager.go_hub()
