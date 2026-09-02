extends CharacterBody2D
const _Combat := preload("res://src/core/combat.gd")
var def: EnemyDef
var hp: int = 1
var max_hp: int = 1
var is_elite: bool = false
var _contact_cd := 0.0
var _visual: Sprite2D
var _shape: CollisionShape2D
var _hp_bar: ColorRect
var _hp_bg: ColorRect
var _hp_bar_width := 24.0

func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 8
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING

func setup(enemy: EnemyDef) -> void:
	def = enemy
	max_hp = enemy.hp
	hp = max_hp
	is_elite = false
	_visual = $Visual
	_shape = $CollisionShape2D
	_hp_bar = $HpBar
	_hp_bg = $HpBarBg
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hp_bar_width = 36.0 if enemy.is_boss else 24.0
	if enemy.is_boss:
		add_to_group("boss_mob")
		_hp_bar.position.x = -_hp_bar_width * 0.5
		_hp_bg.position.x = -_hp_bar_width * 0.5
		_hp_bg.size.x = _hp_bar_width
		_hp_bar.size.x = _hp_bar_width
		_hp_bar.color = Color(1.0, 0.55, 0.35)
	var radius := maxf(def.size + 2.0, 7.0)
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	var tex_path := "res://assets/characters/%s" % def.sprite
	var tex: Texture2D = load(tex_path)
	if tex:
		_visual.texture = tex
	_visual.scale = Vector2(def.sprite_scale, def.sprite_scale)
	_visual.modulate = Color.from_string(def.color, Color.WHITE)
	_refresh_hp()
	if def.is_boss:
		EventBus.boss_hp_changed.emit(def.display_name, hp, max_hp)

func make_elite() -> void:
	if def == null or def.is_boss or is_elite:
		return
	is_elite = true
	var mult := float(ContentDB.section("combat").get("elite_hp_mult", 1.55))
	max_hp = int(float(max_hp) * mult)
	hp = max_hp
	modulate = Color(1.15, 1.05, 0.65)
	_hp_bar.color = Color(0.95, 0.75, 0.25)
	_refresh_hp()

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
		player.take_hit(_Combat.hit_damage(def.attack, GameState.effective_defense()))
		_contact_cd = float(ContentDB.section("combat").get("contact_cooldown", 0.55))

func take_damage(amount: int) -> void:
	hp -= amount
	_refresh_hp()
	if def != null and def.is_boss:
		EventBus.boss_hp_changed.emit(def.display_name, hp, max_hp)
	EventBus.damage_dealt.emit(global_position, amount, false)
	modulate = Color(1.4, 1.2, 1.2) if not is_elite else Color(1.5, 1.25, 0.7)
	var tw := create_tween()
	var restore := Color(1.15, 1.05, 0.65) if is_elite else Color.WHITE
	tw.tween_property(self, "modulate", restore, 0.08)
	if hp <= 0:
		_die()

func _refresh_hp() -> void:
	if _hp_bar == null or max_hp <= 0:
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.size.x = _hp_bar_width * ratio

func _die() -> void:
	if def != null and def.is_boss:
		EventBus.boss_hp_cleared.emit()
	var drops := LootService.roll_enemy_loot(def, GameState.stage_id)
	if is_elite:
		var bonus := float(ContentDB.section("combat").get("elite_loot_chance_bonus", 0.15))
		if randf() < bonus:
			drops.append({ "item_id": "white_pill", "amount": 1 })
	GameState.register_kill(def.id)
	var pickups := get_tree().get_first_node_in_group("pickups")
	var parent := pickups if pickups else get_parent()
	var orb := preload("res://scenes/world/essence.tscn").instantiate()
	orb.global_position = global_position + Vector2(-8, 0)
	orb.amount = def.xp_attack + (1 if is_elite else 0)
	parent.add_child(orb)
	for i in drops.size():
		var row: Dictionary = drops[i]
		var item_id := str(row.get("item_id", ""))
		var amount := int(row.get("amount", 1))
		if item_id.is_empty() or amount <= 0:
			continue
		var pickup := preload("res://scenes/world/item_pickup.tscn").instantiate()
		parent.add_child(pickup)
		pickup.global_position = global_position + Vector2(8 + i * 6, -4)
		if pickup.has_method("setup"):
			pickup.setup(item_id, amount)
	if def.is_boss:
		GameState.add_spirit_stones(int(ContentDB.section("loot").get("boss_stone_reward", 40)))
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.25, 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
