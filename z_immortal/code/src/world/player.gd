extends CharacterBody2D

const SPEED := 90.0

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	_visual.color = Color("e6d7a2")


func _physics_process(_delta: float) -> void:
	var direction := _move_axis()
	velocity = direction * SPEED
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or _is_key(event, KEY_J):
		GameState.cultivate_attack()
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_K):
		GameState.try_breakthrough()
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
