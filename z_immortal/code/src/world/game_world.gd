extends Node2D



const TILE := 16

const TILE_GRASS := Vector2i(0, 0)

const TILE_DIRT := Vector2i(1, 0)

const TILE_STONE := Vector2i(2, 0)

const SOURCE_ID := 0



@onready var _bg: Sprite2D = $Background

@onready var _tiles: TileMapLayer = $TileMapLayer

@onready var _player: CharacterBody2D = $Player

@onready var _mobs: Node2D = $Mobs

@onready var _projectiles: Node2D = $Projectiles

@onready var _pickups: Node2D = $Pickups

@onready var _obstacles: Node2D = $Obstacles

@onready var _zones: Node2D = $Zones

@onready var _camera: Camera2D = $Player/Camera2D



var _map_size := Vector2i(48, 30)

var _spawn_acc := 0.0

var _bounds := Rect2()

var _obstacle_rects: Array[Rect2] = []

var _last_wave_hint := ""





func _ready() -> void:

	_pickups.add_to_group("pickups")

	EventBus.stage_changed.connect(_on_stage_changed)

	EventBus.stage_cleared.connect(_on_stage_cleared)

	EventBus.boss_spawned.connect(_on_boss_spawned)

	_apply_stage(GameState.stage_id)





func _process(delta: float) -> void:

	if GameState.dead:

		return

	GameState.run_time += delta

	var stage := GameState.current_stage()

	if stage == null:

		return

	var kills := GameState.stage_kills()

	var hint := stage.wave_hint(kills)

	if hint != _last_wave_hint and not hint.is_empty():

		_last_wave_hint = hint

		EventBus.wave_changed.emit(hint)

	_spawn_acc += delta

	var interval := stage.spawn_interval_for(kills)

	var cap := stage.max_alive_for(kills)

	if _spawn_acc >= interval and _mobs.get_child_count() < cap:

		_spawn_acc = 0.0

		_spawn_one(stage)





func _on_stage_changed(stage_id: String) -> void:

	_apply_stage(stage_id)





func _on_stage_cleared(_stage_id: String) -> void:

	var banner := get_node_or_null("HUD")

	if banner and banner.has_method("show_clear"):

		banner.show_clear()





func _on_boss_spawned(boss_id: String) -> void:

	var enemy := ContentDB.get_enemy(boss_id)

	if enemy == null:

		push_warning("Missing boss %s" % boss_id)

		return

	var mob := preload("res://scenes/world/mob.tscn").instantiate()

	_mobs.add_child(mob)

	mob.setup(enemy)

	mob.scale = Vector2(1.5, 1.5)

	var pixel := Vector2(_map_size) * float(TILE)

	mob.global_position = pixel * 0.5 + Vector2(0, -80)





func _apply_stage(stage_id: String) -> void:

	var stage := ContentDB.get_stage(stage_id)

	if stage == null:

		push_error("Unknown stage %s" % stage_id)

		return

	_clear_group_children(_mobs)

	_clear_group_children(_projectiles)

	_clear_group_children(_pickups)

	_clear_group_children(_obstacles)

	_clear_group_children(_zones)

	_spawn_acc = 0.0

	_last_wave_hint = ""

	_obstacle_rects.clear()

	var map: Dictionary = stage.map

	_map_size = Vector2i(int(map.get("width", 48)), int(map.get("height", 30)))

	var pixel := Vector2(_map_size) * float(TILE)

	_bounds = Rect2(Vector2(24, 24), pixel - Vector2(48, 48))

	_set_background(stage, pixel)

	_tiles.modulate = Color(1, 1, 1, float(map.get("tile_opacity", 0.32)))

	_tiles.tile_set = _build_tileset(map)

	_paint_map(str(map.get("pattern", "yard")))

	_build_obstacles(map)

	_build_zones(map, pixel)

	_player.position = pixel * 0.5

	_player.configure(_projectiles, _bounds)

	_camera.zoom = Vector2(1.15, 1.15)

	_camera.limit_left = 0

	_camera.limit_top = 0

	_camera.limit_right = int(pixel.x)

	_camera.limit_bottom = int(pixel.y)
	add_to_group("game_world")
	var obs_array: Array = []
	for r in _obstacle_rects:
		obs_array.append(r)
	EventBus.map_layout_updated.emit(pixel, obs_array)
	print("Stage: %s (%s)" % [stage.display_name, stage.id])





func _set_background(stage: StageDef, pixel: Vector2) -> void:

	var path := stage.background_path()

	if path.is_empty() or not ResourceLoader.exists(path):

		_bg.texture = null

		return

	var tex: Texture2D = load(path)

	_bg.texture = tex

	_bg.centered = false

	_bg.position = Vector2.ZERO

	if tex:

		_bg.scale = Vector2(pixel.x / float(tex.get_width()), pixel.y / float(tex.get_height()))

	_bg.z_index = -20





func _spawn_one(stage: StageDef) -> void:

	var wave := stage.current_wave(GameState.stage_kills())

	var pool: Array = wave.get("spawns", [])

	var enemy_id := stage._pick_from_spawns(pool) if typeof(pool) == TYPE_ARRAY and not pool.is_empty() else stage.pick_enemy_id()

	var enemy := ContentDB.get_enemy(enemy_id)

	if enemy == null:

		push_error("Stage %s missing enemy %s" % [stage.id, enemy_id])

		return

	var mob := preload("res://scenes/world/mob.tscn").instantiate()

	_mobs.add_child(mob)

	mob.setup(enemy)

	if enemy.is_boss:

		mob.scale = Vector2(1.35, 1.35)

	mob.global_position = _spawn_point()





