extends Area2D

## World loot orb — land flash → magnet suck → crisp collect pop.

var item_id: String = ""
var amount: int = 1
var _pulse := 0.0
var _visual: Polygon2D
var _landing := true
var _sucking := false
var _collected := false
var _land_ring: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	monitorable = false
	call_deferred("_enable_sensing")
	_ensure_visual()
	_apply_rarity_visual()
	# setup() usually runs after add_child — wait for item_id before land FX.
	if not item_id.is_empty():
		_play_land_flash()

func _enable_sensing() -> void:
	set_deferred("monitoring", true)

func setup(id: String, qty: int) -> void:
	item_id = id
	amount = maxi(qty, 1)
	_ensure_visual()
	_apply_rarity_visual()
	_play_land_flash()

func _ensure_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		return
	if has_node("Visual"):
		_visual = $Visual as Polygon2D

func _is_stone() -> bool:
	return item_id == "spirit_stones" or item_id.ends_with("_token")

func _is_pill() -> bool:
	return "pill" in item_id

func _apply_rarity_visual() -> void:
	_ensure_visual()
	if _visual == null:
		return
	var item := ContentDB.get_item(item_id)
	var rarity := item.rarity if item else "common"
	var color := LootService.rarity_color(rarity)
	# Stones / pills get distinct silhouettes so magnet trails read mid-fight.
	if _is_stone():
		color = Color(1.0, 0.88, 0.4)
		_visual.polygon = PackedVector2Array([
			Vector2(0, -7), Vector2(5, -2), Vector2(4, 5), Vector2(-4, 5), Vector2(-5, -2),
		])
	elif _is_pill():
		color = Color(0.55, 0.95, 0.75) if rarity == "common" else color
		_visual.polygon = PackedVector2Array([
			Vector2(-5, -3), Vector2(5, -3), Vector2(5, 3), Vector2(-5, 3),
		])
	_visual.color = Color(color.r, color.g, color.b, 0.98)
	if has_node("Glow"):
		var glow := $Glow as Polygon2D
		if glow:
			var ga := 0.32 if _is_stone() or rarity in ["rare", "epic", "legendary"] else 0.16
			glow.color = Color(color.r, color.g, color.b, ga)
	scale = Vector2(1.25, 1.25) if (_is_stone() or rarity in ["rare", "epic", "legendary"]) else Vector2.ONE
	if (rarity in ["epic", "legendary"] or _is_stone()) and not has_node("Spark"):
		var spark := Polygon2D.new()
		spark.name = "Spark"
		spark.z_index = 1
		spark.color = Color(color.r, color.g, color.b, 0.75)
		spark.polygon = [Vector2(0, -11), Vector2(2, -2), Vector2(11, 0), Vector2(2, 2), Vector2(0, 11), Vector2(-2, 2), Vector2(-11, 0), Vector2(-2, -2)]
		add_child(spark)

func _play_land_flash() -> void:
	_landing = true
	# Pop in from above — drop feels physical.
	var land_scale := Vector2(1.35, 1.35) if _is_stone() else Vector2(1.25, 1.25)
	scale = Vector2(0.35, 0.35)
	modulate.a = 0.4
	if _is_stone():
		modulate = Color(1.35, 1.2, 0.75, 0.4)
	var pop := create_tween()
	pop.tween_property(self, "scale", land_scale, 0.1).set_trans(Tween.TRANS_BACK)
	pop.tween_property(self, "scale", Vector2.ONE, 0.08)
	pop.parallel().tween_property(self, "modulate", Color.WHITE, 0.12)
	pop.tween_callback(func() -> void: _landing = false)
	if _is_stone():
		_spawn_stone_land_flash()
	else:
		_spawn_land_ring()

