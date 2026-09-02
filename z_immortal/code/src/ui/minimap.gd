extends Control

## Top-right minimap: player, mobs, obstacles, map bounds.

var _map_size := Vector2(768, 480)
var _obstacles: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(108, 68)
	EventBus.map_layout_updated.connect(_on_map_layout)
	EventBus.stage_changed.connect(func(_id): queue_redraw())


func _on_map_layout(map_size: Vector2, obstacles: Array) -> void:
	_map_size = map_size
	_obstacles = obstacles
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pad := 4.0
	var inner := Rect2(pad, pad, size.x - pad * 2.0, size.y - pad * 2.0)
	draw_rect(inner, Color(0.05, 0.07, 0.1, 0.75))
	draw_rect(inner, Color(0.35, 0.45, 0.55, 0.6), false, 1.0)
	if _map_size.x <= 0.0 or _map_size.y <= 0.0:
		return
	var sx := inner.size.x / _map_size.x
	var sy := inner.size.y / _map_size.y
	for raw in _obstacles:
		if raw is Rect2:
			var r: Rect2 = raw
			var mini := Rect2(
				inner.position.x + r.position.x * sx,
				inner.position.y + r.position.y * sy,
				r.size.x * sx,
				r.size.y * sy,
			)
			draw_rect(mini, Color(0.25, 0.22, 0.2, 0.85))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var pp := _world_to_mini(player.global_position, inner, sx, sy)
		draw_circle(pp, 3.0, Color(0.45, 0.95, 0.55))
	for node in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var mp := _world_to_mini((node as Node2D).global_position, inner, sx, sy)
		var mob_node: Node = node
		var is_boss := false
		if mob_node.get("def") != null:
			var enemy_def: Variant = mob_node.get("def")
			if enemy_def != null:
				is_boss = bool(enemy_def.is_boss)
		draw_circle(mp, 2.0 if not is_boss else 3.5, Color(1.0, 0.45, 0.4) if is_boss else Color(0.95, 0.55, 0.45))


func _world_to_mini(pos: Vector2, inner: Rect2, sx: float, sy: float) -> Vector2:
	return Vector2(inner.position.x + pos.x * sx, inner.position.y + pos.y * sy)
