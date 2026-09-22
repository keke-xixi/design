extends Area2D

var _dir := Vector2.RIGHT
var _life := 0.85
var _speed := 240.0
var _damage_mult := 1.0
var _hostile := false
var _flat_damage := 0
var _style := "normal" # normal | burst
var _trail_acc := 0.0
var _last_pos := Vector2.ZERO

func _ready() -> void:
	collision_layer = 16
	collision_mask = 8
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	call_deferred("_enable_sensing")

func _enable_sensing() -> void:
	set_deferred("monitoring", true)

func launch(from: Vector2, dir: Vector2, damage_mult: float = 1.0, style: String = "normal") -> void:
	_hostile = false
	_style = style
	global_position = from
	_last_pos = from
	_dir = dir.normalized()
	_damage_mult = damage_mult
	rotation = _dir.angle()
	var cbt := ContentDB.section("combat")
	_speed = float(cbt.get("projectile_speed", 240))
	_life = float(cbt.get("projectile_lifetime", 0.85))
	if _style == "burst":
		_speed *= 1.15
		_life *= 0.95
		_apply_burst_look()
	set_deferred("collision_mask", 8)

func _apply_burst_look() -> void:
	# Gold-ember bolts — reads apart from cyan auto-fire.
	modulate = Color(1.2, 0.95, 0.7)
	var vis := get_node_or_null("Visual") as Polygon2D
	var glow := get_node_or_null("Glow") as Polygon2D
	if vis:
		vis.color = Color(1.0, 0.85, 0.4, 1.0)
		vis.polygon = PackedVector2Array([22, 0, -7, 5, -2, 0, -7, -5])
	if glow:
		glow.color = Color(1.0, 0.55, 0.25, 0.65)
		glow.polygon = PackedVector2Array([24, 0, -12, 9, -12, -9])
	scale = Vector2(1.15, 1.15)

func launch_hostile(from: Vector2, dir: Vector2, flat_damage: int, style: String = "hostile") -> void:
	_hostile = true
	_style = style
	_flat_damage = flat_damage
	global_position = from
	_last_pos = from
	_dir = dir.normalized()
	rotation = _dir.angle()
	var cbt := ContentDB.section("combat")
	_speed = float(cbt.get("projectile_speed", 240)) * 0.85
	_life = float(cbt.get("projectile_lifetime", 0.85)) * 1.2
	set_deferred("collision_mask", 2)
	if _style == "scatter":
		# Boss 散矢 — hotter coral bolts, distinct from trash pink shots.
		_speed *= 1.05
		_life *= 1.05
		_apply_scatter_look()
	else:
		modulate = Color(1.0, 0.45, 0.55)

func _apply_scatter_look() -> void:
	modulate = Color(1.2, 0.7, 0.45)
	var vis := get_node_or_null("Visual") as Polygon2D
	var glow := get_node_or_null("Glow") as Polygon2D
	if vis:
		vis.color = Color(1.0, 0.55, 0.32, 1.0)
		vis.polygon = PackedVector2Array([20, 0, -6, 4.5, -1, 0, -6, -4.5])
	if glow:
		glow.color = Color(1.0, 0.4, 0.22, 0.6)
		glow.polygon = PackedVector2Array([22, 0, -10, 8, -10, -8])
	scale = Vector2(1.1, 1.1)