func _spawn_stone_land_flash() -> void:
	# Warm-gold diamond land — spirit stones must shout louder than generic loot.
	if _land_ring and is_instance_valid(_land_ring):
		_land_ring.queue_free()
	_land_ring = Node2D.new()
	_land_ring.z_index = -2
	add_child(_land_ring)
	var gold := Color(1.0, 0.88, 0.38, 0.95)
	# Diamond pad — same family as chest loot language.
	var pad := Polygon2D.new()
	pad.color = Color(1.0, 0.82, 0.32, 0.4)
	pad.polygon = PackedVector2Array([
		Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0),
	])
	_land_ring.add_child(pad)
	# Double expanding rings.
	for ring_i in 2:
		var line := Line2D.new()
		line.width = 2.4 - float(ring_i) * 0.4
		line.default_color = Color(1.0, 0.9 - float(ring_i) * 0.05, 0.4, 0.95 - float(ring_i) * 0.12)
		var r := 9.0 + float(ring_i) * 4.0
		for i in 21:
			var a := TAU * float(i) / 20.0
			line.add_point(Vector2(cos(a), sin(a)) * r)
		_land_ring.add_child(line)
	_land_ring.scale = Vector2(0.35, 0.35)
	var tw := create_tween()
	tw.tween_property(_land_ring, "scale", Vector2(2.0, 2.0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_land_ring, "modulate:a", 0.0, 0.24)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_land_ring):
			_land_ring.queue_free()
			_land_ring = null
	)
	# Soft rising flecks — treasure dust without clutter.
	var parent := get_parent()
	if parent == null:
		return
	for i in 3:
		var fleck := Polygon2D.new()
		fleck.z_index = 6
		fleck.color = Color(1.0, 0.94, 0.55, 0.85)
		fleck.polygon = PackedVector2Array([
			Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(1.4, 1.4), Vector2(-1.4, 1.4),
		])
		parent.add_child(fleck)
		var ang := TAU * float(i) / 3.0 + 0.5
		fleck.global_position = global_position + Vector2.from_angle(ang) * 5.0
		var ftw := fleck.create_tween()
		ftw.tween_interval(float(i) * 0.025)
		ftw.tween_property(fleck, "global_position", fleck.global_position + Vector2.from_angle(ang) * 12.0 + Vector2(0, -10), 0.26)
		ftw.parallel().tween_property(fleck, "modulate:a", 0.0, 0.26)
		ftw.tween_callback(fleck.queue_free)

func _spawn_land_ring() -> void:
	if _land_ring and is_instance_valid(_land_ring):
		_land_ring.queue_free()
	_land_ring = Node2D.new()
	_land_ring.z_index = -2
	add_child(_land_ring)
	var col := Color(1.0, 0.88, 0.4, 0.85)
	if _is_pill():
		col = Color(0.55, 0.95, 0.75, 0.8)
	elif _is_rare():
		var item := ContentDB.get_item(item_id)
		col = LootService.rarity_color(item.rarity if item else "rare")
		col.a = 0.9
	var line := Line2D.new()
	line.width = 2.2
	line.default_color = col
	var r := 10.0
	for i in 21:
		var a := TAU * float(i) / 20.0
		line.add_point(Vector2(cos(a), sin(a)) * r)
	_land_ring.add_child(line)
	# Soft gold fill flash under the orb.
	var fill := Polygon2D.new()
	fill.color = Color(col.r, col.g, col.b, 0.28)
	var pts: PackedVector2Array = []
	for i in 16:
		var a2 := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a2), sin(a2)) * r)
	fill.polygon = pts
	_land_ring.add_child(fill)
	_land_ring.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(_land_ring, "scale", Vector2(1.8, 1.8), 0.22).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(line, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(fill, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_land_ring):
			_land_ring.queue_free()
			_land_ring = null
	)

