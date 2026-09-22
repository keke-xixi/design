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
var _recovering := false
var _recover_fx: Node2D
var _knockback := Vector2.ZERO
var _charge_cd := 0.0
var _charging := false
var _charge_dir := Vector2.ZERO
var _ranged_cd := 0.0
var _lunge_cd := 0.0
var _lunge_wind := 0.0
var _lunging := false
var _lunge_dir := Vector2.ZERO
var _hop_t := 0.0
var _orbit_sign := 1.0
## 灵兔侧啄 windup — jade arc tell before the hop-in (vs disciple steel blade).
var _peck_wind := 0.0
var _peck_dir := Vector2.ZERO
## Brief hard stun — set by 「迎刃」 so the punish window is fair.
var _stun_t := 0.0

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
	_recovering = false
	_knockback = Vector2.ZERO
	_charge_cd = randf_range(0.8, 1.6)
	_charging = false
	_ranged_cd = randf_range(0.6, 1.4)
	_lunge_cd = randf_range(0.7, 1.4)
	_lunge_wind = 0.0
	_lunging = false
	_hop_t = randf_range(0.1, 0.4)
	_orbit_sign = 1.0 if randf() > 0.5 else -1.0
	_peck_wind = 0.0
	_peck_dir = Vector2.ZERO
	_stun_t = 0.0
	_visual = $Visual
	_shape = $CollisionShape2D
	_hp_bar = $HpBar
	_hp_bg = $HpBarBg
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hp_bar_width = 36.0 if enemy.is_boss else 24.0
	if enemy.is_boss:
		add_to_group("boss_mob")
		# Breath before first skill so spawn shout + first tell can land.
		_skill_cd = 2.2
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
		if get_node_or_null("BossTitle") == null:
			var title := Label.new()
			title.name = "BossTitle"
			title.text = def.display_name
			title.add_theme_font_size_override("font_size", 10)
			title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
			title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
			title.add_theme_constant_override("shadow_offset_x", 1)
			title.add_theme_constant_override("shadow_offset_y", 1)
			title.position = Vector2(-28, -42)
			title.z_index = 8
			add_child(title)
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

## Brief warm-gold silhouette kick when elite lands (pairs world/HUD flash).
func pulse_elite_land() -> void:
	if not is_elite:
		return
	modulate = Color(1.45, 1.25, 0.7)
	var base := scale
	scale = base * 0.92
	var outline := get_node_or_null("Outline") as Sprite2D
	if outline:
		outline.modulate = Color(1.0, 0.86, 0.4, 0.85)
	var tw := create_tween()
	tw.tween_property(self, "scale", base * 1.08, 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", base, 0.14)
	tw.parallel().tween_property(self, "modulate", Color(1.15, 1.05, 0.65), 0.22)
	if outline and _visual:
		tw.parallel().tween_property(outline, "modulate", Color(0.04, 0.05, 0.08, 0.4), 0.28)
		tw.parallel().tween_property(outline, "scale", _visual.scale * 1.03, 0.28)

var _bob := 0.0

func _physics_process(delta: float) -> void:
	if def == null:
		return
	z_index = int(global_position.y)
	if _visual:
		_bob += delta * (8.2 if def.ai == "skittish" else 5.5)
		var hop_amp := 2.4 if def.ai == "skittish" else 1.2
		var bob_y := -4.0 + sin(_bob + float(get_instance_id() % 7)) * hop_amp
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
		var title := get_node_or_null("BossTitle") as Node2D
		if title:
			title.position.y = bob_y - 38.0
	if GameState.dead:
		velocity = Vector2.ZERO
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if def.is_boss and not def.boss_skill.is_empty():
		_boss_skill_tick(delta, player)
	if _casting or _recovering:
		# Telegraph + post-skill recover share a freeze — readable counter window.
		velocity = Vector2.ZERO
		if _recovering and _recover_fx and is_instance_valid(_recover_fx):
			_recover_fx.modulate.a = 0.55 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		move_and_slide()
		return
	if _stun_t > 0.0:
		# 迎刃 hard stun — countdown even while knockback slides, no contact chip.
		_stun_t -= delta
		_lunging = false
		_lunge_wind = 0.0
		_charging = false
		_pulse_stun_steel_outline()
		if _knockback.length_squared() > 4.0:
			velocity = _knockback
			_knockback = _knockback.move_toward(Vector2.ZERO, 480.0 * delta)
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		if _contact_cd > 0.0:
			_contact_cd -= delta
		if _stun_t <= 0.0:
			_restore_stun_steel_outline()
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
		# Pass self so HUD directional sting knows which side clipped.
		player.take_hit(_Combat.hit_damage(def.attack, GameState.effective_defense()), global_position)
		_contact_cd = float(ContentDB.section("combat").get("contact_cooldown", 0.55))
		# take_hit already plays hurt SFX — don't double-beep.

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
		"skittish":
			# 灵兔：绕圈起跳 → 侧啄预警 → 近身弹开。Jade arc tell ≠ disciple steel blade.
			_ai_hare_skittish(delta, offset, dist)
		"guard":
			# Patrol: keep mid range, step in for contact — reads different from disciples.
			if dist < 48.0:
				velocity = -offset.normalized() * def.speed * 0.9
			elif dist > 95.0:
				velocity = offset.normalized() * def.speed
			else:
				velocity = offset.normalized().orthogonal() * def.speed * 0.65
				if Engine.get_process_frames() % 55 == 0:
					velocity = offset.normalized() * def.speed * 1.35
			if offset.length_squared() > 0.01:
				_visual.flip_h = offset.x < 0.0
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
		"chase":
			# 外门弟子：贴身走位，亮刃前摇后再突刺 — 对位灵兔绕圈。
			_ai_disciple_lunge(delta, offset, dist)
		_:
			if offset.length_squared() > 0.01:
				velocity = offset.normalized() * def.speed
				_visual.flip_h = offset.x < 0.0
			else:
				velocity = Vector2.ZERO

func _ai_hare_skittish(delta: float, offset: Vector2, dist: float) -> void:
	if offset.length_squared() > 0.01:
		_visual.flip_h = offset.x < 0.0
	var side := offset.normalized().orthogonal() * _orbit_sign if offset.length_squared() > 0.01 else Vector2.RIGHT * _orbit_sign
	# Peck windup — plant on the arc, then hop-in (jade, not steel forward blade).
	if _peck_wind > 0.0:
		_peck_wind -= delta
		velocity = side * def.speed * 0.35
		if _visual and def:
			var squat := 0.88 + 0.08 * sin(Time.get_ticks_msec() * 0.05)
			_visual.scale = Vector2(def.sprite_scale * (2.05 - squat), def.sprite_scale * squat)
		if _peck_wind <= 0.0:
			_do_hare_hop()
			velocity = _peck_dir * def.speed * 1.7
			if _visual and def:
				_visual.scale = Vector2(def.sprite_scale, def.sprite_scale)
			_spawn_hop_pip(_peck_dir)
			if SfxService:
				SfxService.play_hare_peck()
		return
	_hop_t -= delta
	var hop := _hop_t <= 0.0
	if hop:
		_hop_t = randf_range(0.34, 0.5)
	if dist < 48.0:
		velocity = -offset.normalized() * def.speed * 1.4 + side * def.speed * 0.35
		if hop:
			_do_hare_hop()
	elif dist > 118.0:
		velocity = (offset.normalized() * 0.65 + side * 0.55).normalized() * def.speed
		if hop:
			_do_hare_hop()
	else:
		velocity = side * def.speed * 1.2
		if hop and dist < 96.0:
			# Arm side-peck — jade crescent warn, then hop after windup.
			_peck_dir = (offset.normalized() * 0.55 + side * 0.85).normalized()
			_peck_wind = 0.2
			_spawn_peck_warn(_peck_dir)
			modulate = Color(0.75, 1.15, 0.95)
			var tw := create_tween()
			tw.tween_property(self, "modulate", Color.WHITE if not is_elite else Color(1.15, 1.05, 0.65), 0.26)
		elif hop:
			_do_hare_hop()

func _ai_disciple_lunge(delta: float, offset: Vector2, dist: float) -> void:
	if offset.length_squared() > 0.01:
		_visual.flip_h = offset.x < 0.0
	if _lunging:
		velocity = _lunge_dir * def.speed * 2.35
		_lunge_cd -= delta
		if _lunge_cd <= 0.0:
			_lunging = false
			_lunge_cd = randf_range(1.05, 1.7)
		return
	if _lunge_wind > 0.0:
		# Plant feet — steel 亮刃 tell so the stab is readable vs hare hop.
		_lunge_wind -= delta
		velocity = offset.normalized() * def.speed * 0.12
		# Soft crouch pulse while blade is drawn.
		if _visual and def:
			var crouch := 0.92 + 0.06 * sin(Time.get_ticks_msec() * 0.04)
			_visual.scale = Vector2(def.sprite_scale * (2.0 - crouch), def.sprite_scale * crouch)
		if _lunge_wind <= 0.0:
			_lunging = true
			_lunge_dir = offset.normalized() if dist > 1.0 else Vector2.RIGHT
			_lunge_cd = 0.22
			if _visual and def:
				_visual.scale = Vector2(def.sprite_scale, def.sprite_scale)
			if SfxService:
				SfxService.play_blade_thrust()
		return
	_lunge_cd -= delta
	if _lunge_cd <= 0.0 and dist < 92.0 and dist > 18.0:
		_lunge_wind = 0.26
		_lunge_dir = offset.normalized() if dist > 1.0 else Vector2.RIGHT
		_spawn_lunge_warn()
		modulate = Color(0.78, 0.9, 1.2)
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color.WHITE if not is_elite else Color(1.15, 1.05, 0.65), 0.28)
	else:
		velocity = offset.normalized() * def.speed if dist > 1.0 else Vector2.ZERO

