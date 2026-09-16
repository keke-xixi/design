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
@onready var _chests: Node2D = $Chests
@onready var _obstacles: Node2D = $Obstacles
@onready var _zones: Node2D = $Zones
@onready var _camera: Camera2D = $Player/Camera2D
var _map_size := Vector2i(48, 30)
var _spawn_acc := 0.0
var _bounds := Rect2()
var _obstacle_rects: Array[Rect2] = []
var _zone_defs: Array[Dictionary] = []
var _last_wave_hint := ""
var _zone_tick := 0.0
var _last_zone_effect := ""
var _overlay: CanvasLayer
var _cleared_stop := false
var _spawn_pause := 0.0
var _hitstopping := false

func _ready() -> void:
	_pickups.add_to_group("pickups")
	EventBus.stage_changed.connect(_on_stage_changed)
	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.wave_changed.connect(_on_wave_banner)
	_overlay = preload("res://src/ui/run_overlay.gd").new()
	add_child(_overlay)
	_apply_stage(GameState.stage_id)

func _process(delta: float) -> void:
	_tick_ambient_motes(delta)
	if GameState.dead:
		return
	GameState.run_time += delta
	_apply_zone_effects(delta)
	_pulse_zone_visuals()
	if _cleared_stop:
		return
	if _spawn_pause > 0.0:
		_spawn_pause -= delta
	var stage := GameState.current_stage()
	if stage == null:
		return
	var kills := GameState.stage_kills()
	var hint := stage.wave_hint(kills)
	if hint != _last_wave_hint and not hint.is_empty():
		_last_wave_hint = hint
		EventBus.wave_changed.emit(hint)
	if _spawn_pause > 0.0:
		return
	_spawn_acc += delta
	var interval := stage.spawn_interval_for(kills)
	var cap := stage.max_alive_for(kills)
	if _spawn_acc >= interval and _mobs.get_child_count() < cap:
		_spawn_acc = 0.0
		_spawn_one(stage)

func _pulse_zone_visuals() -> void:
	var t := Time.get_ticks_msec() * 0.003
	for z in _zone_defs:
		var vis: Variant = z.get("visual", null)
		if vis is CanvasItem and is_instance_valid(vis):
			(vis as CanvasItem).modulate.a = 0.7 + 0.3 * sin(t + float(z.get("radius", 1.0)))

func _on_wave_banner(hint: String) -> void:
	_spawn_pause = float(ContentDB.section("combat").get("wave_pause", 0.85))
	if SfxService:
		SfxService.play_wave()
	var banner := get_node_or_null("HUD")
	if banner and banner.has_method("show_clear"):
		banner.show_clear(hint)
	GameState.heal_amount(maxi(int(float(GameState.max_hp) * 0.06), 1))
	# Soft auto-buff on later waves (no modal interrupt).
	if GameState.stage_kills() > 0:
		var cur := float(GameState.run.run_buffs.get("temp_damage", 0.0))
		if cur < 0.24:
			GameState.run.apply_effect({ "temp_damage": 0.03 })
			FloatTextManager.show_message(
				_player.global_position + Vector2(0, -40) if _player else Vector2(320, 140),
				"伤+3%",
				Color(0.95, 0.85, 0.5)
			)
	if _player and _player.has_method("pulse_camera"):
		_player.pulse_camera(0.07)

func hitstop(duration: float = 0.04) -> void:
	if _hitstopping or DisplayServer.get_name() == "headless":
		return
	# Soft hitch — do not freeze the whole game.
	_hitstopping = true
	var prev := Engine.time_scale
	var scale := float(ContentDB.section("combat").get("hitstop_scale", 0.22))
	Engine.time_scale = clampf(scale, 0.15, 0.5)
	await get_tree().create_timer(minf(duration, 0.045), true, true).timeout
	Engine.time_scale = prev if prev > 0.1 else 1.0
	_hitstopping = false

