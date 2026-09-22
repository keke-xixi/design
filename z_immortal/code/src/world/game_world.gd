extends Node2D
const TILE := 16
const TILE_GRASS := Vector2i(0, 0)
const TILE_DIRT := Vector2i(1, 0)
const TILE_STONE := Vector2i(2, 0)
const SOURCE_ID := 0

@onready var _bg: Sprite2D = $Background
@onready var _tiles: TileMapLayer = $TileMapLayer
@onready var _player: CharacterBody2D = $Player
@onready var _mobs: Node2D = $Mobs
@onready var _projectiles: Node2D = $Projectiles
@onready var _pickups: Node2D = $Pickups
@onready var _chests: Node2D = $Chests
@onready var _obstacles: Node2D = $Obstacles
@onready var _zones: Node2D = $Zones
@onready var _camera: Camera2D = $Player/Camera2D
var _map_size := Vector2i(48, 30)
var _spawn_acc := 0.0
var _bounds := Rect2()
var _obstacle_rects: Array[Rect2] = []
var _zone_defs: Array[Dictionary] = []
var _last_wave_hint := ""
var _zone_tick := 0.0
var _last_zone_effect := ""
var _overlay: CanvasLayer
var _cleared_stop := false
var _spawn_pause := 0.0
var _hitstopping := false
var _map_pattern := "yard"
var _stage_accent := Color(0.75, 0.95, 1.0)
var _zone_edge_t := 0.0
var _zone_edge_col := Color(0, 0, 0, 0)
var _base_edge_col := Color(0.02, 0.03, 0.05, 0.26)
## Stage wash bases — atmosphere breath lerps from these (sect cool / city warm).
var _bg_base_mod := Color.WHITE
var _tiles_base_mod := Color.WHITE
## Brief spawn beacons for minimap — {pos: Vector2, life: float}.
var _spawn_pings: Array[Dictionary] = []
## Sect early: dwell on 愈地 then punch a close disciple (once per run).
var _heal_rest_acc := 0.0
var _heal_pressure_fired := false

func _ready() -> void:
	_pickups.add_to_group("pickups")
	EventBus.stage_changed.connect(_on_stage_changed)
	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.wave_changed.connect(_on_wave_banner)
	_overlay = preload("res://src/ui/run_overlay.gd").new()
	add_child(_overlay)
	_apply_stage(GameState.stage_id)

func _process(delta: float) -> void:
	_tick_ambient_motes(delta)
	_tick_fg_mist(delta)
	_tick_atmosphere(delta)
	_tick_zone_edge(delta)
	_tick_spawn_pings(delta)
	if GameState.dead:
		return
	GameState.run_time += delta
	_apply_zone_effects(delta)
	_pulse_zone_visuals()
	_tick_heal_rest_pressure(delta)
	if _cleared_stop:
		return
	if _spawn_pause > 0.0:
		_spawn_pause -= delta
	var stage := GameState.current_stage()
	if stage == null:
		return
	var kills := GameState.stage_kills()
	var hint := stage.wave_hint(kills)
	if hint != _last_wave_hint and not hint.is_empty():
		_last_wave_hint = hint
		EventBus.wave_changed.emit(hint)
	if _spawn_pause > 0.0:
		return
	_spawn_acc += delta
	var interval := stage.spawn_interval_for(kills)
	var cap := stage.max_alive_for(kills)
	if _spawn_acc >= interval and _mobs.get_child_count() < cap:
		_spawn_acc = 0.0
		_spawn_one(stage)

func _pulse_zone_visuals() -> void:
	# Shared clocks: heal uses player HEAL_PULSE_HZ — calm jade vs 破绽 warm gold punch.
	var t_ms := Time.get_ticks_msec()
	var t_fast := t_ms * 0.003
	for z in _zone_defs:
		var effect := str(z.get("effect", ""))
		var vis: Variant = z.get("visual", null)
		var rim: Variant = z.get("rim", null)
		var well: Variant = z.get("well", null)
		var guide: Variant = z.get("guide", null)
		var mark: Variant = z.get("mark", null)
		var active := effect == _last_zone_effect and not _last_zone_effect.is_empty()
		if effect == "heal":
			# Cool breath — half-beat snappier, still opposite of boss 破绽 gold flash.
			var hbreath := 0.5 + 0.5 * sin(t_ms * 0.010)
			var phase := float(z.get("pulse_phase", 0.0))
			if vis is CanvasItem and is_instance_valid(vis):
				var boost := 1.2 if active else 1.0
				(vis as CanvasItem).modulate = Color(
					0.85 + 0.1 * hbreath,
					1.0,
					0.92 + 0.08 * hbreath,
					(0.72 + 0.28 * hbreath) * boost
				)
				(vis as Node2D).scale = Vector2.ONE * (1.0 + 0.04 * hbreath)
			if rim is CanvasItem and is_instance_valid(rim):
				(rim as CanvasItem).modulate = Color(0.45, 1.0, 0.82, 0.55 + 0.4 * hbreath)
				(rim as Node2D).scale = Vector2.ONE * (1.0 + 0.06 * hbreath)
			if well is CanvasItem and is_instance_valid(well):
				(well as CanvasItem).modulate.a = 0.45 + 0.45 * hbreath
				(well as Node2D).scale = Vector2.ONE * (0.92 + 0.12 * hbreath)
			if guide is CanvasItem and is_instance_valid(guide):
				(guide as CanvasItem).modulate = Color(0.55, 1.0, 0.85, 0.35 + 0.45 * hbreath)
				(guide as Node2D).scale = Vector2.ONE * (1.0 + 0.03 * hbreath)
			# Soft alpha only — leave scale to enter-pop so glyph pop still reads.
			if mark is CanvasItem and is_instance_valid(mark):
				(mark as CanvasItem).modulate = Color(0.55 + 0.25 * hbreath, 1.0, 0.8, 0.75 + 0.25 * hbreath)
			# Expanding calm echo — soft jade, never a gold punish bloom.
			_tick_heal_breath_ring(z, hbreath, phase)
		else:
			if vis is CanvasItem and is_instance_valid(vis):
				var boost2 := 1.25 if active else 1.0
				(vis as CanvasItem).modulate.a = (0.7 + 0.3 * sin(t_fast + float(z.get("radius", 1.0)))) * boost2
			if rim is CanvasItem and is_instance_valid(rim) and active:
				(rim as CanvasItem).modulate.a = 0.75 + 0.25 * sin(t_fast * 2.2)

func _tick_heal_breath_ring(z: Dictionary, hbreath: float, phase: float) -> void:
	# One soft expanding jade ring per heal well — pairs against 破绽's sharp gold nova.
	var life := float(z.get("breath_life", 0.0))
	life -= get_process_delta_time()
	if life <= 0.0:
		# Half-beat faster cycle (was 1.35 / 1.2) — still calm, not a punish flash.
		life = 1.05
		var center: Vector2 = z.get("center", Vector2.ZERO)
		var r0 := float(z.get("radius", 40.0)) * 0.55
		var ring := Line2D.new()
		ring.width = 1.8
		ring.default_color = Color(0.35, 0.95, 0.75, 0.55)
		ring.z_index = 3
		ring.position = center
		for i in 25:
			var a := TAU * float(i) / 24.0 + phase
			ring.add_point(Vector2(cos(a), sin(a)) * r0)
		_zones.add_child(ring)
		ring.scale = Vector2(0.85, 0.85)
		var tw := ring.create_tween()
		tw.tween_property(ring, "scale", Vector2(1.65 + 0.15 * hbreath, 1.65 + 0.15 * hbreath), 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.95)
		tw.tween_callback(ring.queue_free)
	z["breath_life"] = life