func _physics_process(delta: float) -> void:
	_last_pos = global_position
	position += _dir * _speed * delta
	_life -= delta
	_trail_acc += delta
	# Burst trails denser / longer — skill identity mid-swarm.
	var interval := 0.018 if _style == "burst" else (0.028 if _style == "scatter" else 0.04)
	if _trail_acc >= interval:
		_trail_acc = 0.0
		_spawn_trail()
	if _life <= 0.0:
		if _style == "burst":
			_spawn_hit_burst(global_position, false)
		elif _style == "scatter":
			# Miss / ground land — softer spark than body hit.
			_spawn_scatter_spark(global_position, false)
		queue_free()

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if _style == "burst":
		# Streak segment along the path — golden sword-qi ribbon.
		var streak := Line2D.new()
		streak.width = 2.8
		streak.default_color = Color(1.0, 0.82, 0.35, 0.85)
		streak.z_index = 4
		streak.add_point(_last_pos - global_position)
		streak.add_point(Vector2.ZERO)
		streak.global_position = global_position
		parent.add_child(streak)
		var glow := Polygon2D.new()
		glow.color = Color(1.0, 0.7, 0.3, 0.45)
		glow.polygon = PackedVector2Array([
			Vector2(-4, -2), Vector2(4, -2), Vector2(4, 2), Vector2(-4, 2),
		])
		glow.global_position = global_position
		glow.rotation = _dir.angle()
		parent.add_child(glow)
		var tw := streak.create_tween()
		tw.tween_property(streak, "modulate:a", 0.0, 0.18)
		tw.parallel().tween_property(streak, "width", 0.6, 0.18)
		tw.tween_callback(streak.queue_free)
		var twg := glow.create_tween()
		twg.tween_property(glow, "modulate:a", 0.0, 0.14)
		twg.parallel().tween_property(glow, "scale", Vector2(0.4, 0.4), 0.14)
		twg.tween_callback(glow.queue_free)
		return
	if _style == "scatter":
		# Coral ribbon — boss 散矢 identity mid-flight.
		var streak2 := Line2D.new()
		streak2.width = 2.4
		streak2.default_color = Color(1.0, 0.5, 0.32, 0.8)
		streak2.z_index = 4
		streak2.add_point(_last_pos - global_position)
		streak2.add_point(Vector2.ZERO)
		streak2.global_position = global_position
		parent.add_child(streak2)
		var tws := streak2.create_tween()
		tws.tween_property(streak2, "modulate:a", 0.0, 0.14)
		tws.parallel().tween_property(streak2, "width", 0.5, 0.14)
		tws.tween_callback(streak2.queue_free)
		return
	var bit := Polygon2D.new()
	bit.polygon = [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]
	if _hostile:
		bit.color = Color(1.0, 0.5, 0.45, 0.5)
	else:
		bit.color = Color(0.75, 0.95, 1.0, 0.55)
	bit.global_position = global_position
	parent.add_child(bit)
	var tw2 := bit.create_tween()
	tw2.tween_property(bit, "modulate:a", 0.0, 0.12)
	tw2.tween_callback(bit.queue_free)

func _spawn_hit_burst(at: Vector2, on_mob: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Crisp gold pop — burst hits must punch through combat clutter.
	var ring := Line2D.new()
	ring.width = 2.2 if on_mob else 1.6
	ring.default_color = Color(1.0, 0.85, 0.4, 0.95)
	ring.z_index = 14
	var r0 := 5.0 if on_mob else 4.0
	for i in 13:
		var a := TAU * float(i) / 12.0
		ring.add_point(Vector2(cos(a), sin(a)) * r0)
	parent.add_child(ring)
	ring.global_position = at
	ring.scale = Vector2(0.4, 0.4)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(2.4 if on_mob else 1.8, 2.4 if on_mob else 1.8), 0.14)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.14)
	tw.tween_callback(ring.queue_free)
	if on_mob:
		for k in 3:
			var shard := Line2D.new()
			shard.width = 1.8
			shard.default_color = Color(1.0, 0.9, 0.5, 0.95)
			shard.z_index = 15
			var ang := _dir.angle() + float(k - 1) * 0.55
			shard.add_point(Vector2.ZERO)
			shard.add_point(Vector2.from_angle(ang) * 10.0)
			parent.add_child(shard)
			shard.global_position = at
			var stw := shard.create_tween()
			stw.tween_property(shard, "modulate:a", 0.0, 0.16)
			stw.parallel().tween_property(shard, "scale", Vector2(1.6, 1.6), 0.16)
			stw.tween_callback(shard.queue_free)

