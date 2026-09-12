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
var _knockback := Vector2.ZERO
var _charge_cd := 0.0
var _charging := false
var _charge_dir := Vector2.ZERO
var _ranged_cd := 0.0

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
	_knockback = Vector2.ZERO
	_charge_cd = randf_range(0.8, 1.6)
	_charging = false
	_ranged_cd = randf_range(0.6, 1.4)
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
	var tint := Color.from_string(def.color, Color.WHITE)
	# Distinguish shared base sprites by role.
	if "guard" in def.id or "general" in def.id:
		tint = tint * Color(0.78, 0.88, 1.05)
	elif "bandit" in def.id:
		tint = tint * Color(1.05, 0.9, 0.78)
	elif "elder" in def.id:
		tint = tint * Color(1.08, 0.95, 0.82)
	elif "beast" in def.id or "hare" in def.id or "worm" in def.id or "tyrant" in def.id or "matriarch" in def.id or "overlord" in def.id:
		tint = tint * Color(0.95, 1.05, 0.9)
	_visual.modulate = tint
	# Soft outline for readability on busy backgrounds.
	if get_node_or_null("Outline") == null and _visual.texture != null:
		var outline := Sprite2D.new()
		outline.name = "Outline"
		outline.texture = _visual.texture
		outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		outline.scale = _visual.scale * 1.03
		outline.modulate = Color(0.04, 0.05, 0.08, 0.4)
		outline.z_index = -1
		outline.position = _visual.position + Vector2(0, 1)
		add_child(outline)
	if def.is_boss:
		# Soft boss aura ring.
		if get_node_or_null("BossAura") == null:
			var aura := Polygon2D.new()
			aura.name = "BossAura"
			aura.z_index = -2
			aura.color = Color(1.0, 0.55, 0.3, 0.18)
			var pts: PackedVector2Array = []
			for i in 20:
				var a := TAU * float(i) / 20.0
				pts.append(Vector2(cos(a), sin(a)) * (def.size + 14.0))
			aura.polygon = pts
			add_child(aura)
	var shadow := get_node_or_null("Shadow") as Polygon2D
	if shadow:
		var s := 1.0 + def.size * 0.04
		if def.is_boss:
			s *= 1.6
		shadow.scale = Vector2(s, s)
	# Spawn pop.
	scale = Vector2(0.7, 0.7)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
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
	# Gold crown mark.
	var mark := Polygon2D.new()
	mark.name = "EliteMark"
	mark.color = Color(1.0, 0.85, 0.35, 0.9)
	mark.polygon = [Vector2(-4, -18), Vector2(0, -24), Vector2(4, -18), Vector2(2, -16), Vector2(-2, -16)]
	add_child(mark)
	_refresh_hp()

var _bob := 0.0

func _physics_process(delta: float) -> void:
	if def == null:
		return
	z_index = int(global_position.y)
	if _visual:
		_bob += delta * 5.5
		var bob_y := -4.0 + sin(_bob + float(get_instance_id() % 7)) * 1.2
		_visual.position.y = bob_y
		var outline := get_node_or_null("Outline") as Sprite2D
		if outline:
			outline.position.y = bob_y + 1.0
			outline.flip_h = _visual.flip_h
		var mark := get_node_or_null("EliteMark") as Node2D
		if mark:
			mark.position.y = bob_y - 16.0
		var aura := get_node_or_null("BossAura") as CanvasItem
		if aura:
			aura.modulate.a = 0.55 + 0.35 * sin(_bob * 0.8)
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
	if _knockback.length_squared() > 4.0:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 480.0 * delta)
		move_and_slide()
		return
	# Face player lightly.
	if _visual and player.global_position.x < global_position.x - 2.0:
		_visual.flip_h = true
	elif _visual and player.global_position.x > global_position.x + 2.0:
		_visual.flip_h = false
	_ai_move(delta, player)
	move_and_slide()
	if _contact_cd > 0.0:
		_contact_cd -= delta
		return
	var offset := player.global_position - global_position
	if offset.length() <= def.size + 12.0 and player.has_method("take_hit"):
		player.take_hit(_Combat.hit_damage(def.attack, GameState.effective_defense()))
		_contact_cd = float(ContentDB.section("combat").get("contact_cooldown", 0.55))
		if SfxService:
			SfxService.play_hurt()

