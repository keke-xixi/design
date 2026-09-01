extends Node2D

const TILE := 16
const MAP_SIZE := Vector2i(40, 24)
const SOURCE_ID := 0
const TILE_GRASS := Vector2i(0, 0)
const TILE_DIRT := Vector2i(1, 0)
const TILE_STONE := Vector2i(2, 0)

@onready var _tiles: TileMapLayer = $TileMapLayer
@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	_tiles.tile_set = _build_tileset()
	_paint_map()
	_player.position = Vector2(MAP_SIZE.x * TILE * 0.5, MAP_SIZE.y * TILE * 0.5)
	var realm := ContentDB.realms.get_realm(GameState.cultivation.realm_id)
	if realm:
		print("Current realm: %s (%s)" % [realm.display_name, realm.id])


func _build_tileset() -> TileSet:
	var image := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	_stamp_tile(image, 0, Color("355e32"), Color("2c4e29"))
	_stamp_tile(image, 1, Color("8a6a3e"), Color("6e5230"))
	_stamp_tile(image, 2, Color("6b7078"), Color("4f545c"))
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


func _paint_map() -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var atlas := TILE_GRASS
			if x == 0 or y == 0 or x == MAP_SIZE.x - 1 or y == MAP_SIZE.y - 1:
				atlas = TILE_STONE
			elif y == int(MAP_SIZE.y * 0.5) or x == int(MAP_SIZE.x * 0.5):
				atlas = TILE_DIRT
			_tiles.set_cell(cell, SOURCE_ID, atlas)
