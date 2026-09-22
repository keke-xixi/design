extends CharacterBody2D

var bounds := Rect2(24, 24, 1000, 700)
var _attack_cd := 0.0
var _hurt_cd := 0.0
var _skill_cd: Dictionary = {}
var _dash_iframe := 0.0
var _facing := Vector2.DOWN
var _projectiles: Node2D

@onready var _visual: Sprite2D = $Visual
@onready var _outline: Sprite2D = get_node_or_null("Outline")
@onready var _hp_bar: ColorRect = $HpBar
@onready var _aura: Polygon2D = get_node_or_null("Aura")
var _bob := 0.0
var _was_crisis := false
var _was_heal_zone := false
var _was_slow_zone := false
var _was_damage_zone := false
var _burst_flash_t := 0.0  # Gold-orange outline window after 灵爆.
var _pill_flash_t := 0.0  # Jade outline window after 服丹 — pairs HUD 翠闪.
var _slow_mist_flash_t := 0.0  # Brief violet mist punch on 滞 enter.
var _ash_flash_t := 0.0  # Brief crimson punch on 煞 enter.
var _heal_enter_t := 0.0  # Calm teal punch on 愈 enter — pairs crisis red kick.
var _revive_flash_t := 0.0  # Jade breath after R/overlay 再起 (soft iframe read).
var last_ring_connected := false  # HUD reads this for U-key gold vs cool flash.

## Shared with HUD edge vignette — keep phase identical.
const CRISIS_PULSE_HZ := 0.007
const HEAL_PULSE_HZ := 0.010  # Half-beat faster jade breath; still calm vs 破绽 gold.
const SLOW_PULSE_HZ := 0.0065  # Soft fog clock — slower than heal jade.
const DAMAGE_PULSE_HZ := 0.009  # Snappy 煞地 sting — faster than mist.

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _outline:
		_outline.texture = _visual.texture
		_outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	EventBus.player_hp_changed.connect(_on_hp)
	_on_hp(GameState.hp, GameState.max_hp)

func configure(projectiles: Node2D, map_rect: Rect2) -> void:
	_projectiles = projectiles
	bounds = map_rect

func _on_hp(hp: int, max_hp: int) -> void:
	var ratio := 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.size.x = 32.0 * ratio
	if ratio > 0.55:
		_hp_bar.color = Color(0.4, 0.92, 0.75)
	elif ratio > 0.35:
		_hp_bar.color = Color(0.95, 0.78, 0.35)
	else:
		_hp_bar.color = Color(0.95, 0.35, 0.3)
	# Low HP: don't freeze tint here — _physics_process breathes with HUD edges.
	if ratio <= 0.3 and not GameState.dead:
		pass
	elif _dash_iframe <= 0.0 and _revive_flash_t <= 0.0 and _burst_flash_t <= 0.0 and _pill_flash_t <= 0.0:
		modulate = Color.WHITE
		if _outline:
			_outline.modulate = Color(0.04, 0.05, 0.08, 0.4)