func _on_wave_banner(hint: String) -> void:
	_spawn_pause = float(ContentDB.section("combat").get("wave_pause", 0.85))
	if SfxService:
		SfxService.play_wave()
	var banner := get_node_or_null("HUD")
	if banner and banner.has_method("show_clear"):
		banner.show_clear(hint)
	GameState.heal_amount(maxi(int(float(GameState.max_hp) * 0.06), 1))
	# Soft auto-buff on later waves (no modal interrupt).
	if GameState.stage_kills() > 0:
		var cur := float(GameState.run.run_buffs.get("temp_damage", 0.0))
		if cur < 0.24:
			GameState.run.apply_effect({ "temp_damage": 0.03 })
			FloatTextManager.show_message(
				_player.global_position + Vector2(0, -40) if _player else Vector2(320, 140),
				"伤+3%",
				Color(0.95, 0.85, 0.5)
			)
	if _player and _player.has_method("pulse_camera"):
		_player.pulse_camera(0.07)

func hitstop(duration: float = 0.04) -> void:
	if _hitstopping or DisplayServer.get_name() == "headless":
		return
	# Soft hitch — never freeze; keep duration tiny so combat stays fluid.
	_hitstopping = true
	var prev := Engine.time_scale
	var scale := float(ContentDB.section("combat").get("hitstop_scale", 0.28))
	Engine.time_scale = clampf(scale, 0.22, 0.55)
	await get_tree().create_timer(minf(duration, 0.032), true, true).timeout
	Engine.time_scale = prev if prev > 0.1 else 1.0
	_hitstopping = false

func _apply_zone_effects(delta: float) -> void:
	if _player == null or GameState.dead:
		return
	_zone_tick += delta
	if _zone_tick < 0.25:
		return
	_zone_tick = 0.0
	var mods := zone_mods_at(_player.global_position)
	var dps := float(mods.get("dps", 0.0))
	var hps := float(mods.get("hps", 0.0))
	var effect := str(mods.get("effect", ""))
	# One toast when stepping into a new zone type — teaches map without a modal.
	if effect != _last_zone_effect and not effect.is_empty():
		var label := effect
		var col := Color(0.9, 0.9, 0.95)
		match effect:
			"heal":
				label = "灵脉·回血" if _map_pattern == "yard" else "药铺·回血"
				col = Color(0.55, 0.95, 0.7)
			"slow":
				label = "山雾·减速" if _map_pattern == "yard" else "市井·减速"
				col = Color(0.65, 0.55, 0.95)
			"damage":
				label = "煞地·伤血" if _map_pattern != "city" else "刑场·伤血"
				col = Color(1.0, 0.5, 0.4)
		FloatTextManager.show_message(_player.global_position + Vector2(0, -28), label, col)
		# HUD ping + rim flash so zone motive lands even mid-fight.
		var hud := get_node_or_null("HUD")
		if hud and hud.has_method("show_clear") and GameState.stage_id in ["sect", "country"]:
			hud.call("show_clear", label)
		_flash_zone_enter(effect)
	elif effect.is_empty() and not _last_zone_effect.is_empty() and _zone_edge_t <= 0.0:
		_restore_zone_edge()
	_last_zone_effect = effect
	if dps > 0.0:
		_player.take_hit(maxi(int(dps * 0.25), 1))
	if hps > 0.0:
		GameState.heal_amount(maxi(int(hps * 0.25), 1))

func _flash_zone_enter(effect: String) -> void:
	var nearest_mark: Label = null
	var nearest_center := Vector2.ZERO
	var nearest_d := INF
	var player_pos := _player.global_position if _player else Vector2.ZERO
	for z in _zone_defs:
		if str(z.get("effect", "")) != effect:
			continue
		# Heal rim/vis owned by slow jade breath — don't punch warm white over it.
		if effect != "heal":
			var rim: Variant = z.get("rim", null)
			if rim is CanvasItem and is_instance_valid(rim):
				var node := rim as CanvasItem
				node.modulate = Color(1.4, 1.3, 1.1, 1.0)
				var tw := create_tween()
				tw.tween_property(node, "modulate", Color.WHITE, 0.35)
			var vis: Variant = z.get("visual", null)
			if vis is CanvasItem and is_instance_valid(vis):
				var v := vis as CanvasItem
				v.modulate = Color(1.35, 1.25, 1.1, 1.0)
				var tw2 := create_tween()
				tw2.tween_property(v, "modulate", Color.WHITE, 0.4)
		else:
			# Nudge breath echo sooner so enter feels like a calm inhale, not a punish flash.
			z["breath_life"] = minf(float(z.get("breath_life", 1.0)), 0.05)
		var c: Vector2 = z.get("center", Vector2.ZERO)
		var d := player_pos.distance_squared_to(c)
		if d < nearest_d:
			nearest_d = d
			nearest_center = c
			var mark_v: Variant = z.get("mark", null)
			if mark_v is Label and is_instance_valid(mark_v):
				nearest_mark = mark_v as Label
	# 煞/愈/滞 glyph: nearest mark pops then settles — damage trembles hardest.
	if nearest_mark:
		_pulse_zone_mark(nearest_mark, effect)
	# Enter 愈地 → teal; 煞地 → crimson; 滞地 → violet mist.
	if effect == "heal":
		_ping_spawn(nearest_center if nearest_d < INF else player_pos, "jade")
	elif effect == "damage":
		_ping_spawn(nearest_center if nearest_d < INF else player_pos, "ash")
	elif effect == "slow":
		_ping_spawn(nearest_center if nearest_d < INF else player_pos, "mist")
	# Screen-edge motive — 煞地 red vs 愈地 cyan-green, short & crisp.
	match effect:
		"damage":
			_zone_edge_col = Color(0.85, 0.12, 0.1, 0.55)
			_zone_edge_t = 0.28
		"heal":
			_zone_edge_col = Color(0.32, 0.96, 0.78, 0.52)
			_zone_edge_t = 0.48
		"slow":
			# 滞地：蓝紫雾感，与煞红 / 愈绿同级可读.
			_zone_edge_col = Color(0.45, 0.35, 0.92, 0.42)
			_zone_edge_t = 0.38
		_:
			return
	_apply_zone_edge(_zone_edge_col)

func _pulse_zone_mark(mark: Label, effect: String) -> void:
	mark.pivot_offset = mark.size * 0.5 if mark.size.x > 1.0 else Vector2(8, 8)
	mark.scale = Vector2.ONE
	mark.rotation = 0.0
	var hot := Color(1.0, 0.55, 0.45, 1.0)
	match effect:
		"damage":
			hot = Color(1.15, 0.4, 0.32, 1.0)
		"heal":
			hot = Color(0.55, 1.05, 0.75, 1.0)
		"slow":
			hot = Color(0.7, 0.6, 1.1, 1.0)
	mark.modulate = hot
	var peak := 1.55 if effect == "damage" else 1.35
	var tw := create_tween()
	# Micro tremble then settle — danger reads as a living glyph.
	tw.tween_property(mark, "scale", Vector2(peak, peak), 0.07).set_trans(Tween.TRANS_BACK)
	if effect == "damage":
		tw.tween_property(mark, "rotation", 0.12, 0.04)
		tw.tween_property(mark, "rotation", -0.1, 0.05)
		tw.tween_property(mark, "rotation", 0.06, 0.04)
		tw.tween_property(mark, "rotation", 0.0, 0.06)
	tw.tween_property(mark, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mark, "modulate", Color.WHITE, 0.22)

