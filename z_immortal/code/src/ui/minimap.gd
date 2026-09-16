extends Control

## Top-right minimap: player, mobs, obstacles, zones, map bounds.

var _map_size := Vector2(768, 480)
var _obstacles: Array = []
var _zones: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(108, 68)
	EventBus.map_layout_updated.connect(_on_map_layout)
	EventBus.stage_changed.connect(func(_id): queue_redraw())

func _on_map_layout(map_size: Vector2, obstacles: Array, zones: Array = []) -> void:
	_map_size = map_size
	_obstacles = obstacles
	_zones = zones
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pad := 3.0
	var outer := Rect2(0, 0, size.x, size.y)
	draw_rect(outer, Color(0.04, 0.06, 0.09, 0.82))
	draw_rect(outer, Color(0.55, 0.78, 0.88, 0.5), false, 1.0)
	var inner := Rect2(pad, pad, size.x - pad * 2.0, size.y - pad * 2.0)
	draw_rect(inner, Color(0.05, 0.07, 0.1, 0.55))
	if _map_size.x <= 0.0 or _map_size.y <= 0.0:
		return
	var sx := inner.size.x / _map_size.x
	var sy := inner.size.y / _map_size.y
	for raw in _zones:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var c: Vector2 = raw.get("center", Vector2.ZERO)
		var r: float = float(raw.get("radius", 8.0))
		var effect := str(raw.get("effect", ""))
		var col := Color(0.7, 0.8, 0.9, 0.25)
		match effect:
			"heal":
				col = Color(0.35, 0.9, 0.55, 0.35)
			"slow":
				col = Color(0.95, 0.8, 0.35, 0.32)
			"damage":
				col = Color(0.95, 0.4, 0.35, 0.35)
		var cp := _world_to_mini(c, inner, sx, sy)
		var rr := maxf(r * minf(sx, sy), 2.5)
		draw_circle(cp, rr, col)
		draw_arc(cp, rr, 0.0, TAU, 16, Color(col.r, col.g, col.b, 0.7), 1.0)
	for raw in _obstacles:
		if raw is Rect2:
			var r: Rect2 = raw
			var mini := Rect2(
				inner.position.x + r.position.x * sx,
				inner.position.y + r.position.y * sy,
				maxi(r.size.x * sx, 1.5),
				maxi(r.size.y * sy, 1.5),
			)
			draw_rect(mini, Color(0.28, 0.24, 0.2, 0.9))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var pp := _world_to_mini(player.global_position, inner, sx, sy)
		draw_circle(pp, 3.2, Color(0.45, 0.95, 0.85))
		draw_arc(pp, 5.0, 0.0, TAU, 12, Color(0.45, 0.95, 0.85, 0.35), 1.0)
	for node in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var mp := _world_to_mini((node as Node2D).global_position, inner, sx, sy)
		var mob_node: Node = node
		var is_boss := false
		var is_elite := false
		if mob_node.get("def") != null:
			var enemy_def: Variant = mob_node.get("def")
			if enemy_def != null:
				is_boss = bool(enemy_def.is_boss)
		if mob_node.get("is_elite") != null:
			is_elite = bool(mob_node.get("is_elite"))
		if is_boss:
			draw_circle(mp, 3.5, Color(1.0, 0.45, 0.4))
		elif is_elite:
			draw_circle(mp, 2.4, Color(1.0, 0.85, 0.35))
		else:
			draw_circle(mp, 2.0, Color(0.95, 0.55, 0.45))
	for node in get_tree().get_nodes_in_group("chests"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var cp2 := _world_to_mini((node as Node2D).global_position, inner, sx, sy)
		draw_rect(Rect2(cp2.x - 2, cp2.y - 2, 4, 4), Color(0.95, 0.82, 0.35))

func _world_to_mini(pos: Vector2, inner: Rect2, sx: float, sy: float) -> Vector2:
	return Vector2(inner.position.x + pos.x * sx, inner.position.y + pos.y * sy)