func _physics_process(delta: float) -> void:
	z_index = int(global_position.y)
	if GameState.dead:
		velocity = Vector2.ZERO
		_was_crisis = false
		return
	_bob += delta * 6.0
	_visual.position.y = -8.0 + sin(_bob) * 1.6
	if _outline:
		_outline.position.y = _visual.position.y + 1.0
		_outline.flip_h = _visual.flip_h
	var crisis := GameState.max_hp > 0 and float(GameState.hp) / float(GameState.max_hp) <= 0.3
	var in_heal := false
	var in_slow := false
	var in_damage := false
	var world_pre := get_tree().get_first_node_in_group("game_world")
	if world_pre and world_pre.has_method("zone_mods_at"):
		var zeff := str(world_pre.zone_mods_at(global_position).get("effect", ""))
		in_heal = zeff == "heal"
		in_slow = zeff == "slow"
		in_damage = zeff == "damage"
	if _aura and _dash_iframe <= 0.0 and _revive_flash_t <= 0.0 and not crisis and not in_heal and not in_slow and not in_damage:
		_aura.modulate = Color(1, 1, 1, 0.35 + 0.2 * sin(_bob * 0.7))
	for key in _skill_cd.keys():
		_skill_cd[key] = maxf(float(_skill_cd[key]) - delta, 0.0)
	if _dash_iframe > 0.0:
		_dash_iframe -= delta
		if _burst_flash_t > 0.0:
			_burst_flash_t = maxf(_burst_flash_t - delta, 0.0)
		# Cyan breath for the whole iframe — invuln must read after the ghost fades.
		var pulse := 0.72 + 0.18 * sin(Time.get_ticks_msec() * 0.028)
		modulate = Color(pulse * 0.75, pulse * 0.95, 1.15, 1.0)
		if _aura:
			_aura.modulate = Color(0.45, 0.9, 1.0, 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.03))
		if _outline:
			_outline.modulate = Color(0.3, 0.85, 1.0, 0.55)
		if _dash_iframe <= 0.0:
			_end_dash_iframe_tint()
	elif _revive_flash_t > 0.0:
		# Jade breath — soft revive iframe must read like dash cyan, calmer.
		_revive_flash_t = maxf(_revive_flash_t - delta, 0.0)
		var rp := 0.78 + 0.16 * sin(Time.get_ticks_msec() * 0.024)
		modulate = Color(rp * 0.7, rp * 1.05, rp * 0.92)
		if _aura:
			_aura.modulate = Color(0.4, 0.95, 0.82, 0.5 + 0.28 * sin(Time.get_ticks_msec() * 0.026))
		if _outline:
			_outline.modulate = Color(0.35, 0.95, 0.82, 0.55)
		if _revive_flash_t <= 0.0:
			_end_revive_flash_tint()
	elif _burst_flash_t > 0.0:
		# 灵爆金橙轮廓 — brief skill silhouette, same slot as dash cyan.
		_burst_flash_t -= delta
		var bp := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.045)
		modulate = Color(1.2 * bp, 0.88 * bp, 0.5)
		if _aura:
			_aura.modulate = Color(1.0, 0.7, 0.28, 0.4 + 0.3 * bp)
		if _outline:
			_outline.modulate = Color(1.0, 0.68, 0.22, 0.5 + 0.4 * bp)
			_outline.scale = _visual.scale * (1.08 + 0.05 * bp)
		if _burst_flash_t <= 0.0:
			_end_burst_flash_tint()
	elif _pill_flash_t > 0.0:
		# 服丹翠闪 — body jade matches HUD edge / KeyI bag punch.
		_pill_flash_t = maxf(_pill_flash_t - delta, 0.0)
		var pp := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.038)
		modulate = Color(0.72 * pp, 1.12 * pp, 0.88)
		if _aura:
			_aura.modulate = Color(0.35, 0.98, 0.7, 0.45 + 0.28 * pp)
		if _outline:
			_outline.modulate = Color(0.28, 0.98, 0.68, 0.55 + 0.35 * pp)
			_outline.scale = _visual.scale * (1.08 + 0.05 * pp)
		if _pill_flash_t <= 0.0:
			_end_pill_flash_tint()
	elif crisis:
		_was_heal_zone = false
		_was_slow_zone = false
		_was_damage_zone = false
		_ash_flash_t = 0.0
		# Sync edge + silhouette — same clock as HUD CRISIS_PULSE_HZ.
		var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * CRISIS_PULSE_HZ)
		# Crest with HUD edges: hot rim when breath peaks.
		modulate = Color(1.05 + 0.12 * breath, 0.68 + 0.1 * (1.0 - breath), 0.68 + 0.1 * (1.0 - breath))
		if _outline:
			_outline.modulate = Color(0.98, 0.12, 0.1, 0.4 + 0.5 * breath)
			_outline.scale = _visual.scale * (1.05 + 0.055 * breath)
		if _aura:
			_aura.modulate = Color(1.0, 0.22, 0.18, 0.3 + 0.4 * breath)
		if not _was_crisis:
			_was_crisis = true
			if SfxService:
				SfxService.play_crisis_enter()
			FloatTextManager.show_message(global_position + Vector2(0, -36), "危机", Color(1.0, 0.45, 0.35))
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_clear"):
				hud.call("show_clear", "危机 · 伤↑")
	elif in_heal:
		# 愈地：青绿微光，与屏幕边缘同频（对称于煞地/危机红）.
		_was_crisis = false
		_was_slow_zone = false
		_was_damage_zone = false
		_ash_flash_t = 0.0
		_slow_mist_flash_t = 0.0
		if _heal_enter_t > 0.0:
			_heal_enter_t = maxf(_heal_enter_t - delta, 0.0)
		var hbreath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * HEAL_PULSE_HZ)
		var enter := clampf(_heal_enter_t / 0.34, 0.0, 1.0)
		# Enter punch blends into calm jade breath — opposite of crisis red kick.
		var jade := hbreath * (1.0 - enter * 0.35) + enter
		modulate = Color(
			0.78 + 0.12 * jade,
			1.02 + 0.12 * jade,
			0.88 + 0.1 * jade
		)
		if _outline:
			_outline.modulate = Color(0.22, 0.98, 0.72, 0.32 + 0.48 * jade)
			_outline.scale = _visual.scale * (1.03 + 0.04 * jade + 0.06 * enter)
		if _aura:
			_aura.modulate = Color(0.32, 0.98, 0.75, 0.28 + 0.4 * jade + 0.18 * enter)
		if not _was_heal_zone:
			_was_heal_zone = true
			_heal_enter_t = 0.34
			if SfxService:
				SfxService.play_heal_enter()
			FloatTextManager.show_message(global_position + Vector2(0, -32), "愈", Color(0.5, 0.98, 0.82))
			var hud_h := get_tree().get_first_node_in_group("hud")
			if hud_h:
				if hud_h.has_method("flash_heal_enter_edges"):
					hud_h.call("flash_heal_enter_edges")
				if hud_h.has_method("show_clear"):
					hud_h.call("show_clear", "愈地 · 回息")
	elif in_slow:
		# 滞地：蓝紫雾呼吸 — outline/aura hang like mist (pairs edge violet).
		_was_crisis = false
		_was_heal_zone = false
		_was_damage_zone = false
		_ash_flash_t = 0.0
		if _slow_mist_flash_t > 0.0:
			_slow_mist_flash_t = maxf(_slow_mist_flash_t - delta, 0.0)
		var sbreath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * SLOW_PULSE_HZ)
		var enter := clampf(_slow_mist_flash_t / 0.32, 0.0, 1.0)
		# Blend enter punch into ongoing fog breath.
		var mist := sbreath * (1.0 - enter * 0.35) + enter
		modulate = Color(
			0.78 + 0.08 * mist,
			0.74 + 0.06 * mist,
			1.16 + 0.08 * mist
		)
		if _outline:
			_outline.modulate = Color(
				0.4 + 0.18 * mist,
				0.36 + 0.12 * mist,
				0.98 + 0.08 * mist,
				0.28 + 0.5 * mist
			)
			_outline.scale = _visual.scale * (1.04 + 0.05 * mist + 0.06 * enter)
		if _aura:
			_aura.modulate = Color(0.48, 0.4, 0.98, 0.22 + 0.45 * mist + 0.2 * enter)
		if not _was_slow_zone:
			_was_slow_zone = true
			_slow_mist_flash_t = 0.32
			if SfxService:
				SfxService.play_mist_enter()
			FloatTextManager.show_message(global_position + Vector2(0, -32), "滞", Color(0.7, 0.6, 0.98))
	elif in_damage:
		# 煞地：赤红呼吸 — snappier than mist, cooler than crisis panic.
		_was_crisis = false
		_was_heal_zone = false
		_was_slow_zone = false
		_slow_mist_flash_t = 0.0
		if _ash_flash_t > 0.0:
			_ash_flash_t = maxf(_ash_flash_t - delta, 0.0)
		var dbreath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * DAMAGE_PULSE_HZ)
		var ash_enter := clampf(_ash_flash_t / 0.28, 0.0, 1.0)
		var ash := dbreath * (1.0 - ash_enter * 0.4) + ash_enter
		modulate = Color(
			1.12 + 0.08 * ash,
			0.72 + 0.05 * (1.0 - ash),
			0.7 + 0.05 * (1.0 - ash)
		)
		if _outline:
			_outline.modulate = Color(
				0.98,
				0.18 + 0.12 * ash,
				0.14 + 0.08 * ash,
				0.32 + 0.48 * ash
			)
			_outline.scale = _visual.scale * (1.04 + 0.05 * ash + 0.07 * ash_enter)
		if _aura:
			_aura.modulate = Color(1.0, 0.28, 0.22, 0.24 + 0.42 * ash + 0.18 * ash_enter)
		if not _was_damage_zone:
			_was_damage_zone = true
			_ash_flash_t = 0.28
			if SfxService:
				SfxService.play_ash_enter()
			FloatTextManager.show_message(global_position + Vector2(0, -32), "煞", Color(1.0, 0.45, 0.38))
	else:
		_slow_mist_flash_t = 0.0
		_ash_flash_t = 0.0
		_heal_enter_t = 0.0
		if _was_crisis or _was_heal_zone or _was_slow_zone or _was_damage_zone:
			_was_crisis = false
			_was_heal_zone = false
			_was_slow_zone = false
			_was_damage_zone = false
			modulate = Color.WHITE
			if _outline:
				_outline.modulate = Color(0.04, 0.05, 0.08, 0.4)
				_outline.scale = _visual.scale * 1.03
		elif _hurt_cd <= 0.0:
			modulate = Color.WHITE
	var cbt := ContentDB.section("combat")
	var speed := float(cbt.get("player_speed", 96)) * GameState.effective_speed_mult()
	var zone_mult := 1.0
	var world := get_tree().get_first_node_in_group("game_world")
	if world and world.has_method("zone_mods_at"):
		zone_mult = float(world.zone_mods_at(global_position).get("speed_mult", 1.0))
	var direction := _move_axis()
	if direction != Vector2.ZERO:
		_facing = direction
		_visual.flip_h = direction.x < 0.0
		if _outline:
			_outline.flip_h = _visual.flip_h
	velocity = direction * speed * zone_mult
	move_and_slide()
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)
	if _hurt_cd > 0.0 and _dash_iframe <= 0.0:
		_hurt_cd -= delta
	elif _dash_iframe > 0.0:
		_hurt_cd = maxf(_hurt_cd, 0.05)
	_attack_cd -= delta
	if _attack_cd <= 0.0 and _try_fire():
		_attack_cd = float(cbt.get("auto_attack_interval", 0.42))