func _apply_zone_effects(delta: float) -> void:
	if _player == null or GameState.dead:
		return
	_zone_tick += delta
	if _zone_tick < 0.25:
		return
	_zone_tick = 0.0
	var mods := zone_mods_at(_player.global_position)
	var dps := float(mods.get("dps", 0.0))
	var hps := float(mods.get("hps", 0.0))
	var effect := str(mods.get("effect", ""))
	# One toast when stepping into a new zone type — teaches map without a modal.
	if effect != _last_zone_effect and not effect.is_empty():
		var label := effect
		var col := Color(0.9, 0.9, 0.95)
		match effect:
			"heal":
				label = "灵脉·回血"
				col = Color(0.55, 0.95, 0.7)
			"slow":
				label = "滞气·减速"
				col = Color(0.95, 0.85, 0.45)
			"damage":
				label = "煞地·伤血"
				col = Color(1.0, 0.5, 0.4)
		FloatTextManager.show_message(_player.global_position + Vector2(0, -28), label, col)
	_last_zone_effect = effect
	if dps > 0.0:
		_player.take_hit(maxi(int(dps * 0.25), 1))
	if hps > 0.0:
		GameState.heal_amount(maxi(int(hps * 0.25), 1))

func zone_mods_at(pos: Vector2) -> Dictionary:
	var speed_mult := 1.0
	var dps := 0.0
	var hps := 0.0
	var effect := ""
	for z in _zone_defs:
		var c: Vector2 = z["center"]
		var r: float = z["radius"]
		if pos.distance_to(c) > r:
			continue
		match str(z.get("effect", "")):
			"slow":
				speed_mult = minf(speed_mult, float(z.get("speed_mult", 0.75)))
				effect = "slow"
			"damage":
				dps = maxf(dps, float(z.get("dps", 4.0)))
				effect = "damage"
			"heal":
				hps = maxf(hps, float(z.get("hps", 2.0)))
				effect = "heal"
	return { "speed_mult": speed_mult, "dps": dps, "hps": hps, "effect": effect }

func _on_stage_changed(stage_id: String) -> void:
	_apply_stage(stage_id)

func _on_stage_cleared(_stage_id: String) -> void:
	_cleared_stop = true
	if SfxService and SfxService.has_method("play_clear"):
		SfxService.play_clear()
	var banner := get_node_or_null("HUD")
	if banner and banner.has_method("show_clear"):
		banner.show_clear()

func _on_boss_spawned(boss_id: String) -> void:
	var pos := _boss_spawn_pos()
	_spawn_ring(pos, Color(1.0, 0.55, 0.25, 0.85), 42.0)
	spawn_enemy_at(boss_id, pos, true)
	if SfxService and SfxService.has_method("play_boss"):
		SfxService.play_boss()
	if _player and _player.has_method("pulse_camera"):
		_player.pulse_camera(0.2)
	if _camera:
		var z0 := _camera.zoom
		var ztw := create_tween()
		ztw.tween_property(_camera, "zoom", z0 * 1.06, 0.12)
		ztw.tween_property(_camera, "zoom", z0, 0.28)
	# Brief dark flash.
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.08, 0.02, 0.02, 0.5)
	var hud := get_node_or_null("HUD")
	if hud and hud.get_node_or_null("Root"):
		var root: Control = hud.get_node("Root")
		root.add_child(flash)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var tw := flash.create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.4)
		tw.tween_callback(flash.queue_free)

func _boss_spawn_pos() -> Vector2:
	var pixel := Vector2(_map_size) * float(TILE)
	return pixel * 0.5 + Vector2(0, -80)

func spawn_enemy_at(enemy_id: String, pos: Vector2, as_boss_scale: bool = false) -> void:
	var enemy := ContentDB.get_enemy(enemy_id)
	if enemy == null:
		push_warning("Missing enemy %s" % enemy_id)
		return
	var mob := preload("res://scenes/world/mob.tscn").instantiate()
	_mobs.add_child(mob)
	mob.setup(enemy)
	if as_boss_scale or enemy.is_boss:
		mob.scale = Vector2(1.5, 1.5)
	mob.global_position = pos