func _tick_zone_edge(delta: float) -> void:
	if _zone_edge_t <= 0.0:
		# Soft linger — same clocks as player silhouette (damage red / heal green / slow violet).
		if _last_zone_effect == "damage" and not GameState.dead:
			var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
			_apply_zone_edge(Color(0.72, 0.08, 0.06, 0.14 + 0.16 * breath))
		elif _last_zone_effect == "heal" and not GameState.dead:
			# Match player.HEAL_PULSE_HZ (0.010) — half-beat snappier jade.
			var breath2 := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
			_apply_zone_edge(Color(0.2, 0.85, 0.55, 0.14 + 0.18 * breath2))
		elif _last_zone_effect == "slow" and not GameState.dead:
			# Match player.SLOW_PULSE_HZ (0.0065) — thicker fog breath.
			var breath3 := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0065)
			_apply_zone_edge(Color(0.38, 0.28, 0.82, 0.12 + 0.16 * breath3))
		return
	_zone_edge_t = maxf(_zone_edge_t - delta, 0.0)
	var a := _zone_edge_col.a * clampf(_zone_edge_t / 0.28, 0.0, 1.0)
	# Damage snaps off faster — crisp sting, not a fog.
	if _zone_edge_col.r > 0.6 and _zone_edge_col.g < 0.3:
		a = _zone_edge_col.a * clampf(_zone_edge_t / 0.22, 0.0, 1.0)
		a *= a # ease-out punch
	# Heal eases softer — comforting wash.
	elif _zone_edge_col.g > 0.5 and _zone_edge_col.b < 0.7:
		a = _zone_edge_col.a * clampf(_zone_edge_t / 0.38, 0.0, 1.0)
	# Slow hangs like mist — slower fade.
	elif _zone_edge_col.b > 0.6:
		a = _zone_edge_col.a * clampf(_zone_edge_t / 0.36, 0.0, 1.0)
	var c := Color(_zone_edge_col.r, _zone_edge_col.g, _zone_edge_col.b, a)
	if _zone_edge_t <= 0.0:
		_restore_zone_edge()
	else:
		_apply_zone_edge(c)

func _apply_zone_edge(col: Color) -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var root := hud.get_node_or_null("Root")
	if root == null:
		return
	# Don't override low-HP crisis red if it's more urgent — heal green may still show under crisis=false.
	var crisis := GameState.hp > 0 and float(GameState.hp) / float(maxi(GameState.max_hp, 1)) <= 0.3
	if crisis and col.r > 0.5 and col.g < 0.4:
		return
	# Crisis beats heal wash — keep the red language when bleeding.
	if crisis and col.g > 0.5 and col.b < 0.7:
		return
	# Crisis also beats slow violet mist.
	if crisis and col.b > 0.55 and col.r < 0.55:
		return
	for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
		var edge := root.get_node_or_null(edge_name) as ColorRect
		if edge:
			edge.color = col

func _restore_zone_edge() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var root := hud.get_node_or_null("Root")
	if root == null:
		return
	for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
		var edge := root.get_node_or_null(edge_name) as ColorRect
		if edge:
			edge.color = _base_edge_col

func zone_mods_at(pos: Vector2) -> Dictionary:
	var speed_mult := 1.0
	var dps := 0.0
	var hps := 0.0
	var effect := ""
	for z in _zone_defs:
		var c: Vector2 = z["center"]
		var r: float = z["radius"]
		if pos.distance_to(c) > r:
			continue
		match str(z.get("effect", "")):
			"slow":
				speed_mult = minf(speed_mult, float(z.get("speed_mult", 0.75)))
				effect = "slow"
			"damage":
				dps = maxf(dps, float(z.get("dps", 4.0)))
				effect = "damage"
			"heal":
				hps = maxf(hps, float(z.get("hps", 2.0)))
				effect = "heal"
	return { "speed_mult": speed_mult, "dps": dps, "hps": hps, "effect": effect }

func _on_stage_changed(stage_id: String) -> void:
	_apply_stage(stage_id)

func _on_stage_cleared(_stage_id: String) -> void:
	_cleared_stop = true
	if SfxService:
		# Dynasty「收刀」owns the settle chime — not generic clear / 破绽 open.
		if str(_stage_id) == "country" or GameState.stage_id == "country":
			if SfxService.has_method("play_sheath"):
				SfxService.play_sheath()
			else:
				SfxService.play_clear()
		elif SfxService.has_method("play_clear"):
			SfxService.play_clear()
	var banner := get_node_or_null("HUD")
	if banner and banner.has_method("show_clear"):
		banner.show_clear()

func _on_boss_spawned(boss_id: String) -> void:
	var pos := _boss_spawn_pos()
	_spawn_ring(pos, Color(1.0, 0.55, 0.25, 0.85), 42.0)
	# Minimap 赤金 pip — boss drop must punch louder than trash gold/teal.
	radar_ping(pos, "boss")
	spawn_enemy_at(boss_id, pos, true)
	if SfxService and SfxService.has_method("play_boss"):
		SfxService.play_boss()
	if _player and _player.has_method("pulse_camera"):
		_player.pulse_camera(0.2)
	if _camera:
		var z0 := _camera.zoom
		var ztw := create_tween()
		ztw.tween_property(_camera, "zoom", z0 * 1.06, 0.12)
		ztw.tween_property(_camera, "zoom", z0, 0.28)
	# Brief dark flash.
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.08, 0.02, 0.02, 0.5)
	var hud := get_node_or_null("HUD")
	if hud and hud.get_node_or_null("Root"):
		var root: Control = hud.get_node("Root")
		root.add_child(flash)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var tw := flash.create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.4)
		tw.tween_callback(flash.queue_free)
	# Teach the boss tell on entry — first telegraphs land cleaner.
	var enemy := ContentDB.get_enemy(boss_id)
	if enemy and not enemy.boss_skill.is_empty():
		var sid := str(enemy.boss_skill.get("id", ""))
		var tip := "Boss"
		match sid:
			"aoe_ring":
				tip = "长老 · 戒圈"
			"dash_strike":
				tip = "将军 · 突斩"
			"spread_shots":
				tip = "散矢"
			"void_pull":
				tip = "虚引"
			"summon":
				tip = "召侍"
		if hud and hud.has_method("show_clear"):
			hud.call("show_clear", tip)
		FloatTextManager.show_message(pos + Vector2(0, -40), tip, Color(1.0, 0.7, 0.4))
		# Early stages: teach that gold window after the tell is the punish beat.
		if GameState.stage_id in ["sect", "country"]:
			var tip_timer := get_tree().create_timer(0.55, true)
			tip_timer.timeout.connect(_teach_recover_tip)

func _boss_spawn_pos() -> Vector2:
	var pixel := Vector2(_map_size) * float(TILE)
	return pixel * 0.5 + Vector2(0, -80)

func _teach_recover_tip() -> void:
	if GameState.dead:
		return
	var hud := get_node_or_null("HUD")
	if hud and is_instance_valid(hud) and hud.has_method("show_clear"):
		hud.call("show_clear", "破 · 金闪可击")

func spawn_enemy_at(enemy_id: String, pos: Vector2, as_boss_scale: bool = false) -> void:
	var enemy := ContentDB.get_enemy(enemy_id)
	if enemy == null:
		push_warning("Missing enemy %s" % enemy_id)
		return
	var mob := preload("res://scenes/world/mob.tscn").instantiate()
	_mobs.add_child(mob)
	mob.setup(enemy)
	if as_boss_scale or enemy.is_boss:
		mob.scale = Vector2(1.5, 1.5)
	mob.global_position = pos

func on_boss_defeated(_boss_id: String) -> void:
	pass