func _do_hare_hop() -> void:
	if _visual == null:
		return
	var base := def.sprite_scale
	_visual.scale = Vector2(base * 1.18, base * 0.78)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2(base * 0.92, base * 1.12), 0.08)
	tw.tween_property(_visual, "scale", Vector2(base, base), 0.1)
	var outline := get_node_or_null("Outline") as Sprite2D
	if outline:
		outline.modulate = Color(0.4, 1.0, 0.72, 0.7)
		var otw := create_tween()
		otw.tween_property(outline, "modulate", Color(0.04, 0.05, 0.08, 0.4), 0.18)

func _spawn_hop_pip(dir: Vector2) -> void:
	# Impact mote after peck lands — quieter than the pre-warn crescent.
	if dir.length_squared() < 0.01:
		return
	var n := dir.normalized()
	var pip := Polygon2D.new()
	pip.color = Color(0.5, 1.0, 0.78, 0.85)
	pip.polygon = [Vector2(-3, -3), Vector2(6, 0), Vector2(-3, 3)]
	pip.rotation = n.angle()
	pip.position = n * 14.0
	pip.z_index = 6
	add_child(pip)
	var tw := pip.create_tween()
	tw.tween_property(pip, "modulate:a", 0.0, 0.16)
	tw.parallel().tween_property(pip, "position", n * 26.0, 0.16)
	tw.tween_callback(pip.queue_free)

func _spawn_peck_warn(dir: Vector2) -> void:
	# Jade crescent arc — side-peck telegraph, not a straight steel blade road.
	if dir.length_squared() < 0.01:
		return
	if SfxService:
		SfxService.play_hare_peck_warn()
	var n := dir.normalized()
	var side := n.orthogonal()
	var arc := Line2D.new()
	arc.width = 2.8
	arc.default_color = Color(0.4, 0.98, 0.72, 0.92)
	arc.z_index = 7
	var pts := PackedVector2Array()
	for i in 10:
		var u := float(i) / 9.0
		var ang := -0.95 + 1.9 * u
		pts.append((n * 0.7 + side * sin(ang) * 0.55).normalized() * (16.0 + 28.0 * u))
	arc.points = pts
	add_child(arc)
	# Soft jade fan fill under the crescent.
	var fan := Polygon2D.new()
	fan.color = Color(0.35, 0.95, 0.7, 0.22)
	fan.z_index = 6
	var fpts := PackedVector2Array([Vector2.ZERO])
	for i in 8:
		var u2 := float(i) / 7.0
		var ang2 := -0.7 + 1.4 * u2
		fpts.append(n.rotated(ang2) * 36.0)
	fan.polygon = fpts
	add_child(fan)
	# Beak tip pip at the far end of the arc.
	var tip := Polygon2D.new()
	tip.color = Color(0.55, 1.0, 0.82, 0.95)
	tip.polygon = [Vector2(-3.5, -3.5), Vector2(7, 0), Vector2(-3.5, 3.5)]
	tip.rotation = n.angle()
	tip.position = n * 40.0
	tip.z_index = 8
	add_child(tip)
	var outline := get_node_or_null("Outline") as Sprite2D
	if outline:
		outline.modulate = Color(0.35, 1.0, 0.72, 0.8)
		var otw := create_tween()
		otw.tween_property(outline, "modulate", Color(0.04, 0.05, 0.08, 0.4), 0.26)
	var tw := create_tween()
	tw.tween_property(arc, "modulate:a", 0.4, 0.08)
	tw.tween_property(arc, "modulate:a", 1.0, 0.08)
	tw.tween_property(arc, "modulate:a", 0.0, 0.12)
	tw.parallel().tween_property(fan, "modulate:a", 0.0, 0.28)
	tw.parallel().tween_property(tip, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func() -> void:
		arc.queue_free()
		fan.queue_free()
		tip.queue_free()
	)

