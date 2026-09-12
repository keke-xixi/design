extends Area2D

var _dir := Vector2.RIGHT
var _life := 0.85
var _speed := 240.0
var _damage_mult := 1.0
var _hostile := false
var _flat_damage := 0

func _ready() -> void:
	collision_layer = 16
	collision_mask = 8
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	call_deferred("_enable_sensing")

func _enable_sensing() -> void:
	set_deferred("monitoring", true)

func launch(from: Vector2, dir: Vector2, damage_mult: float = 1.0) -> void:
	_hostile = false
	global_position = from
	_dir = dir.normalized()
	_damage_mult = damage_mult
	rotation = _dir.angle()
	var cbt := ContentDB.section("combat")
	_speed = float(cbt.get("projectile_speed", 240))
	_life = float(cbt.get("projectile_lifetime", 0.85))
	set_deferred("collision_mask", 8)

func launch_hostile(from: Vector2, dir: Vector2, flat_damage: int) -> void:
	_hostile = true
	_flat_damage = flat_damage
	global_position = from
	_dir = dir.normalized()
	rotation = _dir.angle()
	var cbt := ContentDB.section("combat")
	_speed = float(cbt.get("projectile_speed", 240)) * 0.85
	_life = float(cbt.get("projectile_lifetime", 0.85)) * 1.2
	set_deferred("collision_mask", 2)
	modulate = Color(1.0, 0.45, 0.55)

func _physics_process(delta: float) -> void:
	position += _dir * _speed * delta
	_life -= delta
	# Soft trail — every 3rd frame to cut particle spam stutter.
	if Engine.get_process_frames() % 3 == 0:
		_spawn_trail()
	if _life <= 0.0:
		queue_free()

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var bit := Polygon2D.new()
	bit.polygon = [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]
	bit.color = Color(0.75, 0.95, 1.0, 0.55) if not _hostile else Color(1.0, 0.5, 0.45, 0.5)
	bit.global_position = global_position
	parent.add_child(bit)
	var tw := bit.create_tween()
	tw.tween_property(bit, "modulate:a", 0.0, 0.12)
	tw.tween_callback(bit.queue_free)

func _on_body_entered(body: Node) -> void:
	if _hostile:
		if body.is_in_group("player") and body.has_method("take_hit"):
			body.take_hit(_flat_damage)
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
		body.call("take_damage", GameState.projectile_damage_against(defense, _damage_mult), knock)
	call_deferred("_retire")

func _retire() -> void:
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	monitoring = false
	queue_free()