func take_hit(amount: int, from_pos: Vector2 = Vector2.INF) -> void:
	if GameState.dead or (_hurt_cd > 0.0 and _dash_iframe <= 0.0):
		return
	if _dash_iframe > 0.0:
		return
	GameState.apply_hurt(amount)
	EventBus.damage_dealt.emit(global_position, amount, true)
	_hurt_cd = float(ContentDB.section("combat").get("hurt_iframes", 0.35))
	if SfxService:
		SfxService.play_hurt()
	# White slap then snap back — readable hit before crimson linger.
	modulate = Color(1.55, 1.55, 1.55)
	if _outline:
		_outline.modulate = Color(1.0, 0.95, 0.95, 0.75)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.15, 0.45, 0.42), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.14)
	var knock := Vector2.ZERO
	if from_pos != Vector2.INF:
		knock = (global_position - from_pos)
		if knock.length_squared() > 0.01:
			knock = knock.normalized()
			velocity += knock * 95.0
	_spawn_hurt_splash(knock)
	pulse_camera(0.1)
	# Directional HUD sting — which side the hit came from.
	if knock.length_squared() > 0.01:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("flash_hurt_directional"):
			hud.call("flash_hurt_directional", -knock)

func _spawn_hurt_splash(dir: Vector2 = Vector2.ZERO) -> void:
	# Dark-crimson foot ring — mirror of kill gold circle, opposite emotion.
	var parent := get_parent()
	if parent == null:
		return
	var bias := dir.normalized() * 10.0 if dir.length_squared() > 0.01 else Vector2.ZERO
	var fill := Polygon2D.new()
	fill.z_index = 5
	fill.color = Color(0.75, 0.12, 0.14, 0.42)
	var fpts: PackedVector2Array = []
	for i in 16:
		var a0 := TAU * float(i) / 16.0
		fpts.append(Vector2(cos(a0), sin(a0)) * 7.0)
	fill.polygon = fpts
	parent.add_child(fill)
	fill.global_position = global_position + Vector2(0, 6) + bias * 0.35
	fill.scale = Vector2(0.7, 0.45)
	var ftw := fill.create_tween()
	ftw.tween_property(fill, "scale", Vector2(2.2, 1.2), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ftw.parallel().tween_property(fill, "modulate:a", 0.0, 0.14)
	ftw.tween_callback(fill.queue_free)
	var ring := Line2D.new()
	ring.width = 2.6
	ring.default_color = Color(0.85, 0.18, 0.2, 0.9)
	ring.z_index = 6
	for i in 21:
		var a := TAU * float(i) / 20.0
		ring.add_point(Vector2(cos(a), sin(a)) * 10.0)
	parent.add_child(ring)
	ring.global_position = global_position + Vector2(0, 6) + bias * 0.35
	ring.scale = Vector2(1.0, 0.55)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(2.6, 1.35), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tw.tween_callback(ring.queue_free)
	# Tiny radial flecks — bias toward impact direction when known.
	for i in 6:
		var fleck := Line2D.new()
		fleck.width = 1.6
		fleck.default_color = Color(0.9, 0.25, 0.28, 0.85)
		fleck.z_index = 7
		var ang := TAU * float(i) / 6.0 + 0.2
		if dir.length_squared() > 0.01:
			ang = dir.angle() + (float(i) - 2.5) * 0.35
		fleck.add_point(Vector2.ZERO)
		fleck.add_point(Vector2(cos(ang), sin(ang) * 0.55) * 8.0)
		parent.add_child(fleck)
		fleck.global_position = global_position + Vector2(0, 5) + bias * 0.5
		var ftw2 := fleck.create_tween()
		ftw2.tween_property(fleck, "scale", Vector2(2.4, 2.4), 0.12)
		ftw2.parallel().tween_property(fleck, "modulate:a", 0.0, 0.12)
		ftw2.tween_callback(fleck.queue_free)
	# Directional slash tick — side the hit came from.
	if dir.length_squared() > 0.01:
		var n := dir.normalized()
		var slash := Line2D.new()
		slash.width = 3.2
		slash.default_color = Color(1.0, 0.35, 0.32, 0.9)
		slash.z_index = 8
		slash.add_point(-n * 6.0)
		slash.add_point(n * 16.0)
		parent.add_child(slash)
		slash.global_position = global_position + Vector2(0, -4)
		var stw := slash.create_tween()
		stw.tween_property(slash, "modulate:a", 0.0, 0.16)
		stw.parallel().tween_property(slash, "position", slash.position + n * 10.0, 0.16)
		stw.tween_callback(slash.queue_free)

func soft_revive_guard(seconds: float = 1.1) -> void:
	# Brief iframe after R-revive so early deaths don't chain instantly.
	_hurt_cd = maxf(_hurt_cd, seconds)
	_revive_flash_t = maxf(_revive_flash_t, seconds)
	modulate = Color(0.65, 1.08, 0.92)
	if _outline:
		_outline.modulate = Color(0.35, 0.98, 0.85, 0.8)
		if _visual:
			_outline.scale = _visual.scale * 1.14
	if _aura:
		_aura.modulate = Color(0.4, 0.95, 0.82, 0.75)
	_spawn_revive_land_ring()
	pulse_camera(0.08)
	# HUD jade rim — opposite of death gold pity, same family as 愈地.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_revive_edges"):
		hud.call("flash_revive_edges")
	elif hud and hud.has_method("flash_heal_enter_edges"):
		hud.call("flash_heal_enter_edges")

func _end_revive_flash_tint() -> void:
	modulate = Color.WHITE
	if _outline and _visual:
		_outline.modulate = Color(0.04, 0.05, 0.08, 0.4)
		_outline.scale = _visual.scale * 1.03
	if _aura:
		_aura.modulate = Color(1, 1, 1, 0.4)

## Jade moon scar underfoot — marks soft-revive iframe (pairs dash cyan land).
func _spawn_revive_land_ring() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var at := global_position + Vector2(0, 5)
	var fill := Polygon2D.new()
	fill.z_index = 4
	fill.color = Color(0.4, 0.95, 0.82, 0.4)
	var fpts: PackedVector2Array = []
	for i in 20:
		var a0 := TAU * float(i) / 20.0
		fpts.append(Vector2(cos(a0) * 12.0, sin(a0) * 6.0))
	fill.polygon = fpts
	parent.add_child(fill)
	fill.global_position = at
	fill.scale = Vector2(0.4, 0.4)
	var ftw := fill.create_tween()
	ftw.tween_property(fill, "scale", Vector2(1.45, 1.2), 0.1)
	ftw.tween_property(fill, "scale", Vector2(1.85, 1.45), 0.2)
	ftw.parallel().tween_property(fill, "modulate:a", 0.0, 0.2)
	ftw.tween_callback(fill.queue_free)
	var rim := Line2D.new()
	rim.width = 2.4
	rim.default_color = Color(0.55, 1.0, 0.88, 0.95)
	rim.z_index = 6
	for i in 29:
		var a := TAU * float(i) / 28.0
		rim.add_point(Vector2(cos(a) * 15.0, sin(a) * 7.0))
	parent.add_child(rim)
	rim.global_position = at
	rim.scale = Vector2(0.55, 0.55)
	var rtw := rim.create_tween()
	rtw.tween_property(rim, "scale", Vector2(1.7, 1.4), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.parallel().tween_property(rim, "modulate:a", 0.0, 0.26)
	rtw.tween_callback(rim.queue_free)
	# Soft rising mote — hope, not a second combat VFX pile.
	for i in 3:
		var mote := Polygon2D.new()
		mote.z_index = 7
		mote.color = Color(0.55, 1.0, 0.9, 0.7 - float(i) * 0.12)
		mote.polygon = PackedVector2Array([
			Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2),
		])
		parent.add_child(mote)
		var ox := float(i - 1) * 8.0
		mote.global_position = global_position + Vector2(ox, -10)
		var mtw := mote.create_tween()
		mtw.tween_interval(float(i) * 0.04)
		mtw.tween_property(mote, "global_position", mote.global_position + Vector2(ox * 0.2, -28), 0.32)
		mtw.parallel().tween_property(mote, "modulate:a", 0.0, 0.32)
		mtw.tween_callback(mote.queue_free)

func _try_fire(mult: float = 1.0) -> bool:
	if _projectiles == null:
		return false
	var target := _nearest_mob()
	if target == null:
		return false
	var dir := target.global_position - global_position
	if dir.length_squared() < 0.01:
		dir = _facing
	dir = dir.normalized()
	var bolt := preload("res://scenes/world/projectile.tscn").instantiate()
	_projectiles.add_child(bolt)
	bolt.launch(global_position + Vector2(0, -8), dir, mult)
	_spawn_melee_muzzle(dir)
	return true

func _spawn_melee_muzzle(dir: Vector2) -> void:
	# Tiny facing slash so auto-fire reads as sword qi, not silent bolts.
	var parent := get_parent()
	if parent == null:
		return
	var arc := Line2D.new()
	arc.width = 2.0
	arc.default_color = Color(0.75, 0.92, 1.0, 0.75)
	arc.z_index = 6
	var base := dir.angle()
	for i in 5:
		var a := base - 0.55 + 0.275 * float(i)
		arc.add_point(Vector2.from_angle(a) * 14.0)
	parent.add_child(arc)
	arc.global_position = global_position + Vector2(0, -6)
	var tw := arc.create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, 0.1)
	tw.parallel().tween_property(arc, "scale", Vector2(1.35, 1.35), 0.1)
	tw.tween_callback(arc.queue_free)
	if _visual:
		_visual.scale = Vector2(1.06, 0.94)
		var vtw := create_tween()
		vtw.tween_property(_visual, "scale", Vector2.ONE, 0.08)

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
		_mark_input_handled()
		SceneManager.go_stage_select()
	elif _is_key(event, KEY_J):
		GameState.cultivate_attack()
		_mark_input_handled()
	elif _is_key(event, KEY_K):
		_try_breakthrough()
		_mark_input_handled()
	elif _is_key(event, KEY_R):
		if GameState.dead:
			GameState.revive()
			soft_revive_guard(1.15)
			var tip := "再起"
			if GameState.stage_id in ["sect", "country"]:
				tip = "再起 · 伤↑"
			FloatTextManager.show_message(global_position + Vector2(0, -36), tip, Color(0.55, 0.98, 0.85))
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_clear"):
				hud.call("show_clear", tip)
		_mark_input_handled()
	elif _is_key(event, KEY_L):
		_use_skill("dash")
		_mark_input_handled()
	elif _is_key(event, KEY_U):
		_use_skill("ring_slash")
		_mark_input_handled()
	elif _is_key(event, KEY_I):
		_use_skill("use_pill")
		_mark_input_handled()
	elif _is_key(event, KEY_O):
		_use_skill("spirit_burst")
		_mark_input_handled()