func _spawn_lunge_warn() -> void:
	# Steel 亮刃 telegraph — short road + blade tip, distinct from orange charge / jade hop.
	if SfxService:
		SfxService.play_blade_warn()
	var n := _lunge_dir
	if n.length_squared() < 0.01:
		n = Vector2.RIGHT
	else:
		n = n.normalized()
	var side := n.orthogonal()
	var length := 48.0
	# Soft road fill under the blade line.
	var road := Line2D.new()
	road.width = 9.0
	road.default_color = Color(0.55, 0.78, 1.0, 0.28)
	road.add_point(Vector2.ZERO)
	road.add_point(n * length)
	road.z_index = 6
	add_child(road)
	var edge_a := Line2D.new()
	edge_a.width = 1.4
	edge_a.default_color = Color(0.75, 0.92, 1.0, 0.55)
	edge_a.add_point(side * 4.0)
	edge_a.add_point(n * length + side * 3.0)
	edge_a.z_index = 6
	add_child(edge_a)
	var edge_b := Line2D.new()
	edge_b.width = 1.4
	edge_b.default_color = Color(0.75, 0.92, 1.0, 0.55)
	edge_b.add_point(-side * 4.0)
	edge_b.add_point(n * length - side * 3.0)
	edge_b.z_index = 6
	add_child(edge_b)
	var line := Line2D.new()
	line.width = 3.2
	line.default_color = Color(0.72, 0.9, 1.0, 0.95)
	line.add_point(Vector2.ZERO)
	line.add_point(n * length)
	line.z_index = 7
	add_child(line)
	# Blade tip — steel wedge, not orange charge arrow.
	var tip := Polygon2D.new()
	tip.color = Color(0.88, 0.96, 1.0, 0.95)
	tip.polygon = [Vector2(-5, -4), Vector2(8, 0), Vector2(-5, 4)]
	tip.position = n * length
	tip.rotation = n.angle()
	tip.z_index = 8
	add_child(tip)
	# Cross-guard tick at the hilt — reads as drawn blade.
	var guard := Line2D.new()
	guard.width = 2.4
	guard.default_color = Color(0.95, 0.98, 1.0, 0.9)
	guard.add_point(side * 6.0)
	guard.add_point(-side * 6.0)
	guard.z_index = 8
	add_child(guard)
	var outline := get_node_or_null("Outline") as Sprite2D
	if outline:
		outline.modulate = Color(0.5, 0.85, 1.0, 0.85)
		if _visual:
			outline.scale = _visual.scale * 1.12
		var otw := create_tween()
		otw.tween_property(outline, "modulate", Color(0.04, 0.05, 0.08, 0.4), 0.3)
		if _visual:
			otw.parallel().tween_property(outline, "scale", _visual.scale * 1.03, 0.3)
	# Pulse once so the tell stays alive through the windup.
	var pulse := create_tween()
	pulse.tween_property(line, "modulate:a", 0.45, 0.08)
	pulse.tween_property(line, "modulate:a", 1.0, 0.1)
	pulse.tween_property(line, "modulate:a", 0.0, 0.12)
	pulse.parallel().tween_property(road, "modulate:a", 0.0, 0.3)
	pulse.parallel().tween_property(edge_a, "modulate:a", 0.0, 0.3)
	pulse.parallel().tween_property(edge_b, "modulate:a", 0.0, 0.3)
	pulse.parallel().tween_property(tip, "modulate:a", 0.0, 0.3)
	pulse.parallel().tween_property(guard, "modulate:a", 0.0, 0.3)
	pulse.tween_callback(func() -> void:
		road.queue_free()
		edge_a.queue_free()
		edge_b.queue_free()
		line.queue_free()
		tip.queue_free()
		guard.queue_free()
	)

func _spawn_charge_warn() -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(1.0, 0.55, 0.3, 0.85)
	line.add_point(Vector2.ZERO)
	line.add_point(_charge_dir * 85.0)
	add_child(line)
	var tip := Polygon2D.new()
	tip.color = Color(1.0, 0.75, 0.35, 0.9)
	tip.polygon = [Vector2(-5, -4), Vector2(7, 0), Vector2(-5, 4)]
	tip.position = _charge_dir * 85.0
	tip.rotation = _charge_dir.angle()
	add_child(tip)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.32)
	tw.parallel().tween_property(tip, "modulate:a", 0.0, 0.32)
	tw.tween_callback(func() -> void:
		line.queue_free()
		tip.queue_free()
	)

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
	if _casting or _recovering:
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
	# Call out the move so early bosses teach patterns.
	var callout := "秘法"
	var call_col := Color(1.0, 0.7, 0.4)
	match sid:
		"aoe_ring":
			callout = "戒圈"
			call_col = Color(1.0, 0.55, 0.3)
		"dash_strike":
			callout = "突斩"
			call_col = Color(1.0, 0.75, 0.35)
		"summon":
			callout = "召侍"
			call_col = Color(0.85, 0.7, 1.0)
		"spread_shots":
			callout = "散矢"
			call_col = Color(1.0, 0.6, 0.45)
		"void_pull":
			callout = "虚引"
			call_col = Color(0.7, 0.55, 1.0)
	FloatTextManager.show_message(global_position + Vector2(0, -48), callout, call_col)
	# HUD shout on early bosses — pattern must read over combat clutter.
	var hud := get_tree().get_first_node_in_group("hud")
	if def != null and def.is_boss and GameState.stage_id in ["sect", "country"]:
		if hud and hud.has_method("show_clear"):
			hud.call("show_clear", callout)
	# Orange telegraph warn — distinct from gold 破绽 enter chime.
	if SfxService:
		SfxService.play_telegraph()
	if hud and hud.has_method("flash_telegraph_dock"):
		hud.call("flash_telegraph_dock")
	modulate = Color(1.45, 0.75, 0.55)
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color.WHITE if not is_elite else Color(1.15, 1.05, 0.65), telegraph * 0.55)
	match sid:
		"dash_strike":
			_telegraph_line(player.global_position, telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self) or GameState.dead:
				_casting = false
				return
			var dest: Vector2 = player.global_position
			var strike_from := global_position
			global_position = global_position.lerp(dest, 0.85)
			var hit_dir := (dest - strike_from).normalized()
			if hit_dir.length_squared() < 0.01:
				hit_dir = Vector2.RIGHT
			if player.has_method("take_hit"):
				player.take_hit(int(skill.get("damage", 18)), strike_from)
			_flash_dash_strike_hit(dest, hit_dir)
			_clear_telegraph()
		"summon":
			_telegraph_ring(float(skill.get("radius", 70)), telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self):
				_casting = false
				return
			_do_summon(skill)
			_clear_telegraph()
		"spread_shots":
			_telegraph_fan(player.global_position, telegraph, int(skill.get("count", 6)))
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self):
				_casting = false
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
					player.take_hit(int(skill.get("damage", 16)), global_position)
			_clear_telegraph()
		_:
			var radius := float(skill.get("radius", 90))
			_telegraph_ring(radius, telegraph)
			await get_tree().create_timer(telegraph).timeout
			if not is_instance_valid(self):
				_casting = false
				return
			if is_instance_valid(player) and player.global_position.distance_to(global_position) <= radius:
				if player.has_method("take_hit"):
					player.take_hit(int(skill.get("damage", 14)), global_position)
			_clear_telegraph()
	# Impact done → recover window so the counter hit is obvious.
	_casting = false
	await _enter_recover(skill)