func _ai_move(delta: float, player: Node2D) -> void:
	var offset := player.global_position - global_position
	var dist := offset.length()
	var ai := def.ai if def else "chase"
	match ai:
		"ranged":
			_ranged_cd -= delta
			if dist < 70.0:
				velocity = -offset.normalized() * def.speed
			elif dist > 130.0:
				velocity = offset.normalized() * def.speed * 0.85
			else:
				velocity = offset.normalized().orthogonal() * def.speed * 0.55
			if offset.length_squared() > 0.01:
				_visual.flip_h = offset.x < 0.0
			if _ranged_cd <= 0.0:
				_ranged_cd = float(ContentDB.section("combat").get("ranged_cooldown", 1.35))
				_fire_at(player)
		"charge":
			_charge_cd -= delta
			if _charging:
				velocity = _charge_dir * def.speed * 2.4
				_charge_cd -= delta
				if _charge_cd <= 0.0:
					_charging = false
					_charge_cd = randf_range(1.4, 2.2)
			elif _charge_cd <= 0.0 and dist < 160.0:
				_charging = true
				_charge_dir = offset.normalized() if dist > 1.0 else Vector2.RIGHT
				_charge_cd = 0.35
				modulate = Color(1.3, 0.9, 0.7)
				_spawn_charge_warn()
				var tw := create_tween()
				tw.tween_property(self, "modulate", Color.WHITE if not is_elite else Color(1.15, 1.05, 0.65), 0.2)
			else:
				velocity = offset.normalized() * def.speed if dist > 1.0 else Vector2.ZERO
			if offset.length_squared() > 0.01:
				_visual.flip_h = offset.x < 0.0
		_:
			if offset.length_squared() > 0.01:
				velocity = offset.normalized() * def.speed
				_visual.flip_h = offset.x < 0.0
			else:
				velocity = Vector2.ZERO

func _spawn_charge_warn() -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(1.0, 0.55, 0.3, 0.7)
	line.add_point(Vector2.ZERO)
	line.add_point(_charge_dir * 70.0)
	add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.28)
	tw.tween_callback(line.queue_free)

func _fire_at(player: Node2D) -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null:
		return
	var projs: Node2D = world.get_node_or_null("Projectiles")
	if projs == null:
		return
	var dir := (player.global_position - global_position).normalized()
	var bolt := preload("res://scenes/world/projectile.tscn").instantiate()
	projs.add_child(bolt)
	var dmg := maxi(_Combat.hit_damage(def.attack, GameState.effective_defense()) - 1, 1)
	if bolt.has_method("launch_hostile"):
		bolt.launch_hostile(global_position, dir, dmg)

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
	var fill := Polygon2D.new()
	fill.color = Color(1.0, 0.28, 0.2, 0.22)
	var pts: PackedVector2Array = []
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	fill.polygon = pts
	_telegraph.add_child(fill)
	var rim := Line2D.new()
	rim.width = 2.0
	rim.default_color = Color(1.0, 0.55, 0.35, 0.85)
	for i in 33:
		var a2 := TAU * float(i) / 32.0
		rim.add_point(Vector2(cos(a2), sin(a2)) * radius)
	_telegraph.add_child(rim)
	fill.scale = Vector2(0.55, 0.55)
	var tw := fill.create_tween()
	tw.tween_property(fill, "scale", Vector2.ONE, 0.25)

func _telegraph_line(target: Vector2, _duration: float) -> void:
	_clear_telegraph()
	_telegraph = Node2D.new()
	add_child(_telegraph)
	var dir := target - global_position
	var length := clampf(dir.length(), 40.0, 180.0)
	var line := Line2D.new()
	line.width = 10.0
	line.default_color = Color(1.0, 0.4, 0.25, 0.55)
	line.add_point(Vector2.ZERO)
	line.add_point(dir.normalized() * length)
	_telegraph.add_child(line)
	var tip := Polygon2D.new()
	tip.color = Color(1.0, 0.7, 0.35, 0.8)
	tip.polygon = [Vector2(-6, -5), Vector2(8, 0), Vector2(-6, 5)]
	tip.position = dir.normalized() * length
	tip.rotation = dir.angle()
	_telegraph.add_child(tip)

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