func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()

func _try_breakthrough() -> void:
	var result := GameState.try_breakthrough()
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", ""))
		if reason == "not_enough_attack":
			FloatTextManager.show_message(global_position + Vector2(0, -28), "攻不足", Color(0.95, 0.55, 0.45))
		elif reason == "already_peak":
			FloatTextManager.show_message(global_position + Vector2(0, -28), "巅峰", Color(0.75, 0.75, 0.8))

func _use_skill(skill_id: String) -> void:
	if GameState.dead:
		return
	if float(_skill_cd.get(skill_id, 0.0)) > 0.0:
		EventBus.skill_denied.emit(skill_id, "cooldown")
		return
	var cfg := ContentDB.get_skill(skill_id)
	if cfg.is_empty():
		return
	var cd := float(cfg.get("cooldown", 1.0))
	match skill_id:
		"dash":
			_do_dash(cfg)
		"ring_slash":
			_do_ring_slash(cfg)
		"use_pill":
			if not _do_use_pill(cfg):
				EventBus.skill_denied.emit(skill_id, "empty")
				return
		"spirit_burst":
			_do_spirit_burst(cfg)
	_skill_cd[skill_id] = cd
	EventBus.skill_used.emit(skill_id, cd)

func pulse_camera(strength: float = 0.08) -> void:
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var amp := (3.0 + strength * 40.0) * (1.0 + minf(float(GameState.combo) * 0.025, 0.4))
	var shake := create_tween()
	shake.tween_property(cam, "offset", Vector2(amp, -amp * 0.7), 0.03)
	shake.tween_property(cam, "offset", Vector2(-amp * 0.8, amp * 0.5), 0.04)
	shake.tween_property(cam, "offset", Vector2.ZERO, 0.06)
	if GameState.combo >= 12:
		var z0 := cam.zoom
		var ztw := create_tween()
		ztw.tween_property(cam, "zoom", z0 * 1.03, 0.05)
		ztw.tween_property(cam, "zoom", z0, 0.12)