func _enter_recover(skill: Dictionary) -> void:
	if not is_instance_valid(self) or GameState.dead:
		_recovering = false
		return
	var recover := float(skill.get("recover", 0.7))
	if recover <= 0.05:
		_recovering = false
		return
	_recovering = true
	var as_boss := def != null and def.is_boss
	var early_boss := as_boss and GameState.stage_id in ["sect", "country"]
	_show_recover_fx(as_boss, early_boss)
	if as_boss:
		# Gold punish window — opposite of red telegraph, same language as combo dopamine.
		var shout := "破绽" if early_boss else "破"
		FloatTextManager.show_message(global_position + Vector2(0, -52), shout, Color(1.0, 0.9, 0.4))
		if early_boss:
			FloatTextManager.show_message(global_position + Vector2(0, -68), "狠打", Color(1.0, 0.95, 0.55))
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			if early_boss and hud.has_method("flash_recover_edges_loud"):
				hud.call("flash_recover_edges_loud")
			elif hud.has_method("flash_recover_edges"):
				hud.call("flash_recover_edges")
			if hud.has_method("arm_boss_break_window"):
				hud.call("arm_boss_break_window", recover)
			if early_boss and hud.has_method("show_clear"):
				hud.call("show_clear", "破绽 · 狠打")
			elif GameState.stage_id in ["sect", "country"] and hud.has_method("show_clear"):
				hud.call("show_clear", "破 · 狠打")
		modulate = Color(1.35, 1.15, 0.65) if early_boss else Color(1.15, 1.05, 0.7)
		var outline := get_node_or_null("Outline") as Sprite2D
		if outline and early_boss:
			outline.modulate = Color(1.0, 0.88, 0.35, 0.9)
			outline.scale = _visual.scale * 1.14 if _visual else Vector2(1.14, 1.14)
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.4, 1.2, 0.7), recover * 0.28)
		tw.tween_property(self, "modulate", Color.WHITE if not is_elite else Color(1.15, 1.05, 0.65), recover * 0.72)
		if outline and early_boss:
			tw.parallel().tween_property(outline, "modulate", Color(0.04, 0.05, 0.08, 0.4), recover * 0.85)
			if _visual:
				tw.parallel().tween_property(outline, "scale", _visual.scale * 1.03, recover * 0.85)
		# Soft hitch + camera kick so 破绽 lands as a beat.
		if early_boss:
			var world := get_tree().get_first_node_in_group("game_world")
			if world and world.has_method("hitstop"):
				world.hitstop(0.028)
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player and player.has_method("pulse_camera"):
				player.pulse_camera(0.1)
		# Gold enter chime — all boss 破绽; replaces old clear-victory beep.
		if SfxService:
			SfxService.play_break()
		if hud and hud.has_method("flash_break_dock"):
			hud.call("flash_break_dock")
		# Minimap warm-gold pip — life matches recover so edge/bar/pip share one clock.
		var radar := get_tree().get_first_node_in_group("game_world")
		if radar and radar.has_method("radar_ping"):
			var ping_life := recover + (0.25 if early_boss else 0.15)
			radar.call("radar_ping", global_position, "break", ping_life)
	else:
		FloatTextManager.show_message(global_position + Vector2(0, -52), "破绽", Color(0.55, 1.0, 0.85))
		# Cool cyan breath — opposite of warm telegraph.
		modulate = Color(0.7, 1.15, 1.05)
		var tw2 := create_tween()
		tw2.tween_property(self, "modulate", Color(0.85, 1.2, 1.1), recover * 0.35)
		tw2.tween_property(self, "modulate", Color.WHITE if not is_elite else Color(1.15, 1.05, 0.65), recover * 0.65)
	await get_tree().create_timer(recover).timeout
	if not is_instance_valid(self):
		return
	_clear_recover_fx()
	_recovering = false