func take_damage(amount: int, knock_dir: Vector2 = Vector2.ZERO) -> void:
	hp -= amount
	_refresh_hp()
	if def != null and def.is_boss:
		EventBus.boss_hp_changed.emit(def.display_name, hp, max_hp)
	EventBus.damage_dealt.emit(global_position, amount, false)
	if SfxService:
		SfxService.play_hit()
	var kb := float(ContentDB.section("combat").get("knockback", 90))
	if knock_dir.length_squared() > 0.01:
		_knockback = knock_dir.normalized() * kb * (0.45 if def and def.is_boss else 1.0)
	modulate = Color(1.5, 1.25, 1.2) if not is_elite else Color(1.55, 1.3, 0.75)
	var base_scale := scale
	var tw := create_tween()
	var restore := Color(1.15, 1.05, 0.65) if is_elite else Color.WHITE
	tw.tween_property(self, "scale", base_scale * 1.12, 0.04)
	tw.tween_property(self, "scale", base_scale, 0.06)
	tw.parallel().tween_property(self, "modulate", restore, 0.1)
	# Micro hitstop only for heavy hits — avoids combat stutter.
	var min_hs := float(ContentDB.section("combat").get("hitstop_min_damage", 18))
	if amount >= min_hs or (def != null and def.is_boss) or is_elite:
		var world := get_tree().get_first_node_in_group("game_world")
		if world and world.has_method("hitstop"):
			world.hitstop(0.02 if amount < 28 else 0.035)
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
	if SfxService:
		SfxService.play_kill()
	if def != null and def.is_boss:
		FloatTextManager.show_message(global_position + Vector2(0, -36), "斩Boss", Color(1.0, 0.72, 0.35))
	elif is_elite:
		FloatTextManager.show_message(global_position + Vector2(0, -28), "精英", Color(1.0, 0.88, 0.45))
	GameState.register_kill(def.id)
	_spawn_burst()
	call_deferred("_spawn_drops")
	if def.is_boss:
		GameState.add_spirit_stones(int(ContentDB.section("loot").get("boss_stone_reward", 40)))
		var world := get_tree().get_first_node_in_group("game_world")
		if world and world.has_method("on_boss_defeated"):
			world.on_boss_defeated(def.id)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("pulse_camera"):
		player.pulse_camera(0.08 if not def.is_boss else 0.18)
	if def != null and (def.is_boss or is_elite):
		var world2 := get_tree().get_first_node_in_group("game_world")
		if world2 and world2.has_method("hitstop"):
			world2.hitstop(0.04 if is_elite else 0.055)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	call_deferred("set_physics_process", false)
	_clear_telegraph()
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.35, 0.07)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)

func _spawn_drops() -> void:
	if def == null or not is_inside_tree():
		return
	var drops := LootService.roll_enemy_loot(def, GameState.stage_id)
	if is_elite:
		var bonus := float(ContentDB.section("combat").get("elite_loot_chance_bonus", 0.15))
		if randf() < bonus:
			drops.append({ "item_id": "white_pill", "amount": 1 })
	var pickups := get_tree().get_first_node_in_group("pickups")
	var parent := pickups if pickups else get_parent()
	if parent == null:
		return
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

func _spawn_burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var count := 8 if (def != null and def.is_boss) else (6 if is_elite else 5)
	for i in count:
		var bit := Polygon2D.new()
		bit.polygon = [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]
		if def != null and def.is_boss:
			bit.color = Color(1.0, 0.65, 0.3, 0.95)
		elif is_elite:
			bit.color = Color(1.0, 0.88, 0.4, 0.95)
		else:
			bit.color = Color(0.85, 0.95, 0.7, 0.9)
		bit.global_position = global_position
		bit.z_index = 12
		parent.add_child(bit)
		var dir := Vector2.from_angle(TAU * float(i) / float(count) + randf() * 0.25)
		var tw := bit.create_tween()
		tw.tween_property(bit, "global_position", global_position + dir * randf_range(20, 40), 0.2)
		tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.2)
		tw.tween_callback(bit.queue_free)