func _do_dash(cfg: Dictionary) -> void:
	var dir := _move_axis()
	if dir == Vector2.ZERO:
		dir = _facing
	dir = dir.normalized()
	var dist := float(cfg.get("dash_distance", 90))
	var from := global_position
	var to := from + dir * dist
	to.x = clampf(to.x, bounds.position.x, bounds.end.x)
	to.y = clampf(to.y, bounds.position.y, bounds.end.y)
	_spawn_dash_trail(from, to, dir)
	global_position = to
	_dash_iframe = float(cfg.get("iframe", 0.32))
	if SfxService:
		SfxService.play_dash()
	FloatTextManager.show_message(global_position + Vector2(0, -28), "闪", Color(0.55, 0.95, 1.0))
	# Landing ring + dust — marks invuln start mid-swarm.
	_spawn_dash_land_ring(dir)
	modulate = Color(0.65, 0.95, 1.2)
	pulse_camera(0.06)

func _end_dash_iframe_tint() -> void:
	var low := GameState.max_hp > 0 and float(GameState.hp) / float(GameState.max_hp) <= 0.3
	if low and not GameState.dead:
		# Crisis breath resumes next frame.
		pass
	else:
		modulate = Color.WHITE
		if _outline:
			_outline.modulate = Color(0.04, 0.05, 0.08, 0.4)
			_outline.scale = _visual.scale * 1.03
	if _aura:
		_aura.modulate = Color(1, 1, 1, 0.4)

func _end_burst_flash_tint() -> void:
	# Hand outline/aura back to zone / crisis breath next frame.
	if _outline:
		_outline.modulate = Color(0.04, 0.05, 0.08, 0.4)
		_outline.scale = _visual.scale * 1.03
	if _aura:
		_aura.modulate = Color(1, 1, 1, 0.4)
	modulate = Color.WHITE

func _end_pill_flash_tint() -> void:
	# Hand jade silhouette back after 服丹 window.
	if _outline:
		_outline.modulate = Color(0.04, 0.05, 0.08, 0.4)
		_outline.scale = _visual.scale * 1.03
	if _aura:
		_aura.modulate = Color(1, 1, 1, 0.4)
	modulate = Color.WHITE

func _spawn_dash_trail(from: Vector2, to: Vector2, dir: Vector2) -> void:
	if _visual == null or _visual.texture == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	# 4 afterimages along the path — cyan rim, staggered fade.
	var steps := 4
	for i in steps:
		var t := float(i) / float(steps)
		var ghost := Sprite2D.new()
		ghost.texture = _visual.texture
		ghost.scale = _visual.scale * (1.0 - t * 0.08)
		ghost.flip_h = _visual.flip_h
		ghost.modulate = Color(0.45, 0.85, 1.0, 0.55 - t * 0.1)
		ghost.global_position = from.lerp(to, t) + _visual.position - dir * 4.0
		ghost.z_index = int(ghost.global_position.y) - 1
		parent.add_child(ghost)
		# Soft silhouette plate behind the sprite for readability on busy ground.
		var plate := Polygon2D.new()
		plate.color = Color(0.35, 0.8, 1.0, 0.22 - t * 0.04)
		plate.polygon = PackedVector2Array([
			Vector2(-10, -6), Vector2(10, -6), Vector2(8, 8), Vector2(-8, 8),
		])
		plate.z_index = -1
		ghost.add_child(plate)
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.22 + float(i) * 0.05)
		tw.parallel().tween_property(ghost, "scale", ghost.scale * 0.85, 0.22 + float(i) * 0.05)
		tw.tween_callback(ghost.queue_free)