func _show_recover_fx(as_boss: bool = false, early_boss: bool = false) -> void:
	_clear_recover_fx()
	_recover_fx = Node2D.new()
	_recover_fx.z_index = 25
	add_child(_recover_fx)
	var r := (def.size if def else 10.0) + (28.0 if early_boss else 22.0)
	var rim_col := Color(1.0, 0.9, 0.38, 1.0) if early_boss else (Color(1.0, 0.86, 0.38, 0.98) if as_boss else Color(0.45, 1.0, 0.82, 0.95))
	var fill_col := Color(1.0, 0.88, 0.4, 0.32) if early_boss else (Color(1.0, 0.82, 0.35, 0.2) if as_boss else Color(0.35, 0.95, 0.8, 0.16))
	var tick_col := Color(1.0, 0.98, 0.65, 1.0) if early_boss else (Color(1.0, 0.95, 0.55, 0.98) if as_boss else Color(0.7, 1.0, 0.9, 0.95))
	var ring := Line2D.new()
	ring.width = 4.0 if early_boss else (3.2 if as_boss else 2.8)
	ring.default_color = rim_col
	for i in 37:
		var a := TAU * float(i) / 36.0
		ring.add_point(Vector2(cos(a), sin(a)) * r)
	_recover_fx.add_child(ring)
	var fill := Polygon2D.new()
	fill.color = fill_col
	var pts: PackedVector2Array = []
	for i in 28:
		var a2 := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a2), sin(a2)) * r)
	fill.polygon = pts
	_recover_fx.add_child(fill)
	# Four ticks mark the punish window.
	for i in 4:
		var a3 := TAU * 0.25 * float(i) + PI * 0.25
		var tick := Line2D.new()
		tick.width = 2.6 if early_boss else (2.2 if as_boss else 2.0)
		tick.default_color = tick_col
		tick.add_point(Vector2.from_angle(a3) * (r * 0.78))
		tick.add_point(Vector2.from_angle(a3) * (r * 1.12 if early_boss else 1.08))
		_recover_fx.add_child(tick)
	_recover_fx.scale = Vector2(0.55 if early_boss else 0.7, 0.55 if early_boss else 0.7)
	var pop := create_tween()
	pop.tween_property(_recover_fx, "scale", Vector2(1.08, 1.08) if early_boss else Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	if early_boss:
		pop.tween_property(_recover_fx, "scale", Vector2.ONE, 0.08)
	if as_boss:
		# Soft outer bloom so the gold rim pops once.
		var bloom := Line2D.new()
		bloom.width = 2.2 if early_boss else 1.6
		bloom.default_color = Color(1.0, 0.94, 0.5, 0.85 if early_boss else 0.7)
		for i in 37:
			var a4 := TAU * float(i) / 36.0
			bloom.add_point(Vector2(cos(a4), sin(a4)) * (r * 1.12))
		_recover_fx.add_child(bloom)
		var btw := bloom.create_tween()
		btw.tween_property(bloom, "scale", Vector2(1.55 if early_boss else 1.35, 1.55 if early_boss else 1.35), 0.32 if early_boss else 0.28)
		btw.parallel().tween_property(bloom, "modulate:a", 0.0, 0.32 if early_boss else 0.28)
		btw.tween_callback(bloom.queue_free)
		if early_boss:
			# Second gold nova — double flash so 破绽 reads mid-swarm.
			var nova := Polygon2D.new()
			nova.color = Color(1.0, 0.9, 0.4, 0.45)
			var npts: PackedVector2Array = []
			for i in 20:
				var an := TAU * float(i) / 20.0
				npts.append(Vector2(cos(an), sin(an)) * (r * 0.55))
			nova.polygon = npts
			_recover_fx.add_child(nova)
			var ntw := nova.create_tween()
			ntw.tween_property(nova, "scale", Vector2(2.4, 2.4), 0.22)
			ntw.parallel().tween_property(nova, "modulate:a", 0.0, 0.22)
			ntw.tween_callback(nova.queue_free)

func _clear_recover_fx() -> void:
	if _recover_fx and is_instance_valid(_recover_fx):
		_recover_fx.queue_free()
	_recover_fx = null

func is_recovering() -> bool:
	return _recovering

func _telegraph_ring(radius: float, duration: float) -> void:
	_clear_telegraph()
	_telegraph = Node2D.new()
	_telegraph.z_index = 24
	add_child(_telegraph)
	var fill := Polygon2D.new()
	fill.color = Color(1.0, 0.22, 0.15, 0.34)
	var pts: PackedVector2Array = []
	for i in 36:
		var a := TAU * float(i) / 36.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	fill.polygon = pts
	_telegraph.add_child(fill)
	var rim := Line2D.new()
	rim.width = 3.6
	rim.default_color = Color(1.0, 0.5, 0.28, 1.0)
	for i in 37:
		var a2 := TAU * float(i) / 36.0
		rim.add_point(Vector2(cos(a2), sin(a2)) * radius)
	_telegraph.add_child(rim)
	# Inner danger ring for readability.
	var inner := Line2D.new()
	inner.width = 1.8
	inner.default_color = Color(1.0, 0.88, 0.4, 0.85)
	for i in 37:
		var a3 := TAU * float(i) / 36.0
		inner.add_point(Vector2(cos(a3), sin(a3)) * (radius * 0.55))
	_telegraph.add_child(inner)
	# Cardinal ticks — "this circle hurts".
	for i in 8:
		var a4 := TAU * float(i) / 8.0
		var tick := Line2D.new()
		tick.width = 2.0
		tick.default_color = Color(1.0, 0.85, 0.45, 0.9)
		tick.add_point(Vector2.from_angle(a4) * (radius * 0.82))
		tick.add_point(Vector2.from_angle(a4) * (radius * 1.06))
		_telegraph.add_child(tick)
	fill.scale = Vector2(0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(fill, "scale", Vector2.ONE, maxf(duration * 0.88, 0.25)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Pulse rim so telegraph stays alive until impact.
	var pulse := create_tween().set_loops()
	pulse.tween_property(rim, "modulate:a", 0.45, 0.14)
	pulse.tween_property(rim, "modulate:a", 1.0, 0.14)

func _telegraph_line(target: Vector2, duration: float) -> void:
	_clear_telegraph()
	_telegraph = Node2D.new()
	_telegraph.z_index = 24
	add_child(_telegraph)
	var dir := target - global_position
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	var length := clampf(dir.length(), 48.0, 200.0)
	var n := dir.normalized()
	var perp := Vector2(-n.y, n.x)
	# Flared corridor — reads as a dash sector, wider at the tip.
	var half_w0 := 11.0
	var half_w1 := 20.0
	var road := Polygon2D.new()
	road.color = Color(1.0, 0.3, 0.18, 0.34)
	road.polygon = PackedVector2Array([
		perp * half_w0,
		n * length + perp * half_w1,
		n * length - perp * half_w1,
		-perp * half_w0,
	])
	_telegraph.add_child(road)
	var edge_a := Line2D.new()
	edge_a.width = 2.0
	edge_a.default_color = Color(1.0, 0.78, 0.35, 0.9)
	edge_a.add_point(perp * half_w0)
	edge_a.add_point(n * length + perp * half_w1)
	_telegraph.add_child(edge_a)
	var edge_b := Line2D.new()
	edge_b.width = 2.0
	edge_b.default_color = Color(1.0, 0.78, 0.35, 0.9)
	edge_b.add_point(-perp * half_w0)
	edge_b.add_point(n * length - perp * half_w1)
	_telegraph.add_child(edge_b)
	var line := Line2D.new()
	line.width = 5.2
	line.default_color = Color(1.0, 0.45, 0.25, 0.95)
	line.add_point(Vector2.ZERO)
	line.add_point(n * length)
	_telegraph.add_child(line)
	# Tip arc — sector bite at the far end of the dash.
	var tip_arc := Line2D.new()
	tip_arc.width = 2.6
	tip_arc.default_color = Color(1.0, 0.88, 0.4, 0.85)
	var tip_ang := n.angle()
	for i in 9:
		var u := float(i) / 8.0
		var aa := tip_ang - 0.55 + 1.1 * u
		tip_arc.add_point(n * length + Vector2.from_angle(aa) * 10.0)
	_telegraph.add_child(tip_arc)
	var tip := Polygon2D.new()
	tip.color = Color(1.0, 0.85, 0.4, 0.95)
	tip.polygon = [Vector2(-7, -6), Vector2(10, 0), Vector2(-7, 6)]
	tip.position = n * length
	tip.rotation = n.angle()
	_telegraph.add_child(tip)
	road.modulate.a = 0.5
	var tw := create_tween()
	tw.tween_property(road, "modulate:a", 1.0, maxf(duration * 0.7, 0.2))
	var pulse := create_tween().set_loops()
	pulse.tween_property(line, "modulate:a", 0.4, 0.12)
	pulse.tween_property(line, "modulate:a", 1.0, 0.12)

func _telegraph_fan(target: Vector2, duration: float, count: int) -> void:
	# Boss 散矢扇区 — filled wedge + arc rim, not just thin rays.
	_clear_telegraph()
	_telegraph = Node2D.new()
	_telegraph.z_index = 24
	add_child(_telegraph)
	var base := (target - global_position).angle()
	var rays := maxi(count, 3)
	var step := 0.28
	var half_span := step * float(rays - 1) * 0.5
	var reach := 78.0
	var a0 := base - half_span
	var a1 := base + half_span
	# Soft filled pie — danger sector reads at a glance.
	var wedge := Polygon2D.new()
	wedge.color = Color(1.0, 0.28, 0.16, 0.3)
	var wpts := PackedVector2Array([Vector2.ZERO])
	for i in 14:
		var t := float(i) / 13.0
		wpts.append(Vector2.from_angle(lerpf(a0, a1, t)) * reach)
	wedge.polygon = wpts
	_telegraph.add_child(wedge)
	# Outer arc rim.
	var arc := Line2D.new()
	arc.width = 3.4
	arc.default_color = Color(1.0, 0.55, 0.28, 0.95)
	for i in 16:
		var t2 := float(i) / 15.0
		arc.add_point(Vector2.from_angle(lerpf(a0, a1, t2)) * reach)
	_telegraph.add_child(arc)
	# Inner guide arc — depth cue.
	var arc_in := Line2D.new()
	arc_in.width = 1.8
	arc_in.default_color = Color(1.0, 0.88, 0.4, 0.75)
	for i in 12:
		var t3 := float(i) / 11.0
		arc_in.add_point(Vector2.from_angle(lerpf(a0, a1, t3)) * (reach * 0.48))
	_telegraph.add_child(arc_in)
	# Bound edges — thick flanks so the sector width is obvious.
	for edge_ang in [a0, a1]:
		var edge := Line2D.new()
		edge.width = 3.0
		edge.default_color = Color(1.0, 0.78, 0.35, 0.9)
		edge.add_point(Vector2.ZERO)
		edge.add_point(Vector2.from_angle(edge_ang) * reach)
		_telegraph.add_child(edge)
	# Shot rays — match _do_spread angles.
	for i in rays:
		var ang := base + (float(i) - float(rays - 1) * 0.5) * step
		var ray := Line2D.new()
		ray.width = 2.2
		ray.default_color = Color(1.0, 0.48, 0.28, 0.82)
		ray.add_point(Vector2.from_angle(ang) * 10.0)
		ray.add_point(Vector2.from_angle(ang) * reach)
		_telegraph.add_child(ray)
		# Tip pip on each shot line.
		var tip := Polygon2D.new()
		tip.color = Color(1.0, 0.85, 0.4, 0.9)
		tip.polygon = [Vector2(-3.5, -3), Vector2(6, 0), Vector2(-3.5, 3)]
		tip.position = Vector2.from_angle(ang) * reach
		tip.rotation = ang
		_telegraph.add_child(tip)
	wedge.modulate.a = 0.55
	var tw := create_tween()
	tw.tween_property(wedge, "modulate:a", 1.0, maxf(duration * 0.55, 0.18))
	var pulse := create_tween().set_loops()
	pulse.tween_property(arc, "modulate:a", 0.4, maxf(duration * 0.18, 0.08))
	pulse.tween_property(arc, "modulate:a", 1.0, maxf(duration * 0.18, 0.08))

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

## Boss 突斩 connect — slash burst + soft stop, distinct from trash contact.
func _flash_dash_strike_hit(at: Vector2, dir: Vector2) -> void:
	var n := dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	var side := n.orthogonal()
	# Hot slash band through the player.
	var slash := Line2D.new()
	slash.width = 5.5
	slash.default_color = Color(1.0, 0.55, 0.28, 0.95)
	slash.z_index = 12
	slash.add_point(-n * 18.0 - side * 4.0)
	slash.add_point(n * 28.0 + side * 2.0)
	get_parent().add_child(slash)
	slash.global_position = at
	var slash2 := Line2D.new()
	slash2.width = 2.8
	slash2.default_color = Color(1.0, 0.9, 0.45, 0.85)
	slash2.z_index = 13
	slash2.add_point(-n * 10.0 + side * 8.0)
	slash2.add_point(n * 22.0 - side * 6.0)
	get_parent().add_child(slash2)
	slash2.global_position = at
	var core := Polygon2D.new()
	core.color = Color(1.0, 0.7, 0.35, 0.55)
	core.z_index = 11
	core.polygon = PackedVector2Array([
		-side * 10.0, n * 8.0, side * 10.0, -n * 6.0
	])
	get_parent().add_child(core)
	core.global_position = at
	var tw := create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(slash2, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(core, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(core, "scale", Vector2(1.8, 1.8), 0.18)
	tw.tween_callback(func() -> void:
		slash.queue_free()
		slash2.queue_free()
		core.queue_free()
	)
	FloatTextManager.show_message(at + Vector2(0, -36), "突斩", Color(1.0, 0.72, 0.35))
	var world := get_tree().get_first_node_in_group("game_world")
	if world and world.has_method("hitstop"):
		world.hitstop(0.035)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("pulse_camera"):
		player.pulse_camera(0.13)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_dash_strike_edges"):
		hud.call("flash_dash_strike_edges", -n)

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
			bolt.launch_hostile(global_position, Vector2.from_angle(ang), dmg, "scatter")
		elif bolt.has_method("launch"):
			# Fallback: still spawn visual; damage via nearby tick is skipped.
			bolt.launch(global_position, Vector2.from_angle(ang), 0.01)

func take_damage(amount: int, knock_dir: Vector2 = Vector2.ZERO) -> void:
	# Punish window: hits during recover read louder and hit harder.
	if _recovering and def != null and def.is_boss:
		amount = int(ceil(float(amount) * 1.2))
		FloatTextManager.show_message(global_position + Vector2(0, -40), "破", Color(1.0, 0.9, 0.4))
	var yingren := _try_yingren_feedback()
	hp -= amount
	_refresh_hp()
	if def != null and def.is_boss:
		EventBus.boss_hp_changed.emit(def.display_name, hp, max_hp)
	EventBus.damage_dealt.emit(global_position, amount, false)
	# 「迎刃」owns the audio beat — skip generic hit so warm-steel reads clean.
	if SfxService and not yingren:
		SfxService.play_hit()
	var kb := float(ContentDB.section("combat").get("knockback", 90))
	if knock_dir.length_squared() > 0.01:
		_knockback = knock_dir.normalized() * kb * (0.45 if def and def.is_boss else 1.0)
	if _recovering:
		modulate = Color(1.45, 1.25, 0.7) if (def != null and def.is_boss) else Color(0.75, 1.35, 1.2)
	else:
		modulate = Color(1.5, 1.25, 1.2) if not is_elite else Color(1.55, 1.3, 0.75)
	var base_scale := scale
	var tw := create_tween()
	var restore := Color.WHITE
	if _recovering:
		restore = Color(1.2, 1.08, 0.72) if (def != null and def.is_boss) else Color(0.85, 1.15, 1.05)
	elif is_elite:
		restore = Color(1.15, 1.05, 0.65)
	tw.tween_property(self, "scale", base_scale * (1.16 if _recovering else 1.12), 0.04)
	tw.tween_property(self, "scale", base_scale, 0.06)
	tw.parallel().tween_property(self, "modulate", restore, 0.1)
	# Micro hitstop: light auto already hitchs in projectile; keep heavier pops for big hits.
	var min_hs := float(ContentDB.section("combat").get("hitstop_min_damage", 18))
	if amount >= min_hs or (def != null and def.is_boss) or is_elite:
		var world := get_tree().get_first_node_in_group("game_world")
		if world and world.has_method("hitstop"):
			world.hitstop(0.022 if amount < 28 else 0.038)
	if hp <= 0:
		_die()

## 愈后近身弟子：落地 0.4s 内首刀 → 「迎刃」 punchy read.
## Returns true when the punish window fired (caller skips generic hit SFX).
func _try_yingren_feedback() -> bool:
	if not has_meta("yingren_armed") or not bool(get_meta("yingren_armed")):
		return false
	set_meta("yingren_armed", false)
	var until_ms := int(get_meta("yingren_until", 0))
	if Time.get_ticks_msec() > until_ms:
		return false
	# ~0.2s hard stun so the counter beat feels fair (FX already fired above/below).
	_stun_t = 0.2
	_lunging = false
	_lunge_wind = 0.0
	_charging = false
	_pulse_stun_steel_outline()
	if SfxService:
		SfxService.play_yingren()
	FloatTextManager.show_message(global_position + Vector2(0, -36), "迎刃", Color(1.0, 0.88, 0.5))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_clear"):
		hud.call("show_clear", "迎刃")
	if hud and hud.has_method("flash_steel_edges"):
		hud.call("flash_steel_edges")
	# Soft kick — keep hitstop_scale floor via world.hitstop.
	var world := get_tree().get_first_node_in_group("game_world")
	if world and world.has_method("hitstop"):
		world.hitstop(0.026)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("pulse_camera"):
		player.pulse_camera(0.07)
	# Brief steel spark on the mob silhouette.
	modulate = Color(1.55, 1.35, 0.75)
	var spark := Line2D.new()
	spark.width = 2.0
	spark.default_color = Color(1.0, 0.86, 0.45, 0.9)
	spark.z_index = 30
	for i in 9:
		var a := TAU * float(i) / 8.0
		spark.add_point(Vector2(cos(a), sin(a)) * 14.0)
	add_child(spark)
	var stw := spark.create_tween()
	stw.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.12).set_trans(Tween.TRANS_SINE)
	stw.parallel().tween_property(spark, "modulate:a", 0.0, 0.12)
	stw.tween_callback(spark.queue_free)
	return true

## Warm-steel silhouette while 迎刃 stun is live — punish window reads at a glance.
func _pulse_stun_steel_outline() -> void:
	var outline := get_node_or_null("Outline") as Sprite2D
	if outline == null or _visual == null:
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.045)
	outline.modulate = Color(1.0, 0.78 + 0.12 * pulse, 0.35, 0.55 + 0.4 * pulse)
	outline.scale = _visual.scale * (1.1 + 0.05 * pulse)

func _restore_stun_steel_outline() -> void:
	var outline := get_node_or_null("Outline") as Sprite2D
	if outline == null:
		return
	outline.modulate = Color(0.04, 0.05, 0.08, 0.4)
	if _visual:
		outline.scale = _visual.scale * 1.03

func _refresh_hp() -> void:
	if _hp_bar == null or max_hp <= 0:
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.size.x = _hp_bar_width * ratio

func _die() -> void:
	# Capture before FX clear — kill inside 破绽 wants a distinct short flash.
	var break_kill := _recovering
	if def != null and def.is_boss:
		EventBus.boss_hp_cleared.emit()
	if SfxService:
		SfxService.play_kill()
	if break_kill and GameState.stage_id in ["sect", "country"]:
		_flash_break_kill()
	elif def != null and def.is_boss:
		FloatTextManager.show_message(global_position + Vector2(0, -36), "斩Boss", Color(1.0, 0.72, 0.35))
	elif is_elite:
		FloatTextManager.show_message(global_position + Vector2(0, -28), "精英", Color(1.0, 0.88, 0.45))
	GameState.register_kill(def.id)
	var stage_now := GameState.current_stage()
	var shoudao := GameState.stage_id == "country" and stage_now != null and GameState.stage_kills() == stage_now.kill_target
	var early := GameState.early_kill_hook()
	# Per-kill shout once combo is live — opening minute also shouts the first 斩 / 市斩.
	if shoudao:
		# Dynasty clear blow — punchy「收刀」closes the near-clear gold tension.
		FloatTextManager.show_message(global_position + Vector2(0, -28), "收刀", Color(1.0, 0.86, 0.4))
		var world_sd := get_tree().get_first_node_in_group("game_world")
		if world_sd and world_sd.has_method("hitstop"):
			world_sd.hitstop(0.032)
	elif not break_kill and (GameState.combo >= 2 or early) and not (def != null and def.is_boss):
		var ccol := Color(0.95, 0.9, 0.55)
		var shout := "斩"
		if GameState.combo >= 8:
			ccol = Color(1.0, 0.6, 0.3)
		elif GameState.combo >= 4:
			ccol = Color(1.0, 0.82, 0.4)
		elif early:
			if GameState.stage_id == "country" and GameState.combo == 1:
				# Dynasty first blood — warm「市斩」vs sect teal「斩」.
				shout = "市斩"
				ccol = Color(1.0, 0.86, 0.42)
			elif GameState.stage_id == "sect" and GameState.combo == 1:
				# Sect first blood — courtyard teal (pairs 市斩 gold).
				shout = "斩"
				ccol = Color(0.45, 0.98, 0.9)
			else:
				ccol = Color(1.0, 0.96, 0.72)
		FloatTextManager.show_message(global_position + Vector2(0, -22), shout, ccol)
		if early and GameState.combo == 1 and GameState.stage_id == "sect":
			var world_zk := get_tree().get_first_node_in_group("game_world")
			if world_zk and world_zk.has_method("hitstop"):
				world_zk.hitstop(0.024)
			if world_zk and world_zk.has_method("radar_ping"):
				world_zk.call("radar_ping", global_position, "yard")
	_spawn_burst()
	call_deferred("_spawn_drops")
	if def.is_boss:
		GameState.add_spirit_stones(int(ContentDB.section("loot").get("boss_stone_reward", 40)))
		var world := get_tree().get_first_node_in_group("game_world")
		if world and world.has_method("on_boss_defeated"):
			world.on_boss_defeated(def.id)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("pulse_camera"):
		var shake := 0.08
		if def != null and def.is_boss:
			shake = 0.18
		elif GameState.combo >= 8:
			shake = 0.12
		elif GameState.combo >= 4:
			shake = 0.1
		if early and GameState.combo <= 3:
			shake = maxf(shake, 0.1)
		if shoudao:
			shake = maxf(shake, 0.14)
		if break_kill:
			shake = maxf(shake, 0.11)
		player.pulse_camera(shake)
	if def != null and (def.is_boss or is_elite):
		var world2 := get_tree().get_first_node_in_group("game_world")
		if world2 and world2.has_method("hitstop"):
			world2.hitstop(0.04 if is_elite else 0.055)
	elif break_kill and GameState.stage_id in ["sect", "country"]:
		var world3 := get_tree().get_first_node_in_group("game_world")
		if world3 and world3.has_method("hitstop"):
			world3.hitstop(0.026)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	call_deferred("set_physics_process", false)
	_clear_telegraph()
	_clear_recover_fx()
	_recovering = false
	_stun_t = 0.0
	_restore_stun_steel_outline()
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.35, 0.07)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)

## Kill inside 破绽 — sect teal / dynasty gold short punch (pairs window-open gold).
func _flash_break_kill() -> void:
	var yard := GameState.stage_id == "sect"
	var col := Color(0.45, 0.98, 0.9) if yard else Color(1.0, 0.88, 0.4)
	var y_off := -40.0 if def != null and def.is_boss else -32.0
	FloatTextManager.show_message(global_position + Vector2(0, y_off), "破杀", col)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		if hud.has_method("flash_break_kill_edges"):
			hud.call("flash_break_kill_edges", yard)
		if hud.has_method("show_clear"):
			hud.call("show_clear", "破杀" if yard else "破杀 · 市")
	var radar := get_tree().get_first_node_in_group("game_world")
	if radar and radar.has_method("radar_ping"):
		radar.call("radar_ping", global_position, "yard" if yard else "gold")

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
	var combo := GameState.combo
	var count := 8 if (def != null and def.is_boss) else (6 if is_elite else 5)
	if combo >= 6:
		count += 2
	if combo >= 10:
		count += 2
	if GameState.early_kill_hook() and not (def != null and def.is_boss):
		count += 2
	# Outer gold ring — one bright beat, then expand; sits above auto-hit sparks.
	var gold := Color(1.0, 0.92, 0.45, 1.0)
	if def != null and def.is_boss:
		gold = Color(1.0, 0.6, 0.28, 1.0)
	elif is_elite:
		gold = Color(1.0, 0.88, 0.4, 1.0)
	elif combo >= 8:
		gold = Color(1.0, 0.7, 0.32, 1.0)
	elif combo >= 4:
		gold = Color(1.0, 0.9, 0.42, 1.0)
	# Soft fill flash under the rim.
	var fill := Polygon2D.new()
	fill.z_index = 10
	fill.color = Color(gold.r, gold.g, gold.b, 0.4)
	var fpts: PackedVector2Array = []
	for i in 18:
		var a0 := TAU * float(i) / 18.0
		fpts.append(Vector2(cos(a0), sin(a0)) * 8.0)
	fill.polygon = fpts
	parent.add_child(fill)
	fill.global_position = global_position
	fill.scale = Vector2(0.6, 0.6)
	var ftw := fill.create_tween()
	ftw.tween_property(fill, "scale", Vector2(1.4, 1.4), 0.06)
	ftw.tween_property(fill, "scale", Vector2(2.8, 2.8), 0.16)
	ftw.parallel().tween_property(fill, "modulate:a", 0.0, 0.16)
	ftw.tween_callback(fill.queue_free)
	# Bright rim — holds opaque a beat then blooms out.
	var ring := Line2D.new()
	ring.width = 3.4 if combo >= 6 else 2.8
	ring.default_color = gold
	ring.z_index = 12
	for i in 21:
		var a := TAU * float(i) / 20.0
		ring.add_point(Vector2(cos(a), sin(a)) * 11.0)
	parent.add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector2(0.55, 0.55)
	var rtw := ring.create_tween()
	rtw.tween_property(ring, "scale", Vector2(1.05, 1.05), 0.05) # hold beat
	rtw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	rtw.tween_callback(ring.queue_free)
	# Secondary thinner echo ring — depth vs single auto-hit flecks.
	var echo := Line2D.new()
	echo.width = 1.6
	echo.default_color = Color(gold.r, gold.g, gold.b, 0.7)
	echo.z_index = 11
	for i in 17:
		var a2 := TAU * float(i) / 16.0
		echo.add_point(Vector2(cos(a2), sin(a2)) * 9.0)
	parent.add_child(echo)
	echo.global_position = global_position
	echo.scale = Vector2(0.8, 0.8)
	var etw := echo.create_tween()
	etw.tween_interval(0.04)
	etw.tween_property(echo, "scale", Vector2(3.2, 3.2), 0.2)
	etw.parallel().tween_property(echo, "modulate:a", 0.0, 0.2)
	etw.tween_callback(echo.queue_free)
	for i in count:
		var bit := Polygon2D.new()
		bit.polygon = [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]
		if def != null and def.is_boss:
			bit.color = Color(1.0, 0.65, 0.3, 0.95)
		elif is_elite:
			bit.color = Color(1.0, 0.88, 0.4, 0.95)
		elif combo >= 8:
			bit.color = Color(1.0, 0.6, 0.3, 0.95)
		elif combo >= 4:
			bit.color = Color(1.0, 0.85, 0.4, 0.92)
		else:
			bit.color = Color(1.0, 0.92, 0.55, 0.92)
		bit.global_position = global_position
		bit.z_index = 13
		parent.add_child(bit)
		var dir := Vector2.from_angle(TAU * float(i) / float(count) + randf() * 0.25)
		var dist := randf_range(22, 44) * (1.15 if combo >= 6 else 1.0)
		var tw := bit.create_tween()
		tw.tween_property(bit, "global_position", global_position + dir * dist, 0.2)
		tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.2)
		tw.tween_callback(bit.queue_free)