func _apply_stage(stage_id: String) -> void:
	var stage := ContentDB.get_stage(stage_id)
	if stage == null:
		push_error("Unknown stage %s" % stage_id)
		return
	_cleared_stop = false
	_clear_group_children(_mobs)
	_clear_group_children(_projectiles)
	_clear_group_children(_pickups)
	_clear_group_children(_chests)
	_clear_group_children(_obstacles)
	_clear_group_children(_zones)
	var old_bands := get_node_or_null("GroundBands")
	if old_bands:
		old_bands.queue_free()
	var old_mist := get_node_or_null("FgMist")
	if old_mist:
		old_mist.queue_free()
	_spawn_acc = 0.0
	_last_wave_hint = ""
	_spawn_pause = 0.0
	_obstacle_rects.clear()
	_zone_defs.clear()
	_spawn_pings.clear()
	_last_zone_effect = ""
	_heal_rest_acc = 0.0
	_heal_pressure_fired = false
	var map: Dictionary = stage.map
	_map_size = Vector2i(int(map.get("width", 48)), int(map.get("height", 30)))
	var pixel := Vector2(_map_size) * float(TILE)
	_bounds = Rect2(Vector2(24, 24), pixel - Vector2(48, 48))
	_map_pattern = str(map.get("pattern", "yard"))
	_stage_accent = Color.from_string(stage.accent, Color(0.75, 0.95, 1.0))
	_set_background(stage, pixel)
	var pattern := _map_pattern
	# Slightly stronger tiles on patterned stages so layouts read at a glance.
	var tile_a := float(map.get("tile_opacity", 0.28))
	if pattern in ["city", "rift", "crater"]:
		tile_a = maxf(tile_a, 0.34)
	if pattern == "yard":
		# Cool cyan-green wash on tiles — mountain sect.
		_tiles.modulate = Color(0.78, 0.98, 0.96, tile_a)
	elif pattern == "city":
		# Warm ochre wash — dynasty streets.
		_tiles.modulate = Color(1.12, 0.94, 0.78, tile_a)
	else:
		_tiles.modulate = Color(1, 1, 1, tile_a)
	_tiles_base_mod = _tiles.modulate
	_tiles.tile_set = _build_tileset(map)
	_paint_map(pattern)
	_build_ground_bands(pixel, pattern, stage)
	_build_fg_mist(pixel, pattern, stage)
	_build_obstacles(map)
	_build_zones(map, pixel)
	_build_chests(map, pixel)
	_player.position = pixel * 0.5
	_player.configure(_projectiles, _bounds)
	# Slightly wider view after sprite shrink — keeps characters readable, not oversized.
	_camera.zoom = Vector2(1.12, 1.12)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(pixel.x)
	_camera.limit_bottom = int(pixel.y)
	var ztw := create_tween()
	ztw.tween_property(_camera, "zoom", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
	add_to_group("game_world")
	_ensure_vignette()
	_tint_vignette_for_stage()
	_spawn_ambient_motes(pixel, stage)
	var obs_array: Array = []
	for r in _obstacle_rects:
		obs_array.append(r)
	var zone_array: Array = []
	for z in _zone_defs:
		zone_array.append({
			"center": z["center"],
			"radius": z["radius"],
			"effect": z.get("effect", ""),
		})
	EventBus.map_layout_updated.emit(pixel, obs_array, zone_array)
	print("Stage: %s (%s)" % [stage.display_name, stage.id])

func _set_background(stage: StageDef, pixel: Vector2) -> void:
	var path := stage.background_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		_bg.texture = null
		return
	var tex: Texture2D = load(path)
	_bg.texture = tex
	_bg.centered = false
	_bg.position = Vector2.ZERO
	if tex:
		_bg.scale = Vector2(pixel.x / float(tex.get_width()), pixel.y / float(tex.get_height()))
	_bg.z_index = -20
	var accent := Color.from_string(stage.accent, Color(0.9, 0.92, 0.95))
	# Stronger stage wash so sect (cool cyan) vs country (warm gold) read instantly.
	match stage.id:
		"sect":
			_bg.modulate = Color(0.78 + accent.r * 0.08, 0.9 + accent.g * 0.1, 0.98 + accent.b * 0.05, 1.0)
		"country":
			_bg.modulate = Color(1.0 + accent.r * 0.05, 0.88 + accent.g * 0.06, 0.72 + accent.b * 0.04, 1.0)
		_:
			_bg.modulate = Color(0.88 + accent.r * 0.08, 0.9 + accent.g * 0.06, 0.92 + accent.b * 0.05, 1.0)
	_bg_base_mod = _bg.modulate if _bg.texture else Color.WHITE

func _tint_vignette_for_stage() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var root := hud.get_node_or_null("Root")
	if root == null:
		return
	var edge_col := Color(0.02, 0.03, 0.05, 0.26)
	match _map_pattern:
		"yard":
			# Cool teal rim — mountain courtyard air.
			edge_col = Color(0.02, 0.12, 0.14, 0.38)
		"city":
			# Warm amber rim — dynasty street dusk.
			edge_col = Color(0.16, 0.08, 0.03, 0.4)
	_base_edge_col = edge_col
	for edge_name in ["EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight"]:
		var edge := root.get_node_or_null(edge_name) as ColorRect
		if edge:
			edge.color = edge_col

## Slow color-temp breath — sect cool cyan vs dynasty warm gold (idle vignette only).
func _tick_atmosphere(_delta: float) -> void:
	if _map_pattern != "yard" and _map_pattern != "city":
		return
	# Slow clock — presence, not combat noise (~0.7Hz half-cycle).
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.00115)
	if _bg and _bg.texture:
		if _map_pattern == "yard":
			_bg.modulate = Color(
				_bg_base_mod.r * (1.0 - 0.035 * breath),
				_bg_base_mod.g * (1.0 + 0.02 * breath),
				_bg_base_mod.b * (1.0 + 0.045 * breath),
				1.0
			)
		else:
			_bg.modulate = Color(
				_bg_base_mod.r * (1.0 + 0.04 * breath),
				_bg_base_mod.g * (1.0 + 0.015 * breath),
				_bg_base_mod.b * (1.0 - 0.04 * breath),
				1.0
			)
	if _tiles:
		var ta := _tiles_base_mod.a
		if _map_pattern == "yard":
			_tiles.modulate = Color(
				_tiles_base_mod.r * (1.0 - 0.03 * breath),
				_tiles_base_mod.g * (1.0 + 0.025 * breath),
				_tiles_base_mod.b * (1.0 + 0.04 * breath),
				ta
			)
		else:
			_tiles.modulate = Color(
				_tiles_base_mod.r * (1.0 + 0.035 * breath),
				_tiles_base_mod.g * (1.0 + 0.01 * breath),
				_tiles_base_mod.b * (1.0 - 0.035 * breath),
				ta
			)
	var bands := get_node_or_null("GroundBands") as Node2D
	if bands:
		if _map_pattern == "yard":
			bands.modulate = Color(0.95 + 0.02 * breath, 1.0 + 0.04 * breath, 1.05 + 0.05 * breath, 0.9 + 0.1 * breath)
		else:
			bands.modulate = Color(1.08 + 0.06 * breath, 1.0 + 0.02 * breath, 0.92 - 0.04 * breath, 0.9 + 0.1 * breath)
	# Vignette breath only when zone/crisis aren't owning the edges.
	if _zone_edge_t > 0.0:
		return
	if not GameState.dead and _last_zone_effect in ["damage", "heal", "slow"]:
		return
	var crisis := GameState.max_hp > 0 and float(GameState.hp) / float(GameState.max_hp) <= 0.3 and not GameState.dead
	if crisis:
		return
	var col := _base_edge_col
	if _map_pattern == "yard":
		col = Color(
			lerpf(_base_edge_col.r, 0.04, breath * 0.35),
			lerpf(_base_edge_col.g, 0.18, breath * 0.45),
			lerpf(_base_edge_col.b, 0.2, breath * 0.4),
			lerpf(_base_edge_col.a, minf(_base_edge_col.a + 0.08, 0.48), breath)
		)
	else:
		col = Color(
			lerpf(_base_edge_col.r, 0.22, breath * 0.45),
			lerpf(_base_edge_col.g, 0.12, breath * 0.35),
			lerpf(_base_edge_col.b, 0.04, breath * 0.3),
			lerpf(_base_edge_col.a, minf(_base_edge_col.a + 0.09, 0.5), breath)
		)
	_apply_zone_edge(col)

