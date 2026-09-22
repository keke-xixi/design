extends Area2D

## World chest — beacon from afar, loud ground ring + 「开」 when near.

var _opened := false
var _loot: Array = []
var _beacon: Line2D
var _near_ring: Line2D
var _ground_fill: Polygon2D
var _open_label: Label
var _open_plate: Polygon2D
var _was_near := false
var _approach_r := 72.0
var _open_r := 28.0
## One-shot punch when 「开」 first becomes readable.
var _open_cue_punched := false

func is_opened() -> bool:
	return _opened

func setup(pos: Vector2, loot: Array) -> void:
	global_position = pos
	_loot = loot if typeof(loot) == TYPE_ARRAY else []

func _ready() -> void:
	add_to_group("chests")
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	monitorable = false
	call_deferred("_enable_sensing")
	$Visual.color = Color(0.85, 0.72, 0.35, 0.95)
	_ensure_beacon()

func _ensure_beacon() -> void:
	# Soft vertical beam so chests pull the eye across the yard/city.
	_beacon = Line2D.new()
	_beacon.name = "Beacon"
	_beacon.width = 2.0
	_beacon.default_color = Color(1.0, 0.88, 0.45, 0.55)
	_beacon.z_index = 4
	_beacon.add_point(Vector2(0, -8))
	var beam_h := -52.0 if GameState.stage_id == "sect" else -36.0
	_beacon.add_point(Vector2(0, beam_h))
	add_child(_beacon)
	# Gold diamond pad — chests must not read as circular 愈地.
	_ground_fill = Polygon2D.new()
	_ground_fill.name = "GroundFill"
	_ground_fill.z_index = 2
	_ground_fill.color = Color(1.0, 0.85, 0.35, 0.0)
	_ground_fill.polygon = PackedVector2Array([
		Vector2(0, -22), Vector2(22, 0), Vector2(0, 22), Vector2(-22, 0)
	])
	add_child(_ground_fill)
	_near_ring = Line2D.new()
	_near_ring.name = "NearRing"
	_near_ring.width = 2.4
	_near_ring.default_color = Color(1.0, 0.9, 0.5, 0.0)
	_near_ring.z_index = 3
	# Diamond rim — matches gold pad, not the circular 愈 well.
	_near_ring.add_point(Vector2(0, -24))
	_near_ring.add_point(Vector2(24, 0))
	_near_ring.add_point(Vector2(0, 24))
	_near_ring.add_point(Vector2(-24, 0))
	_near_ring.add_point(Vector2(0, -24))
	add_child(_near_ring)
	# Cardinal ticks on the ground ring.
	for i in 4:
		var tick := Line2D.new()
		tick.name = "Tick%d" % i
		tick.width = 1.8
		tick.default_color = Color(1.0, 0.92, 0.55, 0.0)
		tick.z_index = 3
		var a3 := TAU * 0.25 * float(i) + PI * 0.25
		tick.add_point(Vector2.from_angle(a3) * 20.0)
		tick.add_point(Vector2.from_angle(a3) * 30.0)
		add_child(tick)
	_open_label = Label.new()
	_open_label.name = "OpenHint"
	_open_label.text = "开"
	_open_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_open_label.add_theme_font_size_override("font_size", 16)
	_open_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.52, 1.0))
	_open_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_open_label.add_theme_constant_override("shadow_offset_x", 1)
	_open_label.add_theme_constant_override("shadow_offset_y", 1)
	_open_label.position = Vector2(-10, -52)
	_open_label.size = Vector2(20, 22)
	_open_label.pivot_offset = Vector2(10, 11)
	_open_label.z_index = 11
	_open_label.modulate.a = 0.0
	# Soft gold plate behind 「开」 — readable on busy yard/city tiles.
	_open_plate = Polygon2D.new()
	_open_plate.name = "OpenPlate"
	_open_plate.z_index = 10
	_open_plate.color = Color(0.18, 0.12, 0.04, 0.0)
	_open_plate.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10), Vector2(-14, 10),
	])
	_open_plate.position = Vector2(0, -42)
	add_child(_open_plate)
	add_child(_open_label)

func _enable_sensing() -> void:
	set_deferred("monitoring", true)

