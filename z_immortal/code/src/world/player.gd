extends CharacterBody2D

var bounds := Rect2(24, 24, 1000, 700)
var _attack_cd := 0.0
var _hurt_cd := 0.0
var _facing := Vector2.DOWN
var _projectiles: Node2D

@onready var _visual: Sprite2D = $Visual


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1


func configure(projectiles: Node2D, map_rect: Rect2) -> void:
	_projectiles = projectiles
	bounds = map_rect


func _physics_process(delta: float) -> void:
	if GameState.dead:
		velocity = Vector2.ZERO
		return
	var cbt := ContentDB.section("combat")
	var speed := float(cbt.get("player_speed", 96))
	var direction := _move_axis()
	if direction != Vector2.ZERO:
		_facing = direction
		_visual.flip_h = direction.x < 0.0
	velocity = direction * speed
	move_and_slide()
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)
	if _hurt_cd > 0.0:
		_hurt_cd -= delta
	_attack_cd -= delta
	if _attack_cd <= 0.0 and _try_fire():
		_attack_cd = float(cbt.get("auto_attack_interval", 0.42))


func take_hit(amount: int) -> void:
	if GameState.dead or _hurt_cd > 0.0:
		return
	GameState.apply_hurt(amount)
	_hurt_cd = float(ContentDB.section("combat").get("hurt_iframes", 0.35))
	modulate = Color(1.0, 0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)


func _try_fire() -> bool:
	if _projectiles == null:
		return false
	var target := _nearest_mob()
	if target == null:
		return false
	var dir := target.global_position - global_position
	if dir.length_squared() < 0.01:
		dir = _facing
	var bolt := preload("res://scenes/world/projectile.tscn").instantiate()
	_projectiles.add_child(bolt)
	bolt.launch(global_position, dir.normalized())
	return true


func _nearest_mob() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var d := global_position.distance_squared_to((node as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_stage_select()
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_J):
		GameState.cultivate_attack()
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_K):
		GameState.try_breakthrough()
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_R):
		GameState.revive()
		get_viewport().set_input_as_handled()


func _move_axis() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir.normalized()


func _is_key(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == key