func _spawn_point() -> Vector2:

	var cbt := ContentDB.section("combat")

	var min_r := float(cbt.get("spawn_min_radius", 150))

	var max_r := float(cbt.get("spawn_max_radius", 230))

	var pixel := Vector2(_map_size) * float(TILE)

	for _i in 12:

		var pos: Vector2 = _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(min_r, max_r)

		pos.x = clampf(pos.x, 32.0, pixel.x - 32.0)

		pos.y = clampf(pos.y, 32.0, pixel.y - 32.0)

		if pos.distance_to(_player.global_position) >= min_r * 0.6 and not _hits_obstacle(pos):

			return pos

	return Vector2(pixel.x * 0.5, 48.0)





func _hits_obstacle(pos: Vector2) -> bool:

	for rect in _obstacle_rects:

		if rect.has_point(pos):

			return true

	return false





func _build_obstacles(map: Dictionary) -> void:

	var rows: Variant = map.get("obstacles", [])

	if typeof(rows) != TYPE_ARRAY:

		return

	for raw in rows:

		if typeof(raw) != TYPE_DICTIONARY:

			continue

		var x := int(raw.get("x", 0)) * TILE

		var y := int(raw.get("y", 0)) * TILE

		var w := int(raw.get("w", 1)) * TILE

		var h := int(raw.get("h", 1)) * TILE

		var rect := Rect2(x, y, w, h)

		_obstacle_rects.append(rect)

		var body := StaticBody2D.new()

		body.collision_layer = 1

		body.collision_mask = 0

		body.position = rect.position

		var shape := CollisionShape2D.new()

		var box := RectangleShape2D.new()

		box.size = rect.size

		shape.shape = box

		shape.position = rect.size * 0.5

		body.add_child(shape)

		var visual := ColorRect.new()

		visual.size = rect.size

		visual.color = Color.from_string(str(raw.get("color", "#4a4038")), Color("4a4038")).lightened(0.1)

		visual.modulate.a = 0.85

		body.add_child(visual)

		_obstacles.add_child(body)





func _build_zones(map: Dictionary, pixel: Vector2) -> void:

	var rows: Variant = map.get("zones", [])

	if typeof(rows) != TYPE_ARRAY:

		return

	for raw in rows:

		if typeof(raw) != TYPE_DICTIONARY:

			continue

		var cx := float(raw.get("cx", 0.5)) * pixel.x

		var cy := float(raw.get("cy", 0.5)) * pixel.y

		var r := float(raw.get("r", 0.1)) * minf(pixel.x, pixel.y)

		var ring := ColorRect.new()

		ring.size = Vector2(r * 2.0, r * 2.0)

		ring.position = Vector2(cx - r, cy - r)

		ring.color = Color.from_string(str(raw.get("color", "#ffffff22")), Color(1, 1, 1, 0.12))

		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_zones.add_child(ring)





func _clear_group_children(node: Node) -> void:

	while node.get_child_count() > 0:

		var child := node.get_child(0)

		node.remove_child(child)

		child.free()





func _build_tileset(map: Dictionary) -> TileSet:

	var image := Image.create(48, 16, false, Image.FORMAT_RGBA8)

	_stamp_tile(image, 0, Color.from_string(str(map.get("ground", "#355e32")), Color("355e32")), Color.from_string(str(map.get("ground_alt", "#2c4e29")), Color("2c4e29")))

	_stamp_tile(image, 1, Color.from_string(str(map.get("path", "#8a6a3e")), Color("8a6a3e")), Color.from_string(str(map.get("path", "#8a6a3e")), Color("8a6a3e")).darkened(0.15))

	_stamp_tile(image, 2, Color.from_string(str(map.get("border", "#6b7078")), Color("6b7078")), Color.from_string(str(map.get("border", "#6b7078")), Color("6b7078")).darkened(0.2))

	var source := TileSetAtlasSource.new()

	source.texture = ImageTexture.create_from_image(image)

	source.texture_region_size = Vector2i(TILE, TILE)

	source.create_tile(TILE_GRASS)

	source.create_tile(TILE_DIRT)

	source.create_tile(TILE_STONE)

	var tileset := TileSet.new()

	tileset.tile_size = Vector2i(TILE, TILE)

	tileset.add_source(source)

	return tileset





func _stamp_tile(image: Image, index: int, base: Color, alt: Color) -> void:

	var origin := Vector2i(index * TILE, 0)

	for y in TILE:

		for x in TILE:

			var speckled := ((x + y + index) % 5) == 0

			image.set_pixel(origin.x + x, origin.y + y, alt if speckled else base)





func _paint_map(pattern: String) -> void:

	_tiles.clear()

	for y in _map_size.y:

		for x in _map_size.x:

			_tiles.set_cell(Vector2i(x, y), SOURCE_ID, _atlas_for(pattern, x, y))





func _atlas_for(pattern: String, x: int, y: int) -> Vector2i:

	if x == 0 or y == 0 or x == _map_size.x - 1 or y == _map_size.y - 1:

		return TILE_STONE

	var w := _map_size.x

	var h := _map_size.y

	match pattern:

		"city":

			if x % 8 == 0 or y % 8 == 0:

				return TILE_DIRT

		"crater":

			var d := Vector2(x - w * 0.5, y - h * 0.5).length()

			if int(d) % 7 == 0:

				return TILE_DIRT

		"nebula":

			if (x * 17 + y * 31) % 11 == 0:

				return TILE_DIRT

		"rift":

			if absi(x * h - y * w) < h or absi(x + y - h) <= 1:

				return TILE_DIRT

		"void":

			if (x * 13 + y * 7) % 17 == 0:

				return TILE_DIRT

		_:

			if y == int(h * 0.5) or x == int(w * 0.5):

				return TILE_DIRT

	return TILE_GRASS