func _ensure_vignette() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var root := hud.get_node_or_null("Root")
	if root == null or root.get_node_or_null("EdgeTop"):
		return
	for i in 4:
		var edge := ColorRect.new()
		match i:
			0:
				edge.name = "EdgeTop"
				edge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				edge.offset_bottom = 26
			1:
				edge.name = "EdgeBottom"
				edge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				edge.offset_top = -22
			2:
				edge.name = "EdgeLeft"
				edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
				edge.offset_right = 32
			3:
				edge.name = "EdgeRight"
				edge.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
				edge.offset_left = -32
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.color = Color(0.02, 0.03, 0.05, 0.26)
		root.add_child(edge)

func _build_ground_bands(pixel: Vector2, pattern: String, stage: StageDef) -> void:
	# Soft horizontal color bands under the fight — sect cool moss vs dynasty warm dust.
	var root := Node2D.new()
	root.name = "GroundBands"
	root.z_index = -18
	add_child(root)
	var accent := Color.from_string(stage.accent, Color(0.7, 0.9, 1.0))
	var band_count := 5
	for i in band_count:
		var band := Polygon2D.new()
		var y0 := pixel.y * (float(i) / float(band_count))
		var y1 := pixel.y * (float(i + 1) / float(band_count))
		band.polygon = PackedVector2Array([
			Vector2(0, y0), Vector2(pixel.x, y0), Vector2(pixel.x, y1), Vector2(0, y1),
		])
		var t := float(i) / float(maxi(band_count - 1, 1))
		if pattern == "yard":
			# Cool cyan→jade bands — mountain courtyard air.
			band.color = Color(
				lerpf(0.12, 0.2, t) * accent.r,
				lerpf(0.28, 0.42, t),
				lerpf(0.32, 0.38, t),
				0.1 + t * 0.06
			)
		elif pattern == "city":
			# Warm ochre→ember bands — paved streets.
			band.color = Color(
				lerpf(0.42, 0.55, t),
				lerpf(0.28, 0.22, t),
				lerpf(0.14, 0.1, t),
				0.12 + t * 0.07
			)
		else:
			band.color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.22, 0.08)
		root.add_child(band)
	# Thin path wash along the middle for yard / grid for city.
	if pattern == "yard":
		var cross := Polygon2D.new()
		var mid_y := pixel.y * 0.5
		cross.polygon = PackedVector2Array([
			Vector2(0, mid_y - 18), Vector2(pixel.x, mid_y - 18),
			Vector2(pixel.x, mid_y + 18), Vector2(0, mid_y + 18),
		])
		cross.color = Color(0.45, 0.7, 0.62, 0.1)
		root.add_child(cross)
	elif pattern == "city":
		for gx in range(0, int(pixel.x), 128):
			var street := Polygon2D.new()
			street.polygon = PackedVector2Array([
				Vector2(gx - 6, 0), Vector2(gx + 6, 0),
				Vector2(gx + 6, pixel.y), Vector2(gx - 6, pixel.y),
			])
			street.color = Color(0.55, 0.42, 0.28, 0.09)
			root.add_child(street)

func _build_fg_mist(pixel: Vector2, pattern: String, stage: StageDef) -> void:
	# Foreground haze sits above actors slightly — depth without hiding combat.
	var root := Node2D.new()
	root.name = "FgMist"
	root.z_index = 30
	add_child(root)
	var accent := Color.from_string(stage.accent, Color(0.7, 0.9, 1.0))
	var layers := 3
	for i in layers:
		var mist := Polygon2D.new()
		var h := 36.0 + float(i) * 22.0
		var y := pixel.y - h - float(i) * 10.0
		mist.polygon = PackedVector2Array([
			Vector2(-40, y), Vector2(pixel.x + 40, y),
			Vector2(pixel.x + 40, pixel.y + 20), Vector2(-40, pixel.y + 20),
		])
		if pattern == "yard":
			mist.color = Color(0.55 * accent.r, 0.85, 0.92, 0.07 + float(i) * 0.025)
		elif pattern == "city":
			mist.color = Color(0.75, 0.55, 0.35, 0.08 + float(i) * 0.03)
		else:
			mist.color = Color(accent.r, accent.g, accent.b, 0.05 + float(i) * 0.02)
		mist.set_meta("base_x", 0.0)
		mist.set_meta("drift", 8.0 + float(i) * 4.0)
		mist.set_meta("phase", randf() * TAU)
		root.add_child(mist)

func _tick_fg_mist(delta: float) -> void:
	var root := get_node_or_null("FgMist")
	if root == null:
		return
	for child in root.get_children():
		if not (child is Polygon2D):
			continue
		var mist := child as Polygon2D
		var drift := float(mist.get_meta("drift", 10.0))
		var phase := float(mist.get_meta("phase", 0.0)) + delta
		mist.set_meta("phase", phase)
		mist.position.x = sin(phase * 0.35) * drift
		mist.modulate.a = 0.85 + 0.15 * sin(phase * 1.1)

func _spawn_ambient_motes(pixel: Vector2, stage: StageDef = null) -> void:
	var old := get_node_or_null("AmbientMotes")
	if old:
		old.queue_free()
	var root := Node2D.new()
	root.name = "AmbientMotes"
	root.z_index = 8
	add_child(root)
	var accent := Color(0.75, 0.95, 1.0)
	if stage != null:
		accent = Color.from_string(stage.accent, accent)
	var count := 18
	var city := _map_pattern == "city"
	if city:
		count = 14
	for i in count:
		var mote := Polygon2D.new()
		if city:
			# Warm dust drifting sideways — human battlefield grit.
			mote.color = Color(accent.r, accent.g * 0.9, accent.b * 0.7, randf_range(0.14, 0.32))
			mote.polygon = [Vector2(-1.5, -1), Vector2(1.5, -1), Vector2(1.5, 1), Vector2(-1.5, 1)]
			mote.set_meta("drift", Vector2(randf_range(10, 22), randf_range(-6, 4)))
		else:
			# Cool spirit petals rising — mountain-sect air.
			mote.color = Color(accent.r * 0.85, accent.g, accent.b, randf_range(0.14, 0.34))
			mote.polygon = [Vector2(0, -2), Vector2(1.4, 1), Vector2(-1.4, 1)]
			mote.set_meta("drift", Vector2(randf_range(-6, 6), randf_range(-18, -8)))
		mote.position = Vector2(randf() * pixel.x, randf() * pixel.y)
		root.add_child(mote)
		mote.set_meta("phase", randf() * TAU)

func _tick_ambient_motes(delta: float) -> void:
	var root := get_node_or_null("AmbientMotes")
	if root == null:
		return
	var pixel := Vector2(_map_size) * float(TILE)
	var city := _map_pattern == "city"
	for child in root.get_children():
		if not (child is Polygon2D):
			continue
		var mote := child as Polygon2D
		var drift: Vector2 = mote.get_meta("drift", Vector2(0, -8))
		var phase: float = float(mote.get_meta("phase", 0.0)) + delta
		mote.set_meta("phase", phase)
		mote.position += drift * delta
		mote.modulate.a = 0.35 + 0.25 * sin(phase * 2.0)
		if city:
			if mote.position.x > pixel.x + 8.0 or mote.position.y < -8.0 or mote.position.y > pixel.y + 8.0:
				mote.position = Vector2(-8.0, randf() * pixel.y)
		elif mote.position.y < -8.0 or mote.position.x < -8.0 or mote.position.x > pixel.x + 8.0:
			mote.position = Vector2(randf() * pixel.x, pixel.y + randf() * 20.0)