func _physics_process(_delta: float) -> void:
	if _opened:
		return
	_pulse_visual()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	var near := dist < _approach_r
	var t := Time.get_ticks_msec() * 0.001
	# Approach strength 0..1 inside approach radius.
	var strength := clampf(1.0 - (dist - _open_r) / (_approach_r - _open_r), 0.0, 1.0)
	if _near_ring:
		_near_ring.default_color.a = strength * (0.55 + 0.4 * sin(t * 6.0))
		_near_ring.width = 2.0 + 1.2 * strength
		var pulse_scale := 1.0 + 0.08 * sin(t * 5.5) * strength
		_near_ring.scale = Vector2(pulse_scale, pulse_scale)
	if _ground_fill:
		_ground_fill.color.a = strength * 0.28
		_ground_fill.scale = Vector2(0.85 + 0.2 * strength, 0.85 + 0.2 * strength)
	for i in 4:
		var tick := get_node_or_null("Tick%d" % i) as Line2D
		if tick:
			tick.default_color.a = strength * 0.85
	# 「开」 only past a clear threshold — no ghost text at approach edge.
	var cue_on := strength >= 0.42
	if _open_label:
		if cue_on:
			var bob := 0.55 + 0.45 * sin(t * 5.2)
			_open_label.modulate = Color(1.15, 1.05, 0.75, 0.82 + 0.18 * bob)
			_open_label.add_theme_color_override("font_color", Color(1.0, 0.94 + 0.04 * bob, 0.48, 1.0))
			_open_label.position.y = -52.0 - 3.0 * sin(t * 4.2)
			if not _open_cue_punched:
				_open_cue_punched = true
				_punch_open_cue()
		else:
			_open_label.modulate.a = 0.0
			_open_cue_punched = false
	if _open_plate:
		if cue_on:
			var p := 0.55 + 0.45 * sin(t * 5.2)
			_open_plate.color = Color(0.22, 0.14, 0.04, 0.55 + 0.2 * p)
			_open_plate.position.y = -42.0 - 3.0 * sin(t * 4.2)
		else:
			_open_plate.color.a = 0.0
			_open_plate.scale = Vector2.ONE
	# One toast the first time you enter approach range.
	if near and not _was_near:
		FloatTextManager.show_message(global_position + Vector2(0, -40), "开", Color(1.0, 0.92, 0.5))
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_clear") and GameState.stage_id in ["sect", "country"]:
			hud.call("show_clear", "宝箱 · 开")
	_was_near = near
	if dist < _open_r:
		_open(player)

## Warm-gold scale punch when 「开」 first crosses the readable threshold.
func _punch_open_cue() -> void:
	if _open_label:
		_open_label.scale = Vector2(0.72, 0.72)
		var tw := create_tween()
		tw.tween_property(_open_label, "scale", Vector2(1.22, 1.22), 0.1).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_open_label, "scale", Vector2.ONE, 0.14)
	if _open_plate:
		_open_plate.scale = Vector2(0.7, 0.7)
		var ptw := create_tween()
		ptw.tween_property(_open_plate, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK)
		ptw.tween_property(_open_plate, "scale", Vector2.ONE, 0.14)
	# Soft gold rim kick on the near diamond — cue lands with the word.
	if _near_ring:
		_near_ring.default_color = Color(1.0, 0.94, 0.5, 0.95)
		_near_ring.width = 3.2
		var rtw := create_tween()
		rtw.tween_property(_near_ring, "width", 2.4, 0.28)

func _pulse_visual() -> void:
	var t := Time.get_ticks_msec() * 0.005
	var s := 1.0 + sin(t) * 0.07
	$Visual.scale = Vector2(s, s)
	if has_node("Glow"):
		$Glow.modulate.a = 0.55 + 0.35 * sin(t * 1.3)
	if _beacon:
		_beacon.default_color.a = 0.35 + 0.35 * sin(t * 1.1)
		_beacon.width = 1.6 + 0.8 * (0.5 + 0.5 * sin(t))

func _open(_player: Node2D) -> void:
	if _opened:
		return
	_opened = true
	_burst_open()
	var parent := get_tree().get_first_node_in_group("pickups")
	var loot_bits: Array[String] = []
	for i in _loot.size():
		var raw: Variant = _loot[i]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item_id := str(raw.get("item_id", ""))
		var amount := int(raw.get("amount", 1))
		if item_id.is_empty() or amount <= 0:
			continue
		if item_id == "spirit_stones":
			continue
		var item := ContentDB.get_item(item_id)
		var name := item.display_name if item else item_id
		loot_bits.append("%s×%d" % [name, amount])
		if parent:
			var pickup := preload("res://scenes/world/item_pickup.tscn").instantiate()
			parent.add_child(pickup)
			pickup.global_position = global_position + Vector2(i * 8 - 4, -6)
			if pickup.has_method("setup"):
				pickup.setup(item_id, amount)
		else:
			GameState.grant_item(item_id, amount)
	var stones := _loot_stones()
	if stones > 0:
		# Spawn a gold orb so stone loot shares the land→suck→pop juice.
		if parent:
			var stone_orb := preload("res://scenes/world/item_pickup.tscn").instantiate()
			parent.add_child(stone_orb)
			stone_orb.global_position = global_position + Vector2(0, -10)
			if stone_orb.has_method("setup"):
				stone_orb.setup("spirit_stones", stones)
		else:
			GameState.add_spirit_stones(stones)
			loot_bits.append("+%d石" % stones)
	EventBus.chest_opened.emit(global_position)
	if SfxService:
		SfxService.play_pickup()
	var tip := "宝" if loot_bits.is_empty() else "宝 · " + str(loot_bits[0])
	FloatTextManager.show_message(global_position + Vector2(0, -18), tip, Color(1.0, 0.88, 0.45))
	if loot_bits.size() > 1:
		FloatTextManager.show_message(global_position + Vector2(0, -32), loot_bits[1], Color(0.95, 0.85, 0.55))
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)

