extends CharacterBody2D

const _Combat := preload("res://src/core/combat.gd")

var def: EnemyDef
var hp: int = 1
var _contact_cd := 0.0
var _visual: Sprite2D
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 8
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING


func setup(enemy: EnemyDef) -> void:
	def = enemy
	hp = enemy.hp
	_visual = $Visual
	_shape = $CollisionShape2D
	var radius := maxf(def.size + 2.0, 6.0)
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	var tex_path := "res://assets/characters/%s" % def.sprite
	var tex: Texture2D = load(tex_path)
	if tex:
		_visual.texture = tex
	_visual.scale = Vector2(def.sprite_scale, def.sprite_scale)
	_visual.modulate = Color.from_string(def.color, Color.WHITE)


func _physics_process(delta: float) -> void:
	if def == null:
		return
	if GameState.dead:
		velocity = Vector2.ZERO
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var offset := player.global_position - global_position
	if offset.length_squared() > 0.01:
		velocity = offset.normalized() * def.speed
		_visual.flip_h = offset.x < 0.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if _contact_cd > 0.0:
		_contact_cd -= delta
		return
	if offset.length() <= def.size + 12.0 and player.has_method("take_hit"):
		player.take_hit(_Combat.hit_damage(def.attack, GameState.cultivation.defense))
		_contact_cd = float(ContentDB.section("combat").get("contact_cooldown", 0.55))


func take_damage(amount: int) -> void:
	hp -= amount
	modulate = Color(1.4, 1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.register_kill(def.id)
	var orb := preload("res://scenes/world/essence.tscn").instantiate()
	orb.global_position = global_position
	orb.amount = def.xp_attack
	var pickups := get_tree().get_first_node_in_group("pickups")
	if pickups:
		pickups.add_child(orb)
	else:
		get_parent().add_child(orb)
	queue_free()
