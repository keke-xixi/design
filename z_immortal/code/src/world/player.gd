extends CharacterBody2D

var bounds := Rect2(24, 24, 1000, 700)
var _attack_cd := 0.0
var _hurt_cd := 0.0
var _skill_cd: Dictionary = {}
var _dash_iframe := 0.0
var _facing := Vector2.DOWN
var _projectiles: Node2D

@onready var _visual: Sprite2D = $Visual
@onready var _hp_bar: ColorRect = $HpBar

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	EventBus.player_hp_changed.connect(_on_hp)
	_on_hp(GameState.hp, GameState.max_hp)

func configure(projectiles: Node2D, map_rect: Rect2) -> void:
	_projectiles = projectiles
	bounds = map_rect

func _on_hp(hp: int, max_hp: int) -> void:
	var ratio := 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.size.x = 28.0 * ratio
	_hp_bar.color = Color(0.35, 0.9, 0.45) if ratio > 0.35 else Color(0.95, 0.35, 0.3)

func _physics_process(delta: float) -> void:
	if GameState.dead:
		velocity = Vector2.ZERO
		return
	for key in _skill_cd.keys():
		_skill_cd[key] = maxf(float(_skill_cd[key]) - delta, 0.0)
	if _dash_iframe > 0.0:
		_dash_iframe -= delta
	var cbt := ContentDB.section("combat")
	var speed := float(cbt.get("player_speed", 96)) * GameState.effective_speed_mult()
	var direction := _move_axis()
	if direction != Vector2.ZERO:
		_facing = direction
		_visual.flip_h = direction.x < 0.0
	velocity = direction * speed
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

func take_hit(amount: int) -> void:
	if GameState.dead or (_hurt_cd > 0.0 and _dash_iframe <= 0.0):
		return
	if _dash_iframe > 0.0:
		return
	GameState.apply_hurt(amount)
	EventBus.damage_dealt.emit(global_position, amount, true)
	_hurt_cd = float(ContentDB.section("combat").get("hurt_iframes", 0.35))
	modulate = Color(1.0, 0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		var shake := create_tween()
		shake.tween_property(cam, "offset", Vector2(4, -3), 0.04)
		shake.tween_property(cam, "offset", Vector2(-3, 2), 0.04)
		shake.tween_property(cam, "offset", Vector2.ZERO, 0.06)

func _try_fire(mult: float = 1.0) -> bool:
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
	bolt.launch(global_position + Vector2(0, -8), dir.normalized(), mult)
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
		_mark_input_handled()
		SceneManager.go_stage_select()
	elif _is_key(event, KEY_J):
		GameState.cultivate_attack()
		_mark_input_handled()
	elif _is_key(event, KEY_K):
		_try_breakthrough()
		_mark_input_handled()
	elif _is_key(event, KEY_R):
		GameState.revive()
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
			FloatTextManager.show_message(global_position + Vector2(0, -28), "攻不足 %d" % int(result.get("need", 0)), Color(0.95, 0.55, 0.45))
		elif reason == "already_peak":
			FloatTextManager.show_message(global_position + Vector2(0, -28), "已达巅峰", Color(0.75, 0.75, 0.8))

func _use_skill(skill_id: String) -> void:
	if GameState.dead:
		return
	if float(_skill_cd.get(skill_id, 0.0)) > 0.0:
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
				return
		"spirit_burst":
			_do_spirit_burst(cfg)
	_skill_cd[skill_id] = cd
	EventBus.skill_used.emit(skill_id, cd)

func _do_dash(cfg: Dictionary) -> void:
	var dir := _move_axis()
	if dir == Vector2.ZERO:
		dir = _facing
	var dist := float(cfg.get("dash_distance", 90))
	global_position += dir.normalized() * dist
	global_position.x = clampf(global_position.x, bounds.position.x, bounds.end.x)
	global_position.y = clampf(global_position.y, bounds.position.y, bounds.end.y)
	_dash_iframe = float(cfg.get("iframe", 0.25))
	modulate = Color(0.7, 0.9, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)

func _do_ring_slash(cfg: Dictionary) -> void:
	var radius := float(cfg.get("radius", 110))
	var mult := float(cfg.get("damage_mult", 1.6))
	for node in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var mob := node as Node2D
		if global_position.distance_to(mob.global_position) > radius:
			continue
		if mob.has_method("take_damage"):
			var defense := 0
			if mob.get("def") != null:
				defense = int(mob.def.defense)
			mob.take_damage(GameState.projectile_damage_against(defense, mult))
	FloatTextManager.show_message(global_position + Vector2(0, -32), "环斩", Color(0.85, 0.95, 0.55))

func _do_use_pill(cfg: Dictionary) -> bool:
	var priority: Array = cfg.get("pill_priority", [])
	var result := GameState.use_pill_from_inventory(priority)
	if not bool(result.get("ok", false)):
		FloatTextManager.show_message(global_position + Vector2(0, -28), "无丹可服", Color(0.75, 0.75, 0.8))
		return false
	FloatTextManager.show_message(global_position + Vector2(0, -28), "+%d 气血" % int(result.get("healed", 0)), Color(0.55, 0.95, 0.65))
	return true

func _do_spirit_burst(cfg: Dictionary) -> void:
	if _projectiles == null:
		return
	var count := int(cfg.get("projectiles", 8))
	var mult := float(cfg.get("damage_mult", 0.85))
	for i in count:
		var angle := TAU * float(i) / float(count)
		var dir := Vector2.from_angle(angle)
		var bolt := preload("res://scenes/world/projectile.tscn").instantiate()
		_projectiles.add_child(bolt)
		bolt.launch(global_position + Vector2(0, -8), dir, mult)

func get_skill_cooldown(skill_id: String) -> float:
	return float(_skill_cd.get(skill_id, 0.0))

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