func _burst_open() -> void:
	if has_node("Lid"):
		var lid := $Lid
		var tw := create_tween()
		tw.tween_property(lid, "position:y", lid.position.y - 10.0, 0.12)
		tw.parallel().tween_property(lid, "modulate:a", 0.0, 0.18)
	if has_node("Glow"):
		$Glow.color = Color(1.0, 0.92, 0.55, 0.45)
	if _beacon:
		_beacon.visible = false
	if _near_ring:
		_near_ring.visible = false
	if _ground_fill:
		_ground_fill.visible = false
	if _open_label:
		_open_label.visible = false
	if _open_plate:
		_open_plate.visible = false
	for i in 4:
		var tick := get_node_or_null("Tick%d" % i)
		if tick:
			tick.visible = false
	# Warm-gold diamond pad — chest language, not a heal circle.
	var pad := Polygon2D.new()
	pad.z_index = 7
	pad.color = Color(1.0, 0.82, 0.35, 0.45)
	pad.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0),
	])
	add_child(pad)
	pad.scale = Vector2(0.5, 0.5)
	var ptw := pad.create_tween()
	ptw.tween_property(pad, "scale", Vector2(1.8, 1.8), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ptw.parallel().tween_property(pad, "modulate:a", 0.0, 0.2)
	ptw.tween_callback(pad.queue_free)
	# Double gold ring — open lands as loot, not a quiet fade.
	for ring_i in 2:
		var ring := Line2D.new()
		ring.width = 2.6 - float(ring_i) * 0.5
		ring.default_color = Color(1.0, 0.88 - float(ring_i) * 0.06, 0.4, 0.95 - float(ring_i) * 0.15)
		ring.z_index = 8
		var r0 := 11.0 + float(ring_i) * 5.0
		for i in 21:
			var a := TAU * float(i) / 20.0
			ring.add_point(Vector2(cos(a), sin(a)) * r0)
		add_child(ring)
		var delay := float(ring_i) * 0.04
		var tw2 := ring.create_tween()
		if delay > 0.0:
			tw2.tween_interval(delay)
		tw2.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
		tw2.tween_callback(ring.queue_free)
	# Soft rising gold flecks — treasure pop without clutter.
	for i in 4:
		var fleck := Polygon2D.new()
		fleck.z_index = 9
		fleck.color = Color(1.0, 0.92, 0.55, 0.85)
		fleck.polygon = PackedVector2Array([
			Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5),
		])
		add_child(fleck)
		var ang := TAU * float(i) / 4.0 + 0.4
		fleck.position = Vector2.from_angle(ang) * 6.0
		var ftw := fleck.create_tween()
		ftw.tween_interval(float(i) * 0.03)
		ftw.tween_property(fleck, "position", fleck.position + Vector2.from_angle(ang) * 16.0 + Vector2(0, -12), 0.28)
		ftw.parallel().tween_property(fleck, "modulate:a", 0.0, 0.28)
		ftw.tween_callback(fleck.queue_free)
	# Radar warm-gold diamond + HUD rim — open must land on the map.
	var world := get_tree().get_first_node_in_group("game_world")
	if world and world.has_method("radar_ping"):
		world.call("radar_ping", global_position, "chest")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_chest_edges"):
		hud.call("flash_chest_edges")
	elif hud and hud.has_method("flash_steel_edges"):
		hud.call("flash_steel_edges")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("pulse_camera"):
		player.call("pulse_camera", 0.07)

func _loot_stones() -> int:
	for raw in _loot:
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("item_id", "")) == "spirit_stones":
			return int(raw.get("amount", 0))
	return 0
