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
var _skill_cd := 0.0
var _telegraph: Node2D
var _casting := false

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
	_skill_cd = 1.2
	_casting = false
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
	if def.is_boss and not def.boss_skill.is_empty():
		_boss_skill_tick(delta, player)
	if _casting:
		velocity = Vector2.ZERO
		move_and_slide()
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

func _boss_skill_tick(delta: float, player: Node2D) -> void:
	if _casting:
		return
	_skill_cd -= delta
	if _skill_cd > 0.0:
		return
	_skill_cd = float(def.boss_skill.get("cooldown", 4.0))
	_start_skill(player)

func _start_skill(player: Node2D) -> void:
	_casting = true
	var skill: Dictionary = def.boss_skill
	var sid := str(skill.get("id", "aoe_ring"))
	var telegraph := float(skill.get("telegraph", 0.8))
	match sid:
		"dash_strike":
			_telegraph_line(player.global_position, telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self) or GameState.dead:
				_casting = false
				return
			var dest: Vector2 = player.global_position
			global_position = global_position.lerp(dest, 0.85)
			if player.has_method("take_hit"):
				player.take_hit(int(skill.get("damage", 18)))
			_clear_telegraph()
		"summon":
			_telegraph_ring(float(skill.get("radius", 70)), telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self):
				return
			_do_summon(skill)
			_clear_telegraph()
		"spread_shots":
			_telegraph_ring(60.0, telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self):
				return
			_do_spread(skill, player)
			_clear_telegraph()
		"void_pull":
			var r := float(skill.get("radius", 120))
			_telegraph_ring(r, telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self) or not is_instance_valid(player):
				_casting = false
				return
			var pull := float(skill.get("pull", 50))
			var away := player.global_position - global_position
			if away.length() < r and away.length() > 1.0:
				player.global_position -= away.normalized() * pull
				if player.has_method("take_hit"):
					player.take_hit(int(skill.get("damage", 16)))
			_clear_telegraph()
		_:
			var radius := float(skill.get("radius", 90))
			_telegraph_ring(radius, telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self):
				return
			if is_instance_valid(player) and player.global_position.distance_to(global_position) <= radius:
				if player.has_method("take_hit"):
					player.take_hit(int(skill.get("damage", 14)))
			_clear_telegraph()
	_casting = false

func _telegraph_ring(radius: float, _duration: float) -> void:
	_clear_telegraph()
	_telegraph = Node2D.new()
	add_child(_telegraph)
	var ring := ColorRect.new()
	ring.size = Vector2(radius * 2.0, radius * 2.0)
	ring.position = Vector2(-radius, -radius)
	ring.color = Color(1.0, 0.35, 0.25, 0.28)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telegraph.add_child(ring)

func _telegraph_line(target: Vector2, _duration: float) -> void:
	_clear_telegraph()
	_telegraph = Node2D.new()
	add_child(_telegraph)
	var line := ColorRect.new()
	var dir := target - global_position
	var length := clampf(dir.length(), 40.0, 180.0)
	line.size = Vector2(length, 14)
	line.position = Vector2(0, -7)
	line.rotation = dir.angle()
	line.color = Color(1.0, 0.45, 0.2, 0.35)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telegraph.add_child(line)

func _clear_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null

func _do_summon(skill: Dictionary) -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("spawn_enemy_at"):
		return
	var eid := str(skill.get("enemy_id", "dust_worm"))
	var count := int(skill.get("count", 3))
	for i in count:
		var ang := TAU * float(i) / float(count)
		world.spawn_enemy_at(eid, global_position + Vector2.from_angle(ang) * 48.0, false)

func _do_spread(skill: Dictionary, player: Node2D) -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null:
		return
	var projs: Node2D = world.get_node_or_null("Projectiles")
	if projs == null:
		return
	var count := int(skill.get("count", 6))
	var dmg := int(skill.get("damage", 12))
	var base_ang := (player.global_position - global_position).angle()
	for i in count:
		var ang := base_ang + (float(i) - float(count - 1) * 0.5) * 0.28
		var bolt := preload("res://scenes/world/projectile.tscn").instantiate()
		projs.add_child(bolt)
		if bolt.has_method("launch_hostile"):
			bolt.launch_hostile(global_position, Vector2.from_angle(ang), dmg)
		elif bolt.has_method("launch"):
			# Fallback: still spawn visual; damage via nearby tick is skipped.
			bolt.launch(global_position, Vector2.from_angle(ang), 0.01)

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
		var world := get_tree().get_first_node_in_group("game_world")
		if world and world.has_method("on_boss_defeated"):
			world.on_boss_defeated(def.id)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	_clear_telegraph()
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.25, 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