func on_boss_defeated(_boss_id: String) -> void:
	pass

func _apply_stage(stage_id: String) -> void:
	var stage := ContentDB.get_stage(stage_id)
	if stage == null:
		push_error("Unknown stage %s" % stage_id)
		return
	_cleared_stop = false
	_clear_group_children(_mobs)
	_clear_group_children(_projectiles)
	_clear_group_children(_pickups)
	_clear_group_children(_chests)
	_clear_group_children(_obstacles)
	_clear_group_children(_zones)
	_spawn_acc = 0.0
	_last_wave_hint = ""
	_spawn_pause = 0.0
	_obstacle_rects.clear()
	_zone_defs.clear()
	_last_zone_effect = ""
	var map: Dictionary = stage.map
	_map_size = Vector2i(int(map.get("width", 48)), int(map.get("height", 30)))
	var pixel := Vector2(_map_size) * float(TILE)
	_bounds = Rect2(Vector2(24, 24), pixel - Vector2(48, 48))
	_set_background(stage, pixel)
	var pattern := str(map.get("pattern", "yard"))
	# Slightly stronger tiles on patterned stages so layouts read at a glance.
	var tile_a := float(map.get("tile_opacity", 0.28))
	if pattern in ["city", "rift", "crater"]:
		tile_a = maxf(tile_a, 0.34)
	_tiles.modulate = Color(1, 1, 1, tile_a)
	_tiles.tile_set = _build_tileset(map)
	_paint_map(pattern)
	_build_obstacles(map)
	_build_zones(map, pixel)
	_build_chests(map, pixel)
	_player.position = pixel * 0.5
	_player.configure(_projectiles, _bounds)
	# Slightly wider view after sprite shrink — keeps characters readable, not oversized.
	_camera.zoom = Vector2(1.12, 1.12)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(pixel.x)
	_camera.limit_bottom = int(pixel.y)
	var ztw := create_tween()
	ztw.tween_property(_camera, "zoom", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
	add_to_group("game_world")
	_ensure_vignette()
	_spawn_ambient_motes(pixel, stage)
	var obs_array: Array = []
	for r in _obstacle_rects:
		obs_array.append(r)
	var zone_array: Array = []
	for z in _zone_defs:
		zone_array.append({
			"center": z["center"],
			"radius": z["radius"],
			"effect": z.get("effect", ""),
		})
	EventBus.map_layout_updated.emit(pixel, obs_array, zone_array)
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
	var accent := Color.from_string(stage.accent, Color(0.9, 0.92, 0.95))
	_bg.modulate = Color(0.88 + accent.r * 0.08, 0.9 + accent.g * 0.06, 0.92 + accent.b * 0.05, 1.0)

func _ensure_vignette() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var root := hud.get_node_or_null("Root")
	if root == null or root.get_node_or_null("EdgeTop"):
		return
	for i in 4:
		var edge := ColorRect.new()
		match i:
			0:
				edge.name = "EdgeTop"
				edge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				edge.offset_bottom = 26
			1:
				edge.name = "EdgeBottom"
				edge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				edge.offset_top = -22
			2:
				edge.name = "EdgeLeft"
				edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
				edge.offset_right = 32
			3:
				edge.name = "EdgeRight"
				edge.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
				edge.offset_left = -32
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.color = Color(0.02, 0.03, 0.05, 0.26)
		root.add_child(edge)

func _spawn_ambient_motes(pixel: Vector2, stage: StageDef = null) -> void:
	var old := get_node_or_null("AmbientMotes")
	if old:
		old.queue_free()
	var root := Node2D.new()
	root.name = "AmbientMotes"
	root.z_index = 8
	add_child(root)
	var accent := Color(0.75, 0.95, 1.0)
	if stage != null:
		accent = Color.from_string(stage.accent, accent)
	for i in 18:
		var mote := Polygon2D.new()
		mote.color = Color(accent.r, accent.g, accent.b, randf_range(0.12, 0.3))
		mote.polygon = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		mote.position = Vector2(randf() * pixel.x, randf() * pixel.y)
		root.add_child(mote)
		mote.set_meta("drift", Vector2(randf_range(-8, 8), randf_range(-14, -4)))
		mote.set_meta("phase", randf() * TAU)

func _tick_ambient_motes(delta: float) -> void:
	var root := get_node_or_null("AmbientMotes")
	if root == null:
		return
	var pixel := Vector2(_map_size) * float(TILE)
	for child in root.get_children():
		if not (child is Polygon2D):
			continue
		var mote := child as Polygon2D
		var drift: Vector2 = mote.get_meta("drift", Vector2(0, -8))
		var phase: float = float(mote.get_meta("phase", 0.0)) + delta
		mote.set_meta("phase", phase)
		mote.position += drift * delta
		mote.modulate.a = 0.35 + 0.25 * sin(phase * 2.0)
		if mote.position.y < -8.0 or mote.position.x < -8.0 or mote.position.x > pixel.x + 8.0:
			mote.position = Vector2(randf() * pixel.x, pixel.y + randf() * 20.0)

func _spawn_one(stage: StageDef) -> void:
	var wave := stage.current_wave(GameState.stage_kills())
	var pool: Array = wave.get("spawns", [])
	var enemy_id := stage._pick_from_spawns(pool) if typeof(pool) == TYPE_ARRAY and not pool.is_empty() else stage.pick_enemy_id()
	var enemy := ContentDB.get_enemy(enemy_id)
	if enemy == null:
		push_error("Stage %s missing enemy %s" % [stage.id, enemy_id])
		return
	var pos := _spawn_point()
	_spawn_ring(pos, Color(1.0, 0.45, 0.35, 0.55), 18.0)
	var mob := preload("res://scenes/world/mob.tscn").instantiate()
	_mobs.add_child(mob)
	mob.setup(enemy)
	if enemy.is_boss:
		mob.scale = Vector2(1.35, 1.35)
	elif randf() < float(ContentDB.section("combat").get("elite_spawn_chance", 0.1)):
		mob.make_elite()
	mob.global_position = pos

func _spawn_ring(pos: Vector2, color: Color, radius: float) -> void:
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = color
	ring.z_index = 6
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	pts.append(pts[0])
	ring.points = pts
	add_child(ring)
	ring.global_position = pos
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.22)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ring.queue_free)
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
		var base_col := Color.from_string(str(raw.get("color", "#4a4038")), Color("4a4038"))
		var shadow := Polygon2D.new()
		shadow.color = Color(0.05, 0.05, 0.07, 0.35)
		shadow.polygon = [
			Vector2(2, h + 2), Vector2(w + 4, h + 2), Vector2(w + 2, h + 6), Vector2(4, h + 6)
		]
		body.add_child(shadow)
		var rock := Polygon2D.new()
		rock.color = base_col.lightened(0.08)
		rock.polygon = [
			Vector2(2, h * 0.55), Vector2(w * 0.25, 2), Vector2(w * 0.75, 0), Vector2(w - 2, h * 0.4),
			Vector2(w - 4, h - 2), Vector2(4, h - 2)
		]
		body.add_child(rock)
		var highlight := Polygon2D.new()
		highlight.color = base_col.lightened(0.28)
		highlight.polygon = [
			Vector2(w * 0.28, 6), Vector2(w * 0.55, 4), Vector2(w * 0.42, h * 0.35)
		]
		body.add_child(highlight)
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
		var effect := str(raw.get("effect", ""))
		var col := Color.from_string(str(raw.get("color", "#ffffff22")), Color(1, 1, 1, 0.12))
		match effect:
			"heal":
				col = Color(0.35, 0.85, 0.55, 0.22)
			"slow":
				col = Color(0.95, 0.78, 0.35, 0.2)
			"damage":
				col = Color(0.95, 0.35, 0.3, 0.22)
		var ring := Polygon2D.new()
		ring.position = Vector2(cx, cy)
		ring.color = col
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		ring.polygon = pts
		ring.set_meta("pulse_phase", randf() * TAU)
		_zones.add_child(ring)
		var rim := Line2D.new()
		rim.width = 2.0
		rim.default_color = Color(col.r, col.g, col.b, minf(col.a + 0.45, 0.85))
		rim.position = Vector2(cx, cy)
		for i in 25:
			var a2 := TAU * float(i) / 24.0
			rim.add_point(Vector2(cos(a2), sin(a2)) * r)
		_zones.add_child(rim)
		# Tiny ground glyph so heal/slow/damage read without HUD clutter.
		var mark := Label.new()
		mark.text = {"heal": "愈", "slow": "滞", "damage": "煞"}.get(effect, "·")
		mark.add_theme_font_size_override("font_size", 11)
		mark.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.9).lightened(0.25))
		mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		mark.add_theme_constant_override("shadow_offset_x", 1)
		mark.add_theme_constant_override("shadow_offset_y", 1)
		mark.position = Vector2(cx - 8, cy - 8)
		mark.z_index = 2
		_zones.add_child(mark)
		_zone_defs.append({
			"center": Vector2(cx, cy),
			"radius": r,
			"effect": effect,
			"speed_mult": float(raw.get("speed_mult", 0.75)),
			"dps": float(raw.get("dps", 0.0)),
			"hps": float(raw.get("hps", 0.0)),
			"visual": ring,
		})