func _physics_process(delta: float) -> void:
	if item_id.is_empty() or _collected:
		return
	_pulse += delta * (9.0 if (_is_stone() or _is_rare()) else 5.5)
	if not _sucking and not _landing:
		var s := 1.0 + sin(_pulse) * (0.16 if _is_stone() or _is_rare() else 0.1)
		scale = Vector2(s, s) * (1.12 if _is_stone() or _is_rare() else 1.0)
	if has_node("Spark"):
		$Spark.rotation += delta * 2.8
		$Spark.modulate.a = 0.5 + 0.35 * sin(_pulse * 1.4)
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var magnet := float(ContentDB.section("combat").get("item_magnet", 72))
	if _is_stone():
		magnet *= 1.15
	var dist := global_position.distance_to(player.global_position)
	if dist < magnet:
		_sucking = true
		var speed := 280.0 + (80.0 if _is_stone() else 0.0)
		# Accelerate as it nears — crisp inhale.
		speed *= 1.0 + clampf(1.0 - dist / magnet, 0.0, 1.0) * 1.4
		global_position = global_position.move_toward(player.global_position, speed * delta)
		# Stretch toward player — suck reads without extra particles.
		var dir := player.global_position - global_position
		if dir.length_squared() > 4.0:
			var stretch := clampf(dir.length() / 60.0, 0.0, 0.45)
			var ang := dir.angle()
			rotation = ang
			scale = Vector2(1.0 + stretch, 1.0 - stretch * 0.45)
	else:
		_sucking = false
		rotation = 0.0
	if dist < 16.0:
		_collect(player)

func _collect(player: Node2D) -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	var item := ContentDB.get_item(item_id)
	var tip := ""
	var col := Color(1.0, 0.9, 0.5)
	if _is_stone():
		tip = "+%d石" % amount
		col = Color(1.0, 0.92, 0.45)
	elif item:
		if item.rarity in ["rare", "epic", "legendary"] or _is_pill():
			tip = "+%s" % item.display_name
			col = LootService.rarity_color(item.rarity)
		else:
			tip = "+1"
			col = Color(0.9, 0.95, 0.85)
	if not tip.is_empty():
		FloatTextManager.show_message(global_position + Vector2(0, -18), tip, col)
	# Collect flash at player feet.
	_spawn_collect_flash(player.global_position if player else global_position, col)
	if SfxService:
		SfxService.play_pickup()
	GameState.grant_item(item_id, amount)
	# Snap shrink into the player.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.15, 0.15), 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)

func _spawn_collect_flash(pos: Vector2, col: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	if _is_stone():
		# Absorb pop — warm-gold diamond at the hero (pairs land flash).
		var pad := Polygon2D.new()
		pad.z_index = 21
		pad.color = Color(1.0, 0.86, 0.38, 0.5)
		pad.polygon = PackedVector2Array([
			Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0),
		])
		parent.add_child(pad)
		pad.global_position = pos + Vector2(0, 4)
		pad.scale = Vector2(0.4, 0.4)
		var ptw := pad.create_tween()
		ptw.tween_property(pad, "scale", Vector2(1.7, 1.7), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(pad, "modulate:a", 0.0, 0.14)
		ptw.tween_callback(pad.queue_free)
		var ring := Line2D.new()
		ring.width = 2.3
		ring.default_color = Color(1.0, 0.92, 0.45, 0.95)
		ring.z_index = 22
		ring.global_position = pos
		for i in 17:
			var a := TAU * float(i) / 16.0
			ring.add_point(Vector2(cos(a), sin(a)) * 9.0)
		parent.add_child(ring)
		ring.scale = Vector2(0.45, 0.45)
		var tw := ring.create_tween()
		tw.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.16)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
		tw.tween_callback(ring.queue_free)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("flash_chest_edges") and amount >= 3:
			# Louder purse kick only on chunky stone piles.
			hud.call("flash_chest_edges")
		return
	var ring2 := Line2D.new()
	ring2.width = 2.0
	ring2.default_color = Color(col.r, col.g, col.b, 0.95)
	ring2.z_index = 22
	ring2.global_position = pos
	for i in 17:
		var a2 := TAU * float(i) / 16.0
		ring2.add_point(Vector2(cos(a2), sin(a2)) * 8.0)
	parent.add_child(ring2)
	ring2.scale = Vector2(0.5, 0.5)
	var tw2 := ring2.create_tween()
	tw2.tween_property(ring2, "scale", Vector2(1.8, 1.8), 0.16)
	tw2.parallel().tween_property(ring2, "modulate:a", 0.0, 0.16)
	tw2.tween_callback(ring2.queue_free)

func _is_rare() -> bool:
	var item := ContentDB.get_item(item_id)
	return item != null and item.rarity in ["rare", "epic", "legendary"]