func _spawn_one(stage: StageDef) -> void:
	var wave := stage.current_wave(GameState.stage_kills())
	var pool: Array = wave.get("spawns", [])
	var enemy_id := stage._pick_from_spawns(pool) if typeof(pool) == TYPE_ARRAY and not pool.is_empty() else stage.pick_enemy_id()
	var enemy := ContentDB.get_enemy(enemy_id)
	if enemy == null:
		push_error("Stage %s missing enemy %s" % [stage.id, enemy_id])
		return
	var pos := _spawn_point()
	# Sect teal / dynasty gold dual-ring warn — readable land before/with body.
	_flash_spawn_warn(pos)
	var mob := preload("res://scenes/world/mob.tscn").instantiate()
	_mobs.add_child(mob)
	mob.setup(enemy)
	if enemy.is_boss:
		mob.scale = Vector2(1.35, 1.35)
	elif randf() < float(ContentDB.section("combat").get("elite_spawn_chance", 0.1)):
		mob.make_elite()
		# Warm-gold land — world ring + HUD rim (not just minimap pip).
		_flash_elite_land(pos, mob)
	mob.global_position = pos

## Trash spawn telegraph — dual rings + radar pip (yard teal / city gold).
func _flash_spawn_warn(pos: Vector2) -> void:
	if _map_pattern == "yard":
		# Outer mist + inner snap — courtyard identity without clutter.
		_spawn_ring(pos, Color(0.4, 0.94, 0.88, 0.78), 24.0)
		_spawn_ring(pos, Color(0.55, 1.0, 0.94, 0.5), 13.0)
		_ping_spawn(pos, "yard")
	elif _map_pattern == "city":
		# Warm-gold double pip — same family as 市斩 / dynasty HUD.
		_spawn_ring(pos, Color(1.0, 0.84, 0.4, 0.84), 17.0)
		_spawn_ring(pos, Color(1.0, 0.94, 0.62, 0.52), 10.0)
		_ping_spawn(pos, "gold")
	else:
		_spawn_ring(pos, Color(1.0, 0.5, 0.38, 0.65), 18.0)
		_ping_spawn(pos, "")

## Elite drop punch — crown ring, float, soft camera, HUD warm-gold edges.
func _flash_elite_land(pos: Vector2, mob: Node) -> void:
	_spawn_ring(pos, Color(1.0, 0.84, 0.4, 0.78), 17.0)
	_spawn_ring(pos, Color(1.0, 0.94, 0.62, 0.45), 11.0)
	_ping_spawn(pos, "elite")
	FloatTextManager.show_message(pos + Vector2(0, -28), "精英", Color(1.0, 0.88, 0.42))
	if SfxService:
		SfxService.play_elite_land()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		if hud.has_method("flash_elite_spawn_edges"):
			hud.call("flash_elite_spawn_edges")
		if hud.has_method("flash_elite_dock"):
			hud.call("flash_elite_dock")
		if hud.has_method("show_clear"):
			hud.call("show_clear", "精英")
	if _player and is_instance_valid(_player) and _player.has_method("pulse_camera"):
		_player.pulse_camera(0.07)
	if has_method("hitstop"):
		hitstop(0.022)
	if mob and is_instance_valid(mob) and mob.has_method("pulse_elite_land"):
		mob.call("pulse_elite_land")

## First ~60s on 宗门: rest in 愈地 → close outer disciple so heal→pressure stays punchy.
func _tick_heal_rest_pressure(delta: float) -> void:
	if _heal_pressure_fired or _cleared_stop or GameState.dead:
		return
	if GameState.stage_id != "sect" or GameState.run_time >= 60.0:
		return
	if _last_zone_effect == "heal":
		_heal_rest_acc += delta
		if _heal_rest_acc >= 0.9:
			if _spawn_heal_pressure_disciple():
				_heal_pressure_fired = true
	elif _heal_rest_acc > 0.0:
		# Brief leave doesn't wipe the breath, but long leave resets.
		_heal_rest_acc = maxf(0.0, _heal_rest_acc - delta * 0.65)

func _spawn_heal_pressure_disciple() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var stage := GameState.current_stage()
	var cap := 15
	if stage != null:
		cap = stage.max_alive_for(GameState.stage_kills())
	if _mobs.get_child_count() >= cap:
		return false
	var enemy := ContentDB.get_enemy("outer_disciple")
	if enemy == null:
		return false
	var pos := _close_spawn_near_player(72.0, 118.0)
	# Warm steel ring — pressure drop, not the calm cyan yard mist.
	_spawn_ring(pos, Color(0.95, 0.72, 0.35, 0.75), 16.0)
	_ping_spawn(pos, "steel")
	var mob := preload("res://scenes/world/mob.tscn").instantiate()
	_mobs.add_child(mob)
	mob.setup(enemy)
	mob.global_position = pos
	# First-hit 「迎刃」 window — ~0.4s after land.
	mob.set_meta("yingren_armed", true)
	mob.set_meta("yingren_until", Time.get_ticks_msec() + 400)
	FloatTextManager.show_message(pos + Vector2(0, -22), "外门", Color(1.0, 0.82, 0.45))
	if SfxService:
		SfxService.play_heal_pressure()
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_clear"):
		hud.call("show_clear", "愈后 · 外门近身")
	# Warm-steel screen edges — punch vs 愈地 cool breath (minimap reads steel ping).
	if hud and hud.has_method("flash_steel_edges"):
		hud.call("flash_steel_edges")
	return true

func _close_spawn_near_player(min_r: float, max_r: float) -> Vector2:
	var pixel := Vector2(_map_size) * float(TILE)
	var origin := _player.global_position if _player else pixel * 0.5
	var best := origin + Vector2(max_r, 0)
	var best_score := -1.0
	for _i in 14:
		var ang := randf() * TAU
		var pos: Vector2 = origin + Vector2.from_angle(ang) * randf_range(min_r, max_r)
		pos.x = clampf(pos.x, 36.0, pixel.x - 36.0)
		pos.y = clampf(pos.y, 36.0, pixel.y - 36.0)
		if _hits_obstacle(pos):
			continue
		var d := pos.distance_to(origin)
		if d < min_r * 0.85:
			continue
		# Prefer not standing inside the heal well center.
		var heal_c := Vector2(pixel.x * 0.5, pixel.y * 0.52)
		var score := d + pos.distance_to(heal_c) * 0.15 + randf() * 8.0
		if score > best_score:
			best_score = score
			best = pos
	return best

func _ping_spawn(pos: Vector2, kind: String = "", life_override: float = -1.0) -> void:
	var life := 1.15
	if kind == "steel":
		life = 1.65
	elif kind == "gold":
		life = 1.0 # Dynasty spawn warn — snappy vs teal linger, longer than wipe echo.
	elif kind == "jade":
		life = 1.25 # Calm heal-enter ping — softer linger than steel.
	elif kind == "ash":
		life = 1.05 # Snappy 煞地 sting — shorter than jade linger.
	elif kind == "mist":
		life = 1.2 # Soft 滞地 fog — hangs a beat like mist.
	elif kind == "yard":
		life = 1.28 # Sect spawn teal pip — hangs so land reads on radar.
	elif kind == "boss":
		life = 1.55 # Boss drop 赤金 — hangs longer than trash gold.
	elif kind == "break":
		life = 1.2 # 破绽 punish pip — snappy gold, shorter than boss drop.
	elif kind == "elite":
		life = 0.72 # Elite drop — short warm pip, quieter than 破绽.
	elif kind == "chest":
		life = 1.35 # Loot open — warm-gold diamond hang, longer than dynasty wipe.
	if life_override > 0.0:
		life = life_override
	_spawn_pings.append({"pos": pos, "life": life, "kind": kind, "life_max": life})
	if _spawn_pings.size() > 10:
		_spawn_pings.pop_front()

## Public radar ping for overlays (sect open wipe, etc.).
func radar_ping(pos: Vector2, kind: String = "", life_s: float = -1.0) -> void:
	_ping_spawn(pos, kind, life_s)

func _tick_spawn_pings(delta: float) -> void:
	if _spawn_pings.is_empty():
		return
	var next: Array[Dictionary] = []
	for row in _spawn_pings:
		var life := float(row.get("life", 0.0)) - delta
		if life > 0.0:
			next.append({
				"pos": row.get("pos", Vector2.ZERO),
				"life": life,
				"kind": str(row.get("kind", "")),
				"life_max": float(row.get("life_max", life)),
			})
	_spawn_pings = next