func _spawn_auto_hit_spark(at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Dense gold flecks — auto-fire must feel crispy, not cyan-only.
	var combo := GameState.combo
	var shards := 2 + (1 if combo >= 3 else 0) + (1 if combo >= 6 else 0)
	var base_ang := _dir.angle()
	for k in shards:
		var shard := Line2D.new()
		shard.width = 1.7
		shard.default_color = Color(1.0, 0.9, 0.5, 0.95) if combo < 5 else Color(1.0, 0.78, 0.35, 1.0)
		shard.z_index = 13
		var ang := base_ang + float(k - shards * 0.5) * 0.5 + randf_range(-0.15, 0.15)
		var len := 6.0 + float(k) * 1.5
		shard.add_point(Vector2.ZERO)
		shard.add_point(Vector2.from_angle(ang) * len)
		parent.add_child(shard)
		shard.global_position = at + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		var stw := shard.create_tween()
		stw.tween_property(shard, "modulate:a", 0.0, 0.1 + float(k) * 0.02)
		stw.parallel().tween_property(shard, "scale", Vector2(1.4, 1.4), 0.1)
		stw.tween_callback(shard.queue_free)
	# Tiny gold cross at impact.
	var cross := Line2D.new()
	cross.width = 1.4
	cross.default_color = Color(1.0, 0.95, 0.7, 0.9)
	cross.z_index = 14
	cross.add_point(Vector2(-3, -3))
	cross.add_point(Vector2(3, 3))
	parent.add_child(cross)
	cross.global_position = at
	var ctw := cross.create_tween()
	ctw.tween_property(cross, "modulate:a", 0.0, 0.09)
	ctw.tween_callback(cross.queue_free)
	var cross2 := Line2D.new()
	cross2.width = 1.4
	cross2.default_color = Color(1.0, 0.88, 0.45, 0.85)
	cross2.z_index = 14
	cross2.add_point(Vector2(3, -3))
	cross2.add_point(Vector2(-3, 3))
	parent.add_child(cross2)
	cross2.global_position = at
	var ctw2 := cross2.create_tween()
	ctw2.tween_property(cross2, "modulate:a", 0.0, 0.09)
	ctw2.tween_callback(cross2.queue_free)

## Boss 散矢 impact — coral sparks, not player gold auto flecks.
func _spawn_scatter_spark(at: Vector2, on_player: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var base_ang := _dir.angle()
	var shards := 5 if on_player else 3
	for k in shards:
		var shard := Line2D.new()
		shard.width = 2.0 if on_player else 1.6
		shard.default_color = Color(1.0, 0.55, 0.3, 0.95) if on_player else Color(1.0, 0.48, 0.32, 0.8)
		shard.z_index = 14
		var ang := base_ang + PI + float(k - shards * 0.5) * 0.45 + randf_range(-0.12, 0.12)
		var len := (8.0 if on_player else 5.5) + float(k) * 1.2
		shard.add_point(Vector2.ZERO)
		shard.add_point(Vector2.from_angle(ang) * len)
		parent.add_child(shard)
		shard.global_position = at + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		var stw := shard.create_tween()
		stw.tween_property(shard, "modulate:a", 0.0, 0.12 + float(k) * 0.015)
		stw.parallel().tween_property(shard, "scale", Vector2(1.55, 1.55), 0.12)
		stw.tween_callback(shard.queue_free)
	# Hot core pop.
	var ring := Line2D.new()
	ring.width = 2.0 if on_player else 1.5
	ring.default_color = Color(1.0, 0.7, 0.35, 0.9 if on_player else 0.7)
	ring.z_index = 13
	var r0 := 4.5 if on_player else 3.2
	for i in 11:
		var a := TAU * float(i) / 10.0
		ring.add_point(Vector2(cos(a), sin(a)) * r0)
	parent.add_child(ring)
	ring.global_position = at
	ring.scale = Vector2(0.35, 0.35)
	var rtw := ring.create_tween()
	rtw.tween_property(ring, "scale", Vector2(2.2 if on_player else 1.6, 2.2 if on_player else 1.6), 0.12)
	rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.12)
	rtw.tween_callback(ring.queue_free)
	if on_player:
		# Ember flecks up — body hit reads louder than ground land.
		for i in 3:
			var mote := Polygon2D.new()
			mote.color = Color(1.0, 0.65, 0.3, 0.9)
			mote.z_index = 15
			mote.polygon = PackedVector2Array([
				Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5),
			])
			parent.add_child(mote)
			mote.global_position = at
			var mdir := Vector2.from_angle(base_ang + PI + float(i - 1) * 0.55) * randf_range(14.0, 22.0)
			var mtw := mote.create_tween()
			mtw.tween_property(mote, "position", mote.position + mdir, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			mtw.parallel().tween_property(mote, "modulate:a", 0.0, 0.16)
			mtw.tween_callback(mote.queue_free)

func _on_body_entered(body: Node) -> void:
	if _hostile:
		if body.is_in_group("player") and body.has_method("take_hit"):
			var from := global_position - _dir * 12.0
			body.take_hit(_flat_damage, from)
			if _style == "scatter":
				var at := (body as Node2D).global_position if body is Node2D else global_position
				_spawn_scatter_spark(at, true)
			call_deferred("_retire")
		return
	if not body.is_in_group("mobs"):
		return
	if body.has_method("take_damage"):
		var defense := 0
		var enemy_def: Variant = body.get("def")
		if enemy_def != null:
			defense = int(enemy_def.defense)
		var knock := _dir
		var dmg := GameState.projectile_damage_against(defense, _damage_mult)
		body.call("take_damage", dmg, knock)
		if body is Node2D:
			var at := (body as Node2D).global_position
			if _style == "burst":
				_spawn_hit_burst(at, true)
			else:
				# Normal auto-attack: gold sparks + micro hitch.
				_spawn_auto_hit_spark(at)
				var world := get_tree().get_first_node_in_group("game_world")
				if world and world.has_method("hitstop"):
					var hs := 0.012
					if GameState.combo >= 5:
						hs = 0.016
					if GameState.combo >= 8:
						hs = 0.02
					world.hitstop(hs)
	call_deferred("_retire")

func _retire() -> void:
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	monitoring = false
	queue_free()
