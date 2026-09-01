extends Node2D

const TILE := 16
const TILE_GRASS := Vector2i(0, 0)
const TILE_DIRT := Vector2i(1, 0)
const TILE_STONE := Vector2i(2, 0)
const SOURCE_ID := 0

@onready var _tiles: TileMapLayer = $TileMapLayer
@onready var _player: CharacterBody2D = $Player
@onready var _mobs: Node2D = $Mobs
@onready var _projectiles: Node2D = $Projectiles
@onready var _pickups: Node2D = $Pickups
@onready var _camera: Camera2D = $Player/Camera2D

var _map_size := Vector2i(64, 40)
var _spawn_acc := 0.0


func _ready() -> void:
	_pickups.add_to_group("pickups")
	EventBus.stage_changed.connect(_on_stage_changed)
	_apply_stage(GameState.stage_id)


func _process(delta: float) -> void:
	if GameState.dead:
		return
	GameState.run_time += delta
	var stage := GameState.current_stage()
	if stage == null:
		return
	_spawn_acc += delta
	if _spawn_acc >= stage.spawn_interval and _mobs.get_child_count() < stage.max_alive:
		_spawn_acc = 0.0
		_spawn_one(stage)


func _on_stage_changed(stage_id: String) -> void:
	_apply_stage(stage_id)


func _apply_stage(stage_id: String) -> void:
	var stage := ContentDB.get_stage(stage_id)
	if stage == null:
		push_error("Unknown stage %s" % stage_id)
		return
	_clear_group_children(_mobs)
	_clear_group_children(_projectiles)
	_clear_group_children(_pickups)
	_spawn_acc = 0.0
	var map: Dictionary = stage.map
	_map_size = Vector2i(int(map.get("width", 64)), int(map.get("height", 40)))
	_tiles.tile_set = _build_tileset(map)
	_paint_map(str(map.get("pattern", "yard")))
	var pixel := Vector2(_map_size) * float(TILE)
	_player.position = pixel * 0.5
	_player.configure(_projectiles, Rect2(Vector2(24, 24), pixel - Vector2(48, 48)))
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(pixel.x)
	_camera.limit_bottom = int(pixel.y)
	print("Stage: %s (%s)" % [stage.display_name, stage.id])


func _spawn_one(stage: StageDef) -> void:
	var enemy_id := stage.pick_enemy_id()
	var enemy := ContentDB.get_enemy(enemy_id)
	if enemy == null:
		push_error("Stage %s missing enemy %s" % [stage.id, enemy_id])
		return
	var mob := preload("res://scenes/world/mob.tscn").instantiate()
	_mobs.add_child(mob)
	mob.setup(enemy)
	mob.global_position = _spawn_point()


func _spawn_point() -> Vector2:
	var cbt := ContentDB.section("combat")
	var min_r := float(cbt.get("spawn_min_radius", 150))
	var max_r := float(cbt.get("spawn_max_radius", 230))
	var pixel := Vector2(_map_size) * float(TILE)
	for _i in 8:
		var pos: Vector2 = _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(min_r, max_r)
		pos.x = clampf(pos.x, 32.0, pixel.x - 32.0)
		pos.y = clampf(pos.y, 32.0, pixel.y - 32.0)
		if pos.distance_to(_player.global_position) >= min_r * 0.6:
			return pos
	return Vector2(pixel.x * 0.5, 48.0)


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