func recent_spawn_pings() -> Array[Dictionary]:
	return _spawn_pings

## Active zone under the hero — minimap residence breath reads this.
func current_zone_effect() -> String:
	return _last_zone_effect

func _spawn_ring(pos: Vector2, color: Color, radius: float) -> void:
	var city_short := _map_pattern == "city" and radius <= 15.0
	var yard_warn := _map_pattern == "yard" and radius >= 20.0
	var ring := Line2D.new()
	ring.width = 2.6 if yard_warn else (2.2 if _map_pattern == "yard" else (2.5 if city_short else 2.0))
	ring.default_color = color
	ring.z_index = 6
	var pts := PackedVector2Array()
	var segs := 16 if city_short else 22
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	pts.append(pts[0])
	ring.points = pts
	add_child(ring)
	ring.global_position = pos
	# Soft fill flash under rim — drop point reads even on busy tiles.
	var fill := Polygon2D.new()
	fill.z_index = 5
	fill.color = Color(color.r, color.g, color.b, 0.36 if yard_warn or city_short else 0.28)
	var fpts := PackedVector2Array()
	for i in 16:
		var a0 := TAU * float(i) / 16.0
		fpts.append(Vector2(cos(a0), sin(a0)) * (radius * 0.55))
	fill.polygon = fpts
	add_child(fill)
	fill.global_position = pos
	var fade_s := 0.16 if city_short else (0.32 if yard_warn else 0.24)
	var expand := 1.55 if city_short else (2.05 if yard_warn else 1.9)
	var ftw := fill.create_tween()
	ftw.tween_property(fill, "scale", Vector2(1.7, 1.7) if city_short else Vector2(2.2, 2.2), fade_s * 0.85)
	ftw.parallel().tween_property(fill, "modulate:a", 0.0, fade_s * 0.85)
	ftw.tween_callback(fill.queue_free)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(expand, expand), fade_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, fade_s)
	tw.tween_callback(ring.queue_free)

func _spawn_point() -> Vector2:
	var cbt := ContentDB.section("combat")
	var min_r := float(cbt.get("spawn_min_radius", 150))
	var max_r := float(cbt.get("spawn_max_radius", 230))
	var pixel := Vector2(_map_size) * float(TILE)
	if _map_pattern == "yard":
		var lane := _spawn_point_yard(pixel, min_r)
		if lane != Vector2.ZERO:
			return lane
	for _i in 12:
		var pos: Vector2 = _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(min_r, max_r)
		pos.x = clampf(pos.x, 32.0, pixel.x - 32.0)
		pos.y = clampf(pos.y, 32.0, pixel.y - 32.0)
		if pos.distance_to(_player.global_position) >= min_r * 0.6 and not _hits_obstacle(pos):
			return pos
	return Vector2(pixel.x * 0.5, 48.0)

## Sect courtyard: drop from gates / corners so the yard layout reads mid-fight.
func _spawn_point_yard(pixel: Vector2, min_r: float) -> Vector2:
	var stage := GameState.current_stage()
	var lanes: Array = []
	if stage != null and typeof(stage.map.get("spawn_lanes", null)) == TYPE_ARRAY:
		lanes = stage.map.get("spawn_lanes", [])
	if lanes.is_empty():
		lanes = [
			{"cx": 0.5, "cy": 0.1},
			{"cx": 0.12, "cy": 0.32},
			{"cx": 0.88, "cy": 0.32},
			{"cx": 0.14, "cy": 0.78},
			{"cx": 0.86, "cy": 0.78},
			{"cx": 0.5, "cy": 0.9},
		]
	var best := Vector2.ZERO
	var best_score := -1.0
	# Sample a few lanes; prefer far-from-player + away from heal core.
	var heal_c := Vector2(pixel.x * 0.5, pixel.y * 0.52)
	for _try in 5:
		var raw: Variant = lanes[randi() % lanes.size()]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var jitter := Vector2(randf_range(-28, 28), randf_range(-22, 22))
		var pos := Vector2(float(raw.get("cx", 0.5)) * pixel.x, float(raw.get("cy", 0.5)) * pixel.y) + jitter
		pos.x = clampf(pos.x, 36.0, pixel.x - 36.0)
		pos.y = clampf(pos.y, 36.0, pixel.y - 36.0)
		if _hits_obstacle(pos):
			continue
		var d_player := pos.distance_to(_player.global_position)
		if d_player < min_r * 0.55:
			continue
		var d_heal := pos.distance_to(heal_c)
		var score := d_player * 0.55 + d_heal * 0.35 + randf() * 40.0
		if score > best_score:
			best_score = score
			best = pos
	return best

func _hits_obstacle(pos: Vector2) -> bool:
	for rect in _obstacle_rects:
		if rect.has_point(pos):
			return true
	return false