func _build_chests(map: Dictionary, pixel: Vector2) -> void:
	var rows: Variant = map.get("chests", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cx := float(raw.get("cx", 0.5)) * pixel.x
		var cy := float(raw.get("cy", 0.5)) * pixel.y
		var loot: Variant = raw.get("loot", [])
		var chest := preload("res://scenes/world/chest.tscn").instantiate()
		_chests.add_child(chest)
		if chest.has_method("setup"):
			chest.setup(Vector2(cx, cy), loot if typeof(loot) == TYPE_ARRAY else [])

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
			var n := (x * 3 + y * 7 + index * 11) % 11
			var edge := x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1
			var c := alt if n < 3 else base
			if edge:
				c = c.darkened(0.12)
			elif n == 5:
				c = c.lightened(0.1)
			elif n == 8:
				c = c.lightened(0.04)
			image.set_pixel(origin.x + x, origin.y + y, Color(c.r, c.g, c.b, 0.95))

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
			# Street grid + plaza blocks — reads as human city vs wild yard.
			if x % 8 == 0 or y % 8 == 0:
				return TILE_DIRT
			if (x / 8 + y / 8) % 2 == 0 and (x % 8 > 2 and y % 8 > 2):
				return TILE_STONE if ((x + y) % 5 == 0) else TILE_GRASS
		"crater":
			var d := Vector2(x - w * 0.5, y - h * 0.5).length()
			if d < 5.0:
				return TILE_DIRT
			if int(d) % 7 == 0:
				return TILE_DIRT
		"nebula":
			if (x * 17 + y * 31) % 11 == 0:
				return TILE_DIRT
			if (x * 3 + y * 5) % 19 == 0:
				return TILE_STONE
		"rift":
			if absi(x * h - y * w) < h or absi(x + y - h) <= 1:
				return TILE_DIRT
			if absi(x - y) <= 1:
				return TILE_STONE
		"void":
			if (x * 13 + y * 7) % 17 == 0:
				return TILE_DIRT
		_:
			# Yard: cross path + soft garden patches.
			if y == int(h * 0.5) or x == int(w * 0.5):
				return TILE_DIRT
			if (x + y) % 13 == 0:
				return TILE_DIRT
	return TILE_GRASS
