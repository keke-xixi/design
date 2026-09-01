extends Area2D

var _dir := Vector2.RIGHT
var _life := 0.85
var _speed := 240.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 8
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func launch(from: Vector2, dir: Vector2) -> void:
	global_position = from
	_dir = dir.normalized()
	rotation = _dir.angle()
	var cbt := ContentDB.section("combat")
	_speed = float(cbt.get("projectile_speed", 240))
	_life = float(cbt.get("projectile_lifetime", 0.85))


func _physics_process(delta: float) -> void:
	position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("mobs"):
		return
	if body.has_method("take_damage"):
		var defense := 0
		var enemy_def: Variant = body.get("def")
		if enemy_def != null:
			defense = int(enemy_def.defense)
		body.take_damage(GameState.projectile_damage_against(defense))
	queue_free()