func _build_obstacles(map: Dictionary) -> void:
	var rows: Variant = map.get("obstacles", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var x := int(raw.get("x", 0)) * TILE
		var y := int(raw.get("y", 0)) * TILE
		var w := int(raw.get("w", 1)) * TILE
		var h := int(raw.get("h", 1)) * TILE
		var rect := Rect2(x, y, w, h)
		_obstacle_rects.append(rect)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = rect.position
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.size * 0.5
		body.add_child(shape)
		var base_col := Color.from_string(str(raw.get("color", "#4a4038")), Color("4a4038"))
		var style := str(raw.get("style", "rock"))
		if style.is_empty():
			style = "wall" if _map_pattern == "city" else "moss"
		var shadow := Polygon2D.new()
		shadow.color = Color(0.05, 0.05, 0.07, 0.35)
		if style == "wall":
			shadow.polygon = [
				Vector2(1, h + 1), Vector2(w + 3, h + 1), Vector2(w + 1, h + 4), Vector2(3, h + 4)
			]
		else:
			shadow.polygon = [
				Vector2(2, h + 2), Vector2(w + 4, h + 2), Vector2(w + 2, h + 6), Vector2(4, h + 6)
			]
		body.add_child(shadow)
		var rock := Polygon2D.new()
		rock.color = base_col.lightened(0.08)
		if style == "wall":
			# Squared city masonry — dynasty streets.
			rock.polygon = [
				Vector2(1, 1), Vector2(w - 1, 1), Vector2(w - 1, h - 1), Vector2(1, h - 1)
			]
		else:
			# Soft mossy garden stones — sect yard.
			rock.polygon = [
				Vector2(2, h * 0.55), Vector2(w * 0.25, 2), Vector2(w * 0.75, 0), Vector2(w - 2, h * 0.4),
				Vector2(w - 4, h - 2), Vector2(4, h - 2)
			]
		body.add_child(rock)
		var highlight := Polygon2D.new()
		highlight.color = base_col.lightened(0.28)
		if style == "wall":
			highlight.polygon = [
				Vector2(2, 2), Vector2(w * 0.55, 2), Vector2(w * 0.4, 5), Vector2(2, 5)
			]
		else:
			highlight.polygon = [
				Vector2(w * 0.28, 6), Vector2(w * 0.55, 4), Vector2(w * 0.42, h * 0.35)
			]
		body.add_child(highlight)
		_obstacles.add_child(body)

func _build_zones(map: Dictionary, pixel: Vector2) -> void:
	var rows: Variant = map.get("zones", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cx := float(raw.get("cx", 0.5)) * pixel.x
		var cy := float(raw.get("cy", 0.5)) * pixel.y
		var r := float(raw.get("r", 0.1)) * minf(pixel.x, pixel.y)
		var effect := str(raw.get("effect", ""))
		var col := Color.from_string(str(raw.get("color", "#ffffff22")), Color(1, 1, 1, 0.12))
		match effect:
			"heal":
				col = Color(0.32, 0.92, 0.7, 0.3)
			"slow":
				col = Color(0.48, 0.38, 0.92, 0.28)
			"damage":
				col = Color(0.98, 0.35, 0.28, 0.28)
		var phase := randf() * TAU
		var ring := Polygon2D.new()
		ring.position = Vector2(cx, cy)
		ring.color = col
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		ring.polygon = pts
		ring.set_meta("pulse_phase", phase)
		_zones.add_child(ring)
		var well: Polygon2D = null
		var guide: Line2D = null
		if effect == "heal":
			# Inner jade well — circular 愈, never a gold diamond like chests.
			well = Polygon2D.new()
			well.position = Vector2(cx, cy)
			well.color = Color(0.28, 0.88, 0.68, 0.22)
			var wpts := PackedVector2Array()
			for i in 18:
				var aw := TAU * float(i) / 18.0
				wpts.append(Vector2(cos(aw), sin(aw)) * (r * 0.42))
			well.polygon = wpts
			_zones.add_child(well)
			# Soft outer guide ring — calm boundary vs 破绽's sharp gold ticks.
			guide = Line2D.new()
			guide.width = 1.4
			guide.default_color = Color(0.4, 0.95, 0.8, 0.35)
			guide.position = Vector2(cx, cy)
			for i in 29:
				var ag := TAU * float(i) / 28.0
				guide.add_point(Vector2(cos(ag), sin(ag)) * (r * 1.08))
			_zones.add_child(guide)
		var rim := Line2D.new()
		rim.width = 2.6 if effect == "heal" else 2.4
		rim.default_color = Color(col.r, col.g, col.b, minf(col.a + 0.5, 0.9))
		rim.position = Vector2(cx, cy)
		for i in 25:
			var a2 := TAU * float(i) / 24.0
			rim.add_point(Vector2(cos(a2), sin(a2)) * r)
		_zones.add_child(rim)
		# Tiny ground glyph so heal/slow/damage read without HUD clutter.
		var mark := Label.new()
		mark.text = {"heal": "愈", "slow": "滞", "damage": "煞"}.get(effect, "·")
		mark.add_theme_font_size_override("font_size", 13 if effect == "heal" else 12)
		mark.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.95).lightened(0.25))
		mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		mark.add_theme_constant_override("shadow_offset_x", 1)
		mark.add_theme_constant_override("shadow_offset_y", 1)
		mark.position = Vector2(cx - 8, cy - 8)
		mark.z_index = 2
		mark.pivot_offset = Vector2(8, 8)
		_zones.add_child(mark)
		var row := {
			"center": Vector2(cx, cy),
			"radius": r,
			"effect": effect,
			"speed_mult": float(raw.get("speed_mult", 0.75)),
			"dps": float(raw.get("dps", 0.0)),
			"hps": float(raw.get("hps", 0.0)),
			"visual": ring,
			"rim": rim,
			"mark": mark,
			"pulse_phase": phase,
		}
		if well:
			row["well"] = well
			row["guide"] = guide
			row["breath_life"] = randf_range(0.2, 0.9)
		_zone_defs.append(row)

func _build_chests(map: Dictionary, pixel: Vector2) -> void:
	var rows: Variant = map.get("chests", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cx := float(raw.get("cx", 0.5)) * pixel.x
		var cy := float(raw.get("cy", 0.5)) * pixel.y
		var loot: Variant = raw.get("loot", [])
		var chest := preload("res://scenes/world/chest.tscn").instantiate()
		_chests.add_child(chest)
		if chest.has_method("setup"):
			chest.setup(Vector2(cx, cy), loot if typeof(loot) == TYPE_ARRAY else [])
	# Soft explore tip once chests are down — points eyes to the minimap.
	if rows.size() > 0 and GameState.stage_id in ["sect", "country"]:
		call_deferred("_hint_chests")

func _hint_chests() -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_clear"):
		hud.call("show_clear", "小地图 · 寻宝")
	if _player:
		FloatTextManager.show_message(_player.global_position + Vector2(0, -36), "寻宝", Color(1.0, 0.88, 0.5))

func _clear_group_children(node: Node) -> void:
	while node.get_child_count() > 0:
		var child := node.get_child(0)
		node.remove_child(child)
		child.free()

func _build_tileset(map: Dictionary) -> TileSet:
	var image := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	var pattern := str(map.get("pattern", "yard"))
	_stamp_tile(image, 0, Color.from_string(str(map.get("ground", "#355e32")), Color("355e32")), Color.from_string(str(map.get("ground_alt", "#2c4e29")), Color("2c4e29")), pattern)
	_stamp_tile(image, 1, Color.from_string(str(map.get("path", "#8a6a3e")), Color("8a6a3e")), Color.from_string(str(map.get("path", "#8a6a3e")), Color("8a6a3e")).darkened(0.15), pattern)
	_stamp_tile(image, 2, Color.from_string(str(map.get("border", "#6b7078")), Color("6b7078")), Color.from_string(str(map.get("border", "#6b7078")), Color("6b7078")).darkened(0.2), pattern)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(TILE_GRASS)
	source.create_tile(TILE_DIRT)
	source.create_tile(TILE_STONE)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_source(source)
	return tileset

func _stamp_tile(image: Image, index: int, base: Color, alt: Color, pattern: String = "yard") -> void:
	var origin := Vector2i(index * TILE, 0)
	for y in TILE:
		for x in TILE:
			var n := (x * 3 + y * 7 + index * 11) % 11
			var edge := x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1
			var c := alt if n < 3 else base
			if edge:
				c = c.darkened(0.12)
			elif n == 5:
				c = c.lightened(0.1)
			elif n == 8:
				c = c.lightened(0.04)
			# Pattern micro-detail: moss flecks vs brick joints.
			if pattern == "yard" and (x + y * 3) % 7 == 0:
				c = c.lightened(0.08).lerp(Color(0.45, 0.75, 0.65), 0.15)
			elif pattern == "city" and (y == 4 or y == 11 or x == 4 or x == 11):
				c = c.darkened(0.14)
			image.set_pixel(origin.x + x, origin.y + y, Color(c.r, c.g, c.b, 0.95))

func _paint_map(pattern: String) -> void:
	_tiles.clear()
	for y in _map_size.y:
		for x in _map_size.x:
			_tiles.set_cell(Vector2i(x, y), SOURCE_ID, _atlas_for(pattern, x, y))

func _atlas_for(pattern: String, x: int, y: int) -> Vector2i:
	if x == 0 or y == 0 or x == _map_size.x - 1 or y == _map_size.y - 1:
		return TILE_STONE
	var w := _map_size.x
	var h := _map_size.y
	match pattern:
		"city":
			# Street grid + plaza blocks — reads as human city vs wild yard.
			if x % 8 == 0 or y % 8 == 0:
				return TILE_DIRT
			if (x / 8 + y / 8) % 2 == 0 and (x % 8 > 2 and y % 8 > 2):
				return TILE_STONE if ((x + y) % 5 == 0) else TILE_GRASS
		"crater":
			var d := Vector2(x - w * 0.5, y - h * 0.5).length()
			if d < 5.0:
				return TILE_DIRT
			if int(d) % 7 == 0:
				return TILE_DIRT
		"nebula":
			if (x * 17 + y * 31) % 11 == 0:
				return TILE_DIRT
			if (x * 3 + y * 5) % 19 == 0:
				return TILE_STONE
		"rift":
			if absi(x * h - y * w) < h or absi(x + y - h) <= 1:
				return TILE_DIRT
			if absi(x - y) <= 1:
				return TILE_STONE
		"void":
			if (x * 13 + y * 7) % 17 == 0:
				return TILE_DIRT
		_:
			# Yard: cross path + soft garden patches.
			if y == int(h * 0.5) or x == int(w * 0.5):
				return TILE_DIRT
			if (x + y) % 13 == 0:
				return TILE_DIRT
	return TILE_GRASS