func _spawn_dash_land_ring(dir: Vector2 = Vector2.RIGHT) -> void:
	# Cyan-white moon scar underfoot — one beat that marks where invuln began.
	var parent := get_parent()
	if parent == null:
		return
	var n := dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	var side := n.orthogonal()
	var at := global_position + Vector2(0, 5)
	var fill := Polygon2D.new()
	fill.z_index = 4
	fill.color = Color(0.55, 0.92, 1.0, 0.38)
	var fpts: PackedVector2Array = []
	for i in 20:
		var a0 := TAU * float(i) / 20.0
		fpts.append(Vector2(cos(a0) * 11.0, sin(a0) * 5.5))
	fill.polygon = fpts
	parent.add_child(fill)
	fill.global_position = at
	fill.scale = Vector2(0.45, 0.45)
	var ftw := fill.create_tween()
	ftw.tween_property(fill, "scale", Vector2(1.35, 1.15), 0.08)
	ftw.tween_property(fill, "scale", Vector2(1.7, 1.35), 0.16)
	ftw.parallel().tween_property(fill, "modulate:a", 0.0, 0.16)
	ftw.tween_callback(fill.queue_free)
	# Outer ellipse rim.
	var rim := Line2D.new()
	rim.width = 2.6
	rim.default_color = Color(0.75, 0.98, 1.0, 0.95)
	rim.z_index = 6
	for i in 29:
		var a := TAU * float(i) / 28.0
		rim.add_point(Vector2(cos(a) * 14.0, sin(a) * 6.5))
	parent.add_child(rim)
	rim.global_position = at
	rim.scale = Vector2(0.6, 0.6)
	var rtw := rim.create_tween()
	rtw.tween_property(rim, "scale", Vector2(1.55, 1.35), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.parallel().tween_property(rim, "modulate:a", 0.0, 0.22)
	rtw.tween_callback(rim.queue_free)
	# Crescent chord — reads as a moon mark, not a plain circle.
	var crescent := Line2D.new()
	crescent.width = 2.2
	crescent.default_color = Color(0.9, 0.98, 1.0, 0.92)
	crescent.z_index = 7
	for i in 11:
		var t := float(i) / 10.0
		var a2 := -0.85 + 1.7 * t
		crescent.add_point(Vector2(cos(a2) * 12.0, sin(a2) * 5.2) + Vector2(2.5, 0))
	parent.add_child(crescent)
	crescent.global_position = at
	var ctw := crescent.create_tween()
	ctw.tween_property(crescent, "modulate:a", 0.0, 0.26)
	ctw.parallel().tween_property(crescent, "scale", Vector2(1.25, 1.15), 0.26)
	ctw.tween_callback(crescent.queue_free)
	# Landing dust — cyan grit kicked sideways opposite the dash.
	for i in 6:
		var dust := Polygon2D.new()
		dust.z_index = 5
		dust.color = Color(0.65, 0.9, 1.0, 0.7 - float(i) * 0.06)
		var s := 1.6 + float(i % 3) * 0.5
		dust.polygon = PackedVector2Array([
			Vector2(-s, -s * 0.5), Vector2(s, -s * 0.5), Vector2(s * 0.7, s), Vector2(-s * 0.7, s),
		])
		parent.add_child(dust)
		var lateral := (1.0 if i % 2 == 0 else -1.0)
		var kick := -n * randf_range(6.0, 14.0) + side * lateral * randf_range(10.0, 22.0) + Vector2(0, randf_range(-2.0, 4.0))
		dust.global_position = at + kick * 0.15
		var dtw := dust.create_tween()
		dtw.tween_property(dust, "position", dust.position + kick, 0.18 + float(i) * 0.015).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dtw.parallel().tween_property(dust, "modulate:a", 0.0, 0.18 + float(i) * 0.015)
		dtw.parallel().tween_property(dust, "scale", Vector2(0.4, 0.4), 0.18)
		dtw.tween_callback(dust.queue_free)

func _do_ring_slash(cfg: Dictionary) -> void:
	var radius := float(cfg.get("radius", 110))
	var mult := float(cfg.get("damage_mult", 1.6))
	# Brief wind-up punch so the cut lands as a beat, not a silent AoE.
	if _visual:
		_visual.scale = Vector2(0.88, 1.12)
		var vtw := create_tween()
		vtw.tween_property(_visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	# Resolve hits first — gold FX only on connect (whiff stays cool cyan-gray).
	var hit_mobs: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var mob := node as Node2D
		if global_position.distance_to(mob.global_position) > radius:
			continue
		if mob.has_method("take_damage"):
			hit_mobs.append(mob)
	var hits := hit_mobs.size()
	if hits > 0:
		last_ring_connected = true
		if SfxService:
			SfxService.play_ring_hit()
		_spawn_ring_fx(radius)
		for mob in hit_mobs:
			var defense := 0
			if mob.get("def") != null:
				defense = int(mob.def.defense)
			var knock := (mob.global_position - global_position).normalized()
			if knock.length_squared() < 0.01:
				knock = _facing
			mob.call("take_damage", GameState.projectile_damage_against(defense, mult), knock * 1.15)
			_spawn_slash_mark(mob.global_position, knock)
		FloatTextManager.show_message(global_position + Vector2(0, -32), "环斩×%d" % hits, Color(1.0, 0.9, 0.45))
		_flash_ring_body(true)
		# Soft hitch only — short, capped, and skipped if already hitching.
		var world := get_tree().get_first_node_in_group("game_world")
		if world and world.has_method("hitstop"):
			var hs := 0.016 + minf(float(hits) * 0.003, 0.014)
			world.hitstop(hs)
		pulse_camera(0.11 + minf(float(hits) * 0.014, 0.08))
	else:
		# Empty swing — cool cyan-gray only, no gold dopamine, soft air SFX.
		last_ring_connected = false
		if SfxService:
			SfxService.play_skill_miss()
		_spawn_ring_miss_fx(radius)
		FloatTextManager.show_message(global_position + Vector2(0, -32), "空", Color(0.58, 0.72, 0.8))
		_flash_ring_body(false)
		pulse_camera(0.03)

func _flash_ring_body(hit: bool) -> void:
	# Body silhouette confirms connect (gold) vs whiff (cool cyan).
	if hit:
		modulate = Color(1.25, 1.1, 0.75)
		if _outline:
			_outline.modulate = Color(1.0, 0.85, 0.35, 0.85)
			_outline.scale = _visual.scale * 1.1
		if _aura:
			_aura.modulate = Color(1.0, 0.85, 0.4, 0.65)
	else:
		modulate = Color(0.75, 0.85, 0.95)
		if _outline:
			_outline.modulate = Color(0.45, 0.65, 0.8, 0.55)
			_outline.scale = _visual.scale * 1.04
		if _aura:
			_aura.modulate = Color(0.5, 0.7, 0.85, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.16 if hit else 0.12)
	if _outline:
		tw.parallel().tween_property(_outline, "modulate", Color(0.04, 0.05, 0.08, 0.4), 0.18)
		tw.parallel().tween_property(_outline, "scale", _visual.scale * 1.03, 0.18)

func _spawn_slash_mark(at: Vector2, dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ang := dir.angle() if dir.length_squared() > 0.01 else randf() * TAU
	# Twin gold scars — ring-slash hits must read vs auto-attack sparks.
	for k in 2:
		var scar := Line2D.new()
		scar.width = 2.8 - float(k) * 0.5
		scar.default_color = Color(1.0, 0.94, 0.48, 1.0 - float(k) * 0.18)
		scar.z_index = 12
		var spread := 0.55 if k == 0 else -0.7
		var a := ang + spread
		scar.add_point(Vector2.from_angle(a) * -10.0)
		scar.add_point(Vector2.from_angle(a) * 13.0)
		parent.add_child(scar)
		scar.global_position = at + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		# Hold opaque a beat (pairs with soft hitstop), then fade.
		var tw := scar.create_tween()
		tw.tween_interval(0.04)
		tw.tween_property(scar, "modulate:a", 0.0, 0.2 + float(k) * 0.04)
		tw.parallel().tween_property(scar, "scale", Vector2(1.55, 1.55), 0.2)
		tw.tween_callback(scar.queue_free)
	# Tiny hit ripple on the mob.
	var rip := Line2D.new()
	rip.width = 1.8
	rip.default_color = Color(1.0, 0.88, 0.4, 0.9)
	rip.z_index = 11
	for i in 13:
		var a2 := TAU * float(i) / 12.0
		rip.add_point(Vector2(cos(a2), sin(a2)) * 6.0)
	parent.add_child(rip)
	rip.global_position = at
	rip.scale = Vector2(0.4, 0.4)
	var rtw := rip.create_tween()
	rtw.tween_property(rip, "scale", Vector2(2.4, 2.4), 0.16)
	rtw.parallel().tween_property(rip, "modulate:a", 0.0, 0.16)
	rtw.tween_callback(rip.queue_free)

func _spawn_ring_miss_fx(radius: float) -> void:
	# Dashed cool wash — empty swing must never look like a gold cut.
	var parent := get_parent()
	if parent == null:
		return
	var wash := Polygon2D.new()
	wash.z_index = 5
	wash.color = Color(0.45, 0.62, 0.72, 0.22)
	var wpts: PackedVector2Array = []
	for i in 28:
		var a0 := TAU * float(i) / 28.0
		wpts.append(Vector2(cos(a0), sin(a0)) * 8.0)
	wash.polygon = wpts
	parent.add_child(wash)
	wash.global_position = global_position
	var wtw := wash.create_tween()
	wtw.tween_property(wash, "scale", Vector2(radius / 10.0, radius / 10.0), 0.16)
	wtw.parallel().tween_property(wash, "modulate:a", 0.0, 0.16)
	wtw.tween_callback(wash.queue_free)
	# Broken rim segments — reads as "cut the air", not a closed kill circle.
	var segs := 6
	for s in segs:
		var rim := Line2D.new()
		rim.width = 1.8
		rim.default_color = Color(0.55, 0.72, 0.82, 0.65)
		rim.z_index = 6
		var start := TAU * float(s) / float(segs) + 0.08
		var span := TAU / float(segs) * 0.55
		var r := maxf(radius * 0.92, 28.0)
		for i in 8:
			var a := start + span * float(i) / 7.0
			rim.add_point(Vector2(cos(a), sin(a)) * r)
		parent.add_child(rim)
		rim.global_position = global_position
		rim.scale = Vector2(0.82, 0.82)
		var tw := rim.create_tween()
		tw.tween_property(rim, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(rim, "modulate:a", 0.0, 0.16)
		tw.tween_callback(rim.queue_free)

func _spawn_ring_fx(radius: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Gold disc bloom.
	var ring := Polygon2D.new()
	ring.z_index = 5
	ring.color = Color(1.0, 0.82, 0.35, 0.48)
	var pts: PackedVector2Array = []
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * 8.0)
	ring.polygon = pts
	parent.add_child(ring)
	ring.global_position = global_position
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(radius / 8.0, radius / 8.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tw.tween_callback(ring.queue_free)
	# Expanding ripples — skill identity: gold shockwaves, not a static disc.
	for wave in 3:
		var rip := Line2D.new()
		rip.width = 2.8 - float(wave) * 0.5
		rip.default_color = Color(1.0, 0.9, 0.42, 0.95 - float(wave) * 0.18)
		rip.z_index = 6
		for i in 33:
			var a2 := TAU * float(i) / 32.0
			rip.add_point(Vector2(cos(a2), sin(a2)) * 10.0)
		parent.add_child(rip)
		rip.global_position = global_position
		rip.scale = Vector2(0.2, 0.2)
		var delay := float(wave) * 0.05
		var target := radius / 10.0 * (0.7 + float(wave) * 0.18)
		var twr := rip.create_tween()
		twr.tween_interval(delay)
		twr.tween_property(rip, "scale", Vector2(target, target), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		twr.parallel().tween_property(rip, "modulate:a", 0.0, 0.22)
		twr.tween_callback(rip.queue_free)
	# Outer rim tick marks — "this circle cuts".
	var rim := Line2D.new()
	rim.width = 3.2
	rim.default_color = Color(1.0, 0.92, 0.45, 1.0)
	rim.z_index = 7
	for i in 33:
		var a3 := TAU * float(i) / 32.0
		rim.add_point(Vector2(cos(a3), sin(a3)) * radius)
	parent.add_child(rim)
	rim.global_position = global_position
	for i in 8:
		var tick := Line2D.new()
		tick.width = 2.0
		tick.default_color = Color(1.0, 0.95, 0.65, 0.95)
		tick.z_index = 7
		var a4 := TAU * float(i) / 8.0 + _facing.angle()
		tick.add_point(Vector2.from_angle(a4) * (radius * 0.88))
		tick.add_point(Vector2.from_angle(a4) * (radius * 1.06))
		parent.add_child(tick)
		tick.global_position = global_position
		var twt := tick.create_tween()
		twt.tween_property(tick, "modulate:a", 0.0, 0.26)
		twt.tween_callback(tick.queue_free)
	var tw2 := rim.create_tween()
	tw2.tween_property(rim, "modulate:a", 0.0, 0.28)
	tw2.tween_callback(rim.queue_free)
	# Sweeping sword arcs — ring slash identity vs cyan burst.
	for k in 4:
		var blade := Line2D.new()
		blade.width = 2.6 - float(k) * 0.35
		blade.default_color = Color(1.0, 0.96, 0.7, 0.9 - float(k) * 0.12)
		blade.z_index = 8
		var start_a := -1.0 + float(k) * 0.4 + _facing.angle()
		for i in 12:
			var a5 := start_a + float(i) * 0.2
			var r := radius * (0.3 + float(i) * 0.06)
			blade.add_point(Vector2(cos(a5), sin(a5)) * r)
		parent.add_child(blade)
		blade.global_position = global_position
		blade.rotation = float(k) * 0.35
		var tw3 := blade.create_tween()
		tw3.tween_property(blade, "rotation", blade.rotation + 1.25, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw3.parallel().tween_property(blade, "modulate:a", 0.0, 0.2)
		tw3.tween_callback(blade.queue_free)

func _do_use_pill(cfg: Dictionary) -> bool:
	var priority: Array = cfg.get("pill_priority", [])
	var result := GameState.use_pill_from_inventory(priority)
	if not bool(result.get("ok", false)):
		FloatTextManager.show_message(global_position + Vector2(0, -28), "无丹", Color(0.75, 0.75, 0.8))
		return false
	if SfxService:
		SfxService.play_pill()
	var healed := int(result.get("healed", 0))
	FloatTextManager.show_message(global_position + Vector2(0, -28), "+%d" % healed, Color(0.45, 0.98, 0.7))
	# Jade heal rings — same language as heal-zone silhouette / edge wash.
	_spawn_pill_heal_fx()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("pulse_hp_heal"):
		hud.call("pulse_hp_heal", healed)
	return true

func _spawn_pill_heal_fx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Triple jade rings — louder than buy stall, matches 愈地 language.
	for ring_i in 3:
		var ring := Line2D.new()
		ring.width = 2.6 - float(ring_i) * 0.35
		ring.default_color = Color(0.32, 0.98, 0.7, 0.9 - float(ring_i) * 0.18)
		ring.z_index = 7
		var r0 := 10.0 + float(ring_i) * 7.0
		for i in 25:
			var a := TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(a), sin(a)) * r0)
		parent.add_child(ring)
		ring.global_position = global_position
		var delay := float(ring_i) * 0.035
		var tw := ring.create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
		tw.tween_callback(ring.queue_free)
	# Body jade window — pairs HUD 翠缘 / KeyI bag (~0.3s).
	_pill_flash_t = 0.3
	modulate = Color(0.78, 1.2, 0.95)
	if _outline:
		_outline.modulate = Color(0.28, 0.98, 0.68, 0.85)
		_outline.scale = _visual.scale * 1.12
	if _aura:
		_aura.modulate = Color(0.35, 0.98, 0.72, 0.7)
	if _visual:
		_visual.modulate = Color(0.85, 1.25, 1.05)
		var vtw := create_tween()
		vtw.tween_property(_visual, "modulate", Color.WHITE, 0.28)

func _do_spirit_burst(cfg: Dictionary) -> void:
	if _projectiles == null:
		return
	if SfxService:
		SfxService.play_skill()
	_spawn_spirit_burst_fx()
	var count := int(cfg.get("projectiles", 8))
	var mult := float(cfg.get("damage_mult", 0.85))
	for i in count:
		var angle := TAU * float(i) / float(count)
		var dir := Vector2.from_angle(angle)
		var bolt := preload("res://scenes/world/projectile.tscn").instantiate()
		_projectiles.add_child(bolt)
		bolt.launch(global_position + Vector2(0, -8), dir, mult, "burst")
	FloatTextManager.show_message(global_position + Vector2(0, -36), "灵爆", Color(1.0, 0.75, 0.35))
	pulse_camera(0.1)

func _spawn_spirit_burst_fx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Gold-ember nova — distinct from cyan auto and gold ring-slash disc.
	var fill := Polygon2D.new()
	fill.z_index = 6
	fill.color = Color(1.0, 0.65, 0.3, 0.35)
	var fpts: PackedVector2Array = []
	for i in 20:
		var a0 := TAU * float(i) / 20.0
		fpts.append(Vector2(cos(a0), sin(a0)) * 10.0)
	fill.polygon = fpts
	parent.add_child(fill)
	fill.global_position = global_position
	var ftw := fill.create_tween()
	ftw.tween_property(fill, "scale", Vector2(3.2, 3.2), 0.16)
	ftw.parallel().tween_property(fill, "modulate:a", 0.0, 0.16)
	ftw.tween_callback(fill.queue_free)
	var ring := Line2D.new()
	ring.width = 3.4
	ring.default_color = Color(1.0, 0.82, 0.4, 0.95)
	ring.z_index = 8
	for i in 25:
		var a := TAU * float(i) / 24.0
		ring.add_point(Vector2(cos(a), sin(a)) * 14.0)
	parent.add_child(ring)
	ring.global_position = global_position
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(3.8, 3.8), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ring.queue_free)
	for i in 12:
		var ray := Line2D.new()
		ray.width = 2.0
		ray.default_color = Color(1.0, 0.85, 0.4, 0.9)
		ray.z_index = 7
		var ang := TAU * float(i) / 12.0
		ray.add_point(Vector2.ZERO)
		ray.add_point(Vector2.from_angle(ang) * 32.0)
		parent.add_child(ray)
		ray.global_position = global_position
		var rtw := ray.create_tween()
		rtw.tween_property(ray, "scale", Vector2(2.4, 2.4), 0.18)
		rtw.parallel().tween_property(ray, "modulate:a", 0.0, 0.18)
		rtw.tween_callback(ray.queue_free)
	# Gold-orange outline flash — skill identity on the body, not only the nova.
	# ~0.32s pairs HUD KeyO ember cast lock so dock + silhouette share one beat.
	_burst_flash_t = 0.32
	if _outline:
		_outline.modulate = Color(1.0, 0.72, 0.25, 0.95)
		_outline.scale = _visual.scale * 1.14
	if _aura:
		_aura.modulate = Color(1.0, 0.75, 0.3, 0.75)
	if _visual:
		_visual.modulate = Color(1.35, 0.95, 0.5)
		var vtw := create_tween()
		vtw.tween_property(_visual, "modulate", Color.WHITE, 0.26)

func get_skill_cooldown(skill_id: String) -> float:
	return float(_skill_cd.get(skill_id, 0.0))

## Remaining dash invuln seconds — minimap cyan ring reads iframe.
func get_dash_iframe() -> float:
	return maxf(_dash_iframe, 0.0)

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
