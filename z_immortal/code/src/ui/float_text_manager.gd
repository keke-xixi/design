extends Node

## Spawns floating combat text at world positions.

const _FloatTextScene := preload("res://scenes/ui/float_text.tscn")

var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	EventBus.damage_dealt.connect(_on_damage)
	EventBus.attack_gained.connect(_on_attack)
	EventBus.cultivation_broke_through.connect(_on_breakthrough)
	EventBus.mystic_crossed.connect(_on_mystic)
	EventBus.cultivation_stat_gained.connect(_on_stat_gained)
	EventBus.combo_milestone.connect(_on_combo)
	EventBus.item_gained.connect(_on_item_gained)

func _on_item_gained(item_id: String, amount: int, rarity: String) -> void:
	# Only celebrate uncommon+ to reduce screen clutter.
	if rarity not in ["rare", "epic", "legendary"]:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var item := ContentDB.get_item(item_id)
	var name := item.display_name if item else item_id
	_spawn(player.global_position + Vector2(0, -20), "%s×%d" % [name, amount], LootService.rarity_color(rarity))

func _on_mystic() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_spawn(player.global_position + Vector2(0, -48), "通玄", Color(0.65, 0.85, 1.0))

func _on_stat_gained(stat: String, value: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var label := "智%d" % value if stat == "wisdom" else "防%d" % value
	_spawn(player.global_position + Vector2(0, -32), label, Color(0.75, 0.88, 1.0))

func _on_combo(count: int) -> void:
	# Float only on chunky milestones; HUD already shows live combo.
	if count != 3 and (count < 8 or count % 5 != 0):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_spawn(player.global_position + Vector2(0, -40), "%d连" % count, Color(1.0, 0.82, 0.45))

func _on_damage(pos: Vector2, amount: int, is_player: bool) -> void:
	if is_player:
		# Only show meaningful hits to cut clutter.
		if amount < 3:
			return
		_spawn(pos, str(amount), Color(1.0, 0.45, 0.4))
		return
	# Thin auto-attack spam: skip tiny ticks often.
	if amount < 4 and randf() > 0.45:
		return
	var color := Color(0.85, 0.95, 0.55)
	if GameState.combo >= 8:
		color = Color(1.0, 0.78, 0.35)
	elif GameState.combo >= 4:
		color = Color(0.95, 0.92, 0.55)
	_spawn(pos, str(amount), color)

func _on_attack(gain: int, _total: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_spawn(player.global_position + Vector2(0, -24), "+%d攻" % gain, Color(0.55, 0.95, 0.65))

func _on_breakthrough(realm_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var realm := ContentDB.realms.get_realm(realm_id)
	var name := realm.display_name if realm else realm_id
	_spawn(player.global_position + Vector2(0, -36), name, Color(1.0, 0.88, 0.45))

func show_message(world_pos: Vector2, text: String, color: Color) -> void:
	_spawn(world_pos, text, color)

func _spawn(world_pos: Vector2, text: String, color: Color) -> void:
	var node := _FloatTextScene.instantiate()
	_layer.add_child(node)
	if node.has_method("setup"):
		node.setup(_world_to_canvas(world_pos), text, color)

func _world_to_canvas(world_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return world_pos
	var canvas := vp.get_canvas_transform()
	return canvas * world_pos
