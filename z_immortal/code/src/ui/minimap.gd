extends Control

## Top-right minimap: player, mobs, obstacles, zones, chests, map bounds.
## Chests + 煞地 pulse hard — exploration motive must beat combat clutter.
## Yard (宗门) draws courtyard lanes + cyan spawn pips; city keeps warm masonry.

var _map_size := Vector2(768, 480)
var _obstacles: Array = []
var _zones: Array = []
var _frame_col := Color(0.55, 0.78, 0.88, 0.55)
var _fill_col := Color(0.04, 0.06, 0.09, 0.82)
var _pattern := "yard"
var _obs_col := Color(0.28, 0.24, 0.2, 0.9)
var _combo_flash_t := 0.0
var _combo_flash_max := 0.28
var _combo_teal := false
## Milestone tier on radar: 0 soft kill tick, else exact combo count (2/3/5/8…).
var _combo_flash_tier := 0
var _clear_flash_t := 0.0
var _clear_flash_max := 0.42
var _clear_teal := true
## Dynasty「收刀」clear — warmer/longer gold frame than generic city wipe.
var _clear_sheath := false

func _ready() -> void:
	custom_minimum_size = Vector2(108, 68)
	EventBus.map_layout_updated.connect(_on_map_layout)
	EventBus.stage_changed.connect(_on_stage_changed)
	EventBus.chest_opened.connect(func(_p): queue_redraw())
	EventBus.combo_milestone.connect(_on_combo_milestone)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.stage_cleared.connect(_on_stage_cleared)

func _on_stage_cleared(_stage_id: String) -> void:
	# Clear 爆闪 — sect teal / dynasty「收刀」gold, louder than near-clear breath.
	_clear_teal = _pattern == "yard" or _stage_id == "sect"
	_clear_sheath = _stage_id == "country" or (_pattern == "city" and not _clear_teal)
	_clear_flash_max = 0.82 if _clear_sheath else 0.62
	_clear_flash_t = _clear_flash_max
	queue_redraw()

func _on_combo_milestone(count: int) -> void:
	# Match HUD edge — 二连/三连 sect teal; 5/8 hotter gold; soft ticks stay quieter.
	var yard := _pattern == "yard" or GameState.stage_id == "sect"
	_combo_teal = yard and (count == 2 or count == 3)
	_combo_flash_tier = count
	if count == 2:
		_combo_flash_max = 0.3
	elif count == 3:
		_combo_flash_max = 0.36
	elif count == 5:
		_combo_flash_max = 0.42
	elif count >= 8:
		_combo_flash_max = 0.5
	else:
		_combo_flash_max = 0.38
	_combo_flash_t = _combo_flash_max
	queue_redraw()

func _on_enemy_killed(_enemy_id: String, _stage_id: String) -> void:
	# Soft tick from 2连 onward — never steals an active milestone punch.
	if GameState.combo < 2:
		return
	if _combo_flash_t > 0.14:
		return
	_combo_teal = false
	_combo_flash_tier = 0
	_combo_flash_max = 0.16
	_combo_flash_t = _combo_flash_max

func _combo_flash_strength() -> float:
	if _combo_flash_t <= 0.0 or _combo_flash_max <= 0.0:
		return 0.0
	return clampf(_combo_flash_t / _combo_flash_max, 0.0, 1.0)

func _clear_flash_strength() -> float:
	if _clear_flash_t <= 0.0 or _clear_flash_max <= 0.0:
		return 0.0
	return clampf(_clear_flash_t / _clear_flash_max, 0.0, 1.0)

func _on_stage_changed(_id: String) -> void:
	_clear_flash_t = 0.0
	_clear_sheath = false
	_combo_flash_t = 0.0
	_combo_flash_tier = 0
	_refresh_stage_look()
	queue_redraw()

func _refresh_stage_look() -> void:
	var stage := GameState.current_stage()
	if stage == null:
		_frame_col = Color(0.55, 0.78, 0.88, 0.55)
		_fill_col = Color(0.04, 0.06, 0.09, 0.82)
		_pattern = "yard"
		_obs_col = Color(0.28, 0.24, 0.2, 0.9)
		return
	var accent := Color.from_string(stage.accent, Color(0.55, 0.78, 0.88))
	_pattern = str(stage.map.get("pattern", "yard"))
	_frame_col = Color(accent.r, accent.g, accent.b, 0.72 if _pattern == "yard" else 0.65)
	if _pattern == "city":
		_fill_col = Color(0.08, 0.06, 0.04, 0.86)
		_obs_col = Color(0.32, 0.28, 0.22, 0.92)
	elif _pattern == "yard":
		# Cool moss courtyard — mountain-sect identity on the radar.
		_fill_col = Color(0.02, 0.08, 0.07, 0.88)
		_obs_col = Color(0.22, 0.38, 0.3, 0.92)
		_frame_col = Color(0.45, 0.88, 0.82, 0.78)
	else:
		_fill_col = Color(0.04, 0.06, 0.09, 0.82)
		_obs_col = Color(0.28, 0.24, 0.2, 0.9)

func _on_map_layout(map_size: Vector2, obstacles: Array, zones: Array = []) -> void:
	_map_size = map_size
	_obstacles = obstacles
	_zones = zones
	_refresh_stage_look()
	queue_redraw()

func _process(delta: float) -> void:
	if _combo_flash_t > 0.0:
		_combo_flash_t = maxf(_combo_flash_t - delta, 0.0)
		if _combo_flash_t <= 0.0:
			_combo_flash_tier = 0
	if _clear_flash_t > 0.0:
		_clear_flash_t = maxf(_clear_flash_t - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	var pad := 3.0
	var outer := Rect2(0, 0, size.x, size.y)
	var steel_a := _steel_ping_strength()
	var jade_a := _jade_ping_strength()
	var ash_a := _ash_ping_strength()
	var mist_a := _mist_ping_strength()
	var yard_a := _yard_ping_strength()
	var gold_a := _gold_ping_strength()
	var heal_rest := _heal_residence_strength()
	var ash_rest := _damage_residence_strength()
	var mist_rest := _slow_residence_strength()
	var combo_a := _combo_flash_strength()
	var boss_a := _boss_ping_strength()
	var break_a := _break_ping_strength()
	var elite_a := _elite_ping_strength()
	var crisis_a := _crisis_strength()
	var near_a := _near_clear_strength()
	var clear_a := _clear_flash_strength()
	var fill := _fill_col
	var frame := _frame_col
	if steel_a > 0.0:
		# Brief warm-steel frame wash when 愈后近身 lands.
		fill = fill.lerp(Color(0.18, 0.12, 0.06, 0.88), steel_a * 0.55)
		frame = Color(0.98, 0.78, 0.4, 0.55 + 0.45 * steel_a)
	elif clear_a > 0.0:
		# Clear 爆闪 — courtyard teal vs dynasty「收刀」warm-gold (hotter settle).
		var punch := clear_a * clear_a # bias bright at the start of the window
		if _clear_teal:
			fill = fill.lerp(Color(0.05, 0.22, 0.2, 0.95), punch * 0.72)
			frame = Color(0.45, 1.0, 0.92, 0.7 + 0.3 * punch)
		elif _clear_sheath:
			# 收刀 — closes near-clear gold tension with a distinct warm sheath frame.
			fill = fill.lerp(Color(0.24, 0.14, 0.03, 0.96), punch * 0.78)
			frame = Color(1.0, 0.86, 0.36, 0.78 + 0.22 * punch)
		else:
			fill = fill.lerp(Color(0.22, 0.14, 0.04, 0.95), punch * 0.72)
			frame = Color(1.0, 0.9, 0.42, 0.7 + 0.3 * punch)
	elif combo_a > 0.0:
		# Combo rim — 2/3 courtyard teal; 5 warm gold; 8 hot 疯斩; soft ticks quiet.
		var punch := combo_a * combo_a
		if _combo_teal:
			var teal_amp := 0.58 if _combo_flash_tier >= 3 else 0.48
			fill = fill.lerp(Color(0.03, 0.14, 0.13, 0.92), punch * teal_amp)
			frame = Color(0.4, 0.98, 0.9, 0.55 + 0.45 * punch)
		elif _combo_flash_tier >= 8:
			fill = fill.lerp(Color(0.2, 0.07, 0.02, 0.95), punch * 0.68)
			frame = Color(1.0, 0.58, 0.26, 0.68 + 0.32 * punch)
		elif _combo_flash_tier >= 5:
			fill = fill.lerp(Color(0.18, 0.1, 0.02, 0.92), punch * 0.58)
			frame = Color(1.0, 0.78, 0.32, 0.6 + 0.4 * punch)
		elif _combo_flash_tier >= 3:
			fill = fill.lerp(Color(0.15, 0.1, 0.03, 0.9), punch * 0.5)
			frame = Color(1.0, 0.88, 0.4, 0.55 + 0.42 * punch)
		else:
			fill = fill.lerp(Color(0.14, 0.09, 0.03, 0.88), combo_a * 0.28)
			frame = Color(1.0, 0.84, 0.38, 0.42 + 0.38 * combo_a)
	elif break_a > 0.0:
		# 破绽 gold rim — punish window echo, snappier than boss 赤金 drop.
		fill = fill.lerp(Color(0.15, 0.1, 0.03, 0.9), break_a * 0.45)
		frame = Color(1.0, 0.88, 0.4, 0.55 + 0.45 * break_a)
	elif boss_a > 0.0:
		# 赤金 frame — boss drop echo, hotter than dynasty gold wipe.
		fill = fill.lerp(Color(0.16, 0.05, 0.02, 0.9), boss_a * 0.5)
		frame = Color(1.0, 0.58, 0.28, 0.55 + 0.45 * boss_a)
	elif elite_a > 0.0:
		# Short warm-gold frame — elite drop, quieter than 破绽 ticks.
		fill = fill.lerp(Color(0.12, 0.08, 0.03, 0.88), elite_a * 0.35)
		frame = Color(1.0, 0.82, 0.38, 0.48 + 0.4 * elite_a)
	elif ash_a > 0.0:
		# Brief crimson frame wash when stepping into 煞地.
		fill = fill.lerp(Color(0.16, 0.04, 0.04, 0.9), ash_a * 0.5)
		frame = Color(1.0, 0.38, 0.3, 0.55 + 0.45 * ash_a)
	elif mist_a > 0.0:
		# Soft violet frame wash when stepping into 滞地.
		fill = fill.lerp(Color(0.08, 0.06, 0.16, 0.9), mist_a * 0.45)
		frame = Color(0.62, 0.48, 1.0, 0.5 + 0.45 * mist_a)
	elif gold_a > 0.0:
		# Dynasty warm-gold frame — city open wipe echo on the radar.
		fill = fill.lerp(Color(0.14, 0.09, 0.03, 0.9), gold_a * 0.5)
		frame = Color(1.0, 0.84, 0.4, 0.55 + 0.4 * gold_a)
	elif yard_a > 0.0:
		# Courtyard teal frame — sect open wipe echo on the radar.
		fill = fill.lerp(Color(0.03, 0.12, 0.12, 0.9), yard_a * 0.5)
		frame = Color(0.4, 0.95, 0.88, 0.55 + 0.4 * yard_a)
	elif jade_a > 0.0:
		# Soft teal frame wash when stepping into 愈地.
		fill = fill.lerp(Color(0.04, 0.14, 0.12, 0.9), jade_a * 0.45)
		frame = Color(0.35, 0.98, 0.78, 0.5 + 0.45 * jade_a)
	elif crisis_a > 0.0:
		# Low-HP 赤框 breath — same CRISIS_PULSE_HZ as HUD / silhouette.
		fill = fill.lerp(Color(0.14, 0.03, 0.03, 0.9), crisis_a * 0.32)
		frame = Color(0.95, 0.18, 0.12, 0.42 + 0.48 * crisis_a)
	elif near_a > 0.0:
		# Near-clear rim — courtyard teal vs city gold (pairs HUD kill-bar breath).
		if _pattern == "yard" or GameState.stage_id == "sect":
			fill = fill.lerp(Color(0.03, 0.12, 0.11, 0.88), near_a * 0.3)
			frame = Color(0.4, 0.96, 0.86, 0.42 + 0.42 * near_a)
		else:
			fill = fill.lerp(Color(0.14, 0.09, 0.03, 0.88), near_a * 0.28)
			frame = Color(0.98, 0.78, 0.32, 0.42 + 0.4 * near_a)
	elif heal_rest > 0.0:
		# Soft teal frame breath while resting in 愈地 — calm vs enter jade punch.
		fill = fill.lerp(Color(0.03, 0.12, 0.11, 0.88), heal_rest * 0.28)
		frame = Color(0.38, 0.96, 0.8, 0.42 + 0.38 * heal_rest)
	elif ash_rest > 0.0:
		# Soft crimson frame breath while standing in 煞地 — sting vs enter ash punch.
		fill = fill.lerp(Color(0.14, 0.03, 0.03, 0.88), ash_rest * 0.3)
		frame = Color(1.0, 0.4, 0.32, 0.42 + 0.4 * ash_rest)
	elif mist_rest > 0.0:
		# Soft violet frame breath while standing in 滞地 — fog vs enter mist punch.
		fill = fill.lerp(Color(0.07, 0.05, 0.14, 0.88), mist_rest * 0.28)
		frame = Color(0.62, 0.5, 1.0, 0.4 + 0.38 * mist_rest)
	draw_rect(outer, fill)
	var combo_loud := combo_a > 0.15 and _combo_flash_tier >= 3
	var thick := steel_a > 0.15 or clear_a > 0.15 or combo_a > 0.2 or combo_loud or break_a > 0.2 or boss_a > 0.15 or elite_a > 0.2 or jade_a > 0.15 or ash_a > 0.15 or mist_a > 0.15 or yard_a > 0.15 or gold_a > 0.15 or crisis_a > 0.55 or near_a > 0.55 or heal_rest > 0.55 or ash_rest > 0.55 or mist_rest > 0.55
	var frame_w := 1.2 if _pattern != "yard" else 1.4
	if clear_a > 0.15 and _clear_sheath:
		frame_w = 2.9
	elif clear_a > 0.2:
		frame_w = 2.4
	elif combo_a > 0.12 and _combo_flash_tier >= 8:
		frame_w = 2.7
	elif combo_a > 0.12 and _combo_flash_tier >= 5:
		frame_w = 2.3
	elif combo_a > 0.12 and _combo_flash_tier >= 3:
		frame_w = 2.0
	elif thick:
		frame_w = 1.6
	draw_rect(outer, frame, false, frame_w)
	# 收刀 double rim + blade tick — distinct from generic city clear gold.
	if clear_a > 0.18 and _clear_sheath:
		var inset := 2.0
		var sheath_rim := Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0)
		var sa := 0.42 * clear_a * clear_a
		draw_rect(sheath_rim, Color(1.0, 0.92, 0.5, sa), false, 1.55)
		var mid := outer.get_center()
		var tick := 5.5 + 2.5 * clear_a
		draw_line(mid + Vector2(0, -tick), mid + Vector2(0, tick), Color(1.0, 0.9, 0.45, 0.55 * clear_a), 1.35)
		draw_line(mid + Vector2(-tick * 0.55, 0), mid + Vector2(tick * 0.55, 0), Color(1.0, 0.88, 0.4, 0.4 * clear_a), 1.15)
	# Milestone double rim — 5/8 read louder than soft kill ticks on the radar.
	if combo_a > 0.2 and _combo_flash_tier >= 5:
		var inset2 := 2.2
		var inner_rim := Rect2(inset2, inset2, size.x - inset2 * 2.0, size.y - inset2 * 2.0)
		var rim_a := 0.35 * combo_a * combo_a
		var rim_col := Color(1.0, 0.7, 0.3, rim_a) if _combo_flash_tier < 8 else Color(1.0, 0.5, 0.22, rim_a * 1.15)
		draw_rect(inner_rim, rim_col, false, 1.2 if _combo_flash_tier < 8 else 1.5)
	var inner := Rect2(pad, pad, size.x - pad * 2.0, size.y - pad * 2.0)
	draw_rect(inner, Color(0.05, 0.07, 0.1, 0.5))
	# Clear burst rings — expand from radar center (sect teal / 收刀 gold).
	if clear_a > 0.0:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var burst := 1.0 - clear_a # grows as flash fades
		var ring_a := (0.62 if _clear_sheath else 0.55) * clear_a
		var ring_col := Color(0.42, 0.98, 0.9, ring_a) if _clear_teal else Color(1.0, 0.86, 0.36, ring_a)
		var ring_n := 4 if _clear_sheath else 3
		for i in ring_n:
			var rr := 6.0 + burst * (18.0 + float(i) * 10.0) + float(i) * 3.0
			var a := ring_col.a * (1.0 - float(i) * 0.2)
			draw_arc(Vector2(cx, cy), rr, 0.0, TAU, 28, Color(ring_col.r, ring_col.g, ring_col.b, a), 1.7 - float(i) * 0.22)
		# Soft core bloom — 收刀 hotter settle.
		var core_a := 0.28 * clear_a if _clear_sheath else 0.22 * clear_a
		var core := Color(ring_col.r, ring_col.g, ring_col.b, core_a)
		draw_circle(Vector2(cx, cy), 4.0 + 8.0 * clear_a, core)
	if _map_size.x <= 0.0 or _map_size.y <= 0.0:
		return
	var sx := inner.size.x / _map_size.x
	var sy := inner.size.y / _map_size.y
	var t := Time.get_ticks_msec() * 0.001
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _pattern == "yard":
		_draw_yard_lanes(inner)
	elif _pattern == "city":
		_draw_city_grid(inner)
	# Zones first — 煞地 / 灵泉 pulse so map motives read mid-fight.
	for raw in _zones:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var c: Vector2 = raw.get("center", Vector2.ZERO)
		var r: float = float(raw.get("radius", 8.0))
		var effect := str(raw.get("effect", ""))
		var col := Color(0.7, 0.8, 0.9, 0.28)
		var pulse_speed := 3.2
		match effect:
			"heal":
				col = Color(0.3, 0.95, 0.55, 0.55 if _pattern == "yard" else 0.5)
				pulse_speed = 2.6
			"slow":
				# Sect slow = amber mist (courtyard incense); city keeps violet.
				if _pattern == "yard":
					col = Color(1.0, 0.82, 0.42, 0.52)
				else:
					col = Color(0.55, 0.42, 0.95, 0.5)
				pulse_speed = 2.4
			"damage":
				col = Color(0.98, 0.38, 0.32, 0.55)
				pulse_speed = 4.2
		var cp := _world_to_mini(c, inner, sx, sy)
		var rr := maxf(r * minf(sx, sy), 3.4)
		var breath := 0.55 + 0.45 * sin(t * pulse_speed)
		# Residence in 愈地 — sync player HEAL_PULSE_HZ for a soft radar micro-flash.
		var heal_active := effect == "heal" and heal_rest > 0.0
		var ash_active := effect == "damage" and ash_rest > 0.0
		var mist_active := effect == "slow" and mist_rest > 0.0
		if heal_active:
			var hbreath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
			breath = 0.62 + 0.38 * hbreath
			col = Color(0.35, 0.98, 0.78, 0.62 + 0.2 * hbreath)
		elif ash_active:
			# Sync DAMAGE_PULSE_HZ — snappier crimson sting vs calm heal.
			var dbreath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
			breath = 0.58 + 0.42 * dbreath
			col = Color(1.0, 0.36, 0.28, 0.64 + 0.22 * dbreath)
		elif mist_active:
			# Sync SLOW_PULSE_HZ — soft violet fog hang vs ash sting.
			var sbreath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0065)
			breath = 0.6 + 0.4 * sbreath
			col = Color(0.62, 0.48, 1.0, 0.6 + 0.22 * sbreath)
		draw_circle(cp, rr, Color(col.r, col.g, col.b, col.a * (0.55 + 0.45 * breath)))
		draw_arc(cp, rr, 0.0, TAU, 18, Color(col.r, col.g, col.b, 0.55 + 0.45 * breath), 1.5)
		# Expanding beacon ring — draws the eye to unexplored ground.
		var ring_r := rr * (1.15 + 0.55 * fposmod(t * (pulse_speed * 0.35), 1.0))
		var ring_a := 0.75 * (1.0 - fposmod(t * (pulse_speed * 0.35), 1.0))
		draw_arc(cp, ring_r, 0.0, TAU, 20, Color(col.r, col.g, col.b, ring_a), 1.4)
		if heal_active:
			# Soft inner jade blink — residence, not enter wipe punch.
			var blink := 0.45 + 0.55 * sin(Time.get_ticks_msec() * 0.010)
			draw_arc(cp, rr * (0.72 + 0.08 * blink), 0.0, TAU, 14, Color(0.55, 1.0, 0.88, 0.35 + 0.4 * blink), 1.35)
			draw_circle(cp, 1.2 + 0.6 * blink, Color(0.55, 1.0, 0.9, 0.55 + 0.35 * blink))
		elif ash_active:
			# Soft crimson X blink — residence sting, not enter ash punch.
			var blink2 := 0.45 + 0.55 * sin(Time.get_ticks_msec() * 0.009)
			var hs := 2.0 + 1.1 * blink2
			draw_arc(cp, rr * (0.7 + 0.1 * blink2), 0.0, TAU, 14, Color(1.0, 0.5, 0.4, 0.3 + 0.4 * blink2), 1.35)
			draw_line(cp + Vector2(-hs, -hs), cp + Vector2(hs, hs), Color(1.0, 0.55, 0.42, 0.55 + 0.4 * blink2), 1.35)
			draw_line(cp + Vector2(hs, -hs), cp + Vector2(-hs, hs), Color(1.0, 0.55, 0.42, 0.55 + 0.4 * blink2), 1.35)
		elif mist_active:
			# Soft violet square fog — residence hang, not enter mist punch.
			var blink3 := 0.45 + 0.55 * sin(Time.get_ticks_msec() * 0.0065)
			var qs := 1.8 + 1.0 * blink3
			draw_arc(cp, rr * (0.68 + 0.1 * blink3), 0.0, TAU, 14, Color(0.75, 0.65, 1.0, 0.28 + 0.38 * blink3), 1.3)
			draw_rect(Rect2(cp.x - qs, cp.y - qs, qs * 2.0, qs * 2.0), Color(0.72, 0.62, 1.0, 0.5 + 0.4 * blink3), false, 1.3)
		var pip := Color(col.r, col.g, col.b, 0.95).lightened(0.2)
		match effect:
			"heal":
				draw_circle(cp, 1.6, pip)
			"slow":
				draw_rect(Rect2(cp.x - 1.7, cp.y - 1.7, 3.4, 3.4), pip)
			"damage":
				draw_line(cp + Vector2(-2.4, -2.4), cp + Vector2(2.4, 2.4), pip, 1.4)
				draw_line(cp + Vector2(2.4, -2.4), cp + Vector2(-2.4, 2.4), pip, 1.4)
	for raw in _obstacles:
		if raw is Rect2:
			var r2: Rect2 = raw
			var mini := Rect2(
				inner.position.x + r2.position.x * sx,
				inner.position.y + r2.position.y * sy,
				maxi(r2.size.x * sx, 1.5),
				maxi(r2.size.y * sy, 1.5),
			)
			draw_rect(mini, _obs_col)
			if _pattern == "yard":
				# Soft moss rim so garden stones ≠ city walls on the radar.
				draw_rect(mini, Color(0.4, 0.7, 0.55, 0.35), false, 1.0)
	_draw_spawn_pings(inner, sx, sy, t)
	var nearest_chest: Vector2 = Vector2.ZERO
	var nearest_d := INF
	# Warm-gold hunt clock — unopened chests only (opened fade still in group briefly).
	var pulse := 0.55 + 0.45 * sin(t * 5.2)
	var beat := fposmod(t * 1.15, 1.0)
	var gold_blink := 0.5 + 0.5 * sin(t * 4.4)
	for node in get_tree().get_nodes_in_group("chests"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if node.has_method("is_opened") and bool(node.call("is_opened")):
			continue
		var cpos := (node as Node2D).global_position
		var cp2 := _world_to_mini(cpos, inner, sx, sy)
		# Unopened warm-gold pulse: soft halo → expanding ring → breathing diamond.
		var gold := Color(1.0, 0.88, 0.38, 0.5 + 0.5 * pulse)
		draw_circle(cp2, 4.6 + 1.4 * gold_blink, Color(1.0, 0.78, 0.28, 0.16 + 0.2 * gold_blink))
		var expand := 3.2 + 7.0 * beat
		draw_arc(cp2, expand, 0.0, TAU, 18, Color(1.0, 0.9, 0.45, 0.9 * (1.0 - beat)), 1.7)
		var dsz := 3.4 + 1.0 * pulse
		# Soft outer diamond wash, then solid core — reads as loot beckon.
		draw_colored_polygon(PackedVector2Array([
			cp2 + Vector2(0, -(dsz + 1.6)),
			cp2 + Vector2(dsz + 1.6, 0),
			cp2 + Vector2(0, dsz + 1.6),
			cp2 + Vector2(-(dsz + 1.6), 0),
		]), Color(1.0, 0.92, 0.5, 0.18 + 0.28 * gold_blink))
		draw_colored_polygon(PackedVector2Array([
			cp2 + Vector2(0, -dsz),
			cp2 + Vector2(dsz, 0),
			cp2 + Vector2(0, dsz),
			cp2 + Vector2(-dsz, 0),
		]), gold)
		draw_circle(cp2, 1.2 + 0.5 * gold_blink, Color(1.0, 0.98, 0.78, 0.85 + 0.15 * gold_blink))
		if player:
			var d := player.global_position.distance_squared_to(cpos)
			if d < nearest_d:
				nearest_d = d
				nearest_chest = cp2
	if player:
		var pp := _world_to_mini(player.global_position, inner, sx, sy)
		# Pulsing hunt arrow toward far unopened chests — keep exploration desire alive.
		if nearest_d > 80.0 * 80.0 and nearest_d < INF:
			var dir := (nearest_chest - pp).normalized()
			var tip := pp + dir * (11.0 + 2.0 * pulse)
			var arrow_a := 0.45 + 0.4 * pulse
			draw_line(pp + dir * 4.5, tip, Color(1.0, 0.9, 0.4, arrow_a), 1.5)
			draw_line(tip, tip - dir.rotated(0.55) * 3.5, Color(1.0, 0.9, 0.4, arrow_a), 1.3)
			draw_line(tip, tip - dir.rotated(-0.55) * 3.5, Color(1.0, 0.9, 0.4, arrow_a), 1.3)
		var near_teal := _pattern == "yard" or GameState.stage_id == "sect"
		var base_dot := Color(0.45, 0.95, 0.85)
		# Dash iframe on radar — cyan moon ring while invuln (pairs world land mark).
		var dash_a := 0.0
		if player.has_method("get_dash_iframe"):
			var di := float(player.call("get_dash_iframe"))
			if di > 0.0:
				dash_a = clampf(di / 0.32, 0.15, 1.0)
		if near_a > 0.0 and crisis_a <= 0.0 and dash_a <= 0.0:
			# Near-clear identity — courtyard teal vs city gold (pairs frame breath).
			base_dot = Color(0.42, 0.98, 0.9) if near_teal else Color(1.0, 0.86, 0.42)
		elif dash_a > 0.0:
			base_dot = Color(0.5, 0.95, 1.0)
		draw_circle(pp, 3.2 + (0.45 * dash_a) + (0.35 * near_a if crisis_a <= 0.0 and dash_a <= 0.0 else 0.0) + (1.2 * clear_a if clear_a > 0.0 else 0.0), base_dot.lerp(Color(1.0, 0.32, 0.28), crisis_a * 0.55) if crisis_a > 0.0 and dash_a <= 0.0 else (base_dot if clear_a <= 0.0 else (Color(0.5, 1.0, 0.94) if _clear_teal else Color(1.0, 0.92, 0.5))))
		if dash_a > 0.0:
			# Cyan moon ring — invuln must beat crisis/near-clear clutter on the radar.
			var dash_pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.028)
			var cyan := Color(0.4, 0.92, 1.0, 0.35 + 0.5 * dash_a * dash_pulse)
			var rr := 5.2 + 2.2 * dash_pulse * dash_a
			draw_arc(pp, rr, 0.0, TAU, 16, cyan, 1.55)
			draw_arc(pp, rr * 0.62, 0.0, TAU, 14, Color(0.7, 0.98, 1.0, cyan.a * 0.55), 1.1)
			# Soft crescent chord — moon-mark echo of world land ring.
			var cpts: PackedVector2Array = []
			for i in 8:
				var ct := float(i) / 7.0
				var a2 := -0.9 + 1.8 * ct
				cpts.append(pp + Vector2(cos(a2) * (rr * 0.85), sin(a2) * (rr * 0.55)) + Vector2(1.2, 0))
			if cpts.size() >= 2:
				draw_polyline(cpts, Color(0.85, 0.98, 1.0, 0.55 + 0.35 * dash_pulse * dash_a), 1.2)
		elif crisis_a > 0.0:
			draw_arc(pp, 5.0 + 1.2 * crisis_a, 0.0, TAU, 12, Color(0.95, 0.2, 0.15, 0.28 + 0.4 * crisis_a), 1.2)
		elif clear_a > 0.0:
			# Player-local clear nova — pairs center burst, louder than near-clear ring.
			var clr := Color(0.4, 0.98, 0.9, 0.35 + 0.5 * clear_a) if _clear_teal else Color(1.0, 0.86, 0.38, 0.35 + 0.5 * clear_a)
			var pr := 5.5 + 6.0 * (1.0 - clear_a) + 2.5 * clear_a
			draw_arc(pp, pr, 0.0, TAU, 16, clr, 1.5)
			draw_arc(pp, pr * 0.55, 0.0, TAU, 14, Color(clr.r, clr.g, clr.b, clr.a * 0.5), 1.1)
		elif near_a > 0.0:
			# Soft expanding outer ring — tension before clear, not a crisis panic.
			var rr2 := 5.2 + 1.6 * near_a
			var ring_col := Color(0.4, 0.96, 0.88, 0.3 + 0.45 * near_a) if near_teal else Color(1.0, 0.84, 0.38, 0.3 + 0.45 * near_a)
			draw_arc(pp, rr2, 0.0, TAU, 14, ring_col, 1.35)
			draw_arc(pp, rr2 * 0.72, 0.0, TAU, 12, Color(ring_col.r, ring_col.g, ring_col.b, ring_col.a * 0.45), 1.0)
		else:
			draw_arc(pp, 5.0, 0.0, TAU, 12, Color(0.45, 0.95, 0.85, 0.35), 1.0)
	for node in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var mob2d := node as Node2D
		var mp := _world_to_mini(mob2d.global_position, inner, sx, sy)
		var mob_node: Node = node
		var is_boss := false
		var is_elite := false
		if mob_node.get("def") != null:
			var enemy_def: Variant = mob_node.get("def")
			if enemy_def != null:
				is_boss = bool(enemy_def.is_boss)
		if mob_node.get("is_elite") != null:
			is_elite = bool(mob_node.get("is_elite"))
		# Near-threat breath — close mobs pulse hot red on the radar.
		var threat := 0.0
		if player:
			var dist := player.global_position.distance_to(mob2d.global_position)
			if dist < 70.0:
				threat = 1.0
			elif dist < 115.0:
				threat = 1.0 - (dist - 70.0) / 45.0
			elif dist < 155.0:
				threat = 0.4 * (1.0 - (dist - 115.0) / 40.0)
		var threat_pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.016)
		if is_boss:
			var recovering := false
			if mob_node.has_method("is_recovering"):
				recovering = bool(mob_node.call("is_recovering"))
			elif mob_node.get("_recovering") != null:
				recovering = bool(mob_node.get("_recovering"))
			var boss_col := Color(1.0, 0.45, 0.4)
			if threat > 0.2:
				boss_col = boss_col.lerp(Color(1.0, 0.22, 0.18), threat * 0.55)
			draw_circle(mp, 3.5 + 0.55 * threat * threat_pulse, boss_col)
			if threat > 0.25 and not recovering and break_a <= 0.15:
				# Soft threat ring — close boss pressure without stealing 破绽 gold.
				var ta := (0.25 + 0.4 * threat * threat_pulse)
				draw_arc(mp, 5.0 + 1.4 * threat_pulse * threat, 0.0, TAU, 12, Color(1.0, 0.28, 0.22, ta), 1.35)
			if recovering or break_a > 0.15:
				# Boss 破绽 — gold tick ring on the body pip (pairs HUD bar + edge).
				var bp := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
				var ba := 0.55 + 0.4 * maxf(break_a, 0.35 if recovering else 0.0) * bp
				draw_arc(mp, 5.2 + 1.2 * bp, 0.0, TAU, 14, Color(1.0, 0.9, 0.4, ba), 1.55)
				draw_line(mp + Vector2(0, -3.2), mp + Vector2(0, 3.2), Color(1.0, 0.95, 0.55, ba), 1.2)
				draw_line(mp + Vector2(-3.2, 0), mp + Vector2(3.2, 0), Color(1.0, 0.95, 0.55, ba), 1.2)
		elif is_elite:
			var elite_col := Color(1.0, 0.85, 0.35)
			if threat > 0.2:
				elite_col = elite_col.lerp(Color(1.0, 0.4, 0.25), threat * 0.65)
			draw_circle(mp, 2.4 + 0.5 * threat * threat_pulse, elite_col)
			if threat > 0.3:
				draw_arc(mp, 3.8 + 1.2 * threat * threat_pulse, 0.0, TAU, 12, Color(1.0, 0.35, 0.22, 0.3 + 0.4 * threat * threat_pulse), 1.2)
		else:
			# Far: cool/warm trash. Near: hot red breath so threat reads mid-fight.
			var base := Color(0.75, 0.55, 0.5) if _pattern == "yard" else Color(0.95, 0.55, 0.45)
			if threat > 0.12:
				base = base.lerp(Color(1.0, 0.22, 0.18), threat * (0.75 + 0.25 * threat_pulse))
			var rr := 2.0 + 0.7 * threat * threat_pulse
			draw_circle(mp, rr, base)
			if threat > 0.35:
				draw_arc(mp, 3.4 + 1.4 * threat * threat_pulse, 0.0, TAU, 12, Color(1.0, 0.3, 0.22, 0.28 + 0.42 * threat * threat_pulse), 1.15)
func _draw_yard_lanes(inner: Rect2) -> void:
	# Soft courtyard cross — north gate ↔ south path, east/west wings.
	var mid := inner.get_center()
	var lane := Color(0.35, 0.7, 0.62, 0.22)
	var thick := 3.2
	draw_line(Vector2(mid.x, inner.position.y + 2.0), Vector2(mid.x, inner.end.y - 2.0), lane, thick)
	draw_line(Vector2(inner.position.x + 2.0, mid.y * 0.92), Vector2(inner.end.x - 2.0, mid.y * 0.92), lane, thick)
	# Gate pips — where trash prefers to drop.
	var gates := [
		Vector2(mid.x, inner.position.y + 5.0),
		Vector2(inner.position.x + 6.0, mid.y * 0.7),
		Vector2(inner.end.x - 6.0, mid.y * 0.7),
		Vector2(mid.x, inner.end.y - 5.0),
	]
	for g in gates:
		draw_circle(g, 1.4, Color(0.45, 0.9, 0.8, 0.4))

func _draw_city_grid(inner: Rect2) -> void:
	var street := Color(0.7, 0.55, 0.35, 0.16)
	var mid := inner.get_center()
	draw_line(Vector2(mid.x, inner.position.y + 2.0), Vector2(mid.x, inner.end.y - 2.0), street, 2.4)
	draw_line(Vector2(inner.position.x + 2.0, mid.y), Vector2(inner.end.x - 2.0, mid.y), street, 2.4)

func _draw_spawn_pings(inner: Rect2, sx: float, sy: float, t: float) -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return
	var pings: Array = world.call("recent_spawn_pings")
	for raw in pings:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var pos: Vector2 = raw.get("pos", Vector2.ZERO)
		var life := float(raw.get("life", 0.0))
		if life <= 0.0:
			continue
		var kind := str(raw.get("kind", ""))
		var mp := _world_to_mini(pos, inner, sx, sy)
		var life_max := float(raw.get("life_max", 0.0))
		if life_max <= 0.0:
			life_max = 1.15
			if kind == "steel":
				life_max = 1.65
			elif kind == "gold":
				life_max = 1.0
			elif kind == "jade":
				life_max = 1.25
			elif kind == "ash":
				life_max = 1.05
			elif kind == "mist":
				life_max = 1.2
			elif kind == "yard":
				life_max = 1.28
			elif kind == "boss":
				life_max = 1.55
			elif kind == "break":
				life_max = 1.2
			elif kind == "elite":
				life_max = 0.72
			elif kind == "chest":
				life_max = 1.35
		var a := clampf(life / life_max, 0.0, 1.0)
		var col := Color(0.4, 0.95, 0.9, 0.75 * a) if _pattern == "yard" else Color(1.0, 0.82, 0.38, 0.75 * a)
		var rr := 2.2 + (1.0 - a) * 4.0 + 0.4 * sin(t * 10.0)
		var stroke := 1.3
		if kind == "chest":
			# Chest open — warm-gold diamond nova (pairs unopened loot language).
			col = Color(1.0, 0.88, 0.4, 0.98 * a)
			rr = 3.4 + (1.0 - a) * 5.8 + 0.45 * sin(t * 11.0)
			stroke = 1.85
			draw_circle(mp, rr * 0.5, Color(1.0, 0.78, 0.3, 0.22 * a))
			draw_arc(mp, rr * 0.65, 0.0, TAU, 16, Color(1.0, 0.92, 0.55, 0.62 * a), 1.35)
			var cd := 2.6 + (1.0 - a) * 2.0
			draw_colored_polygon(PackedVector2Array([
				mp + Vector2(0, -(cd + 1.2)),
				mp + Vector2(cd + 1.2, 0),
				mp + Vector2(0, cd + 1.2),
				mp + Vector2(-(cd + 1.2), 0),
			]), Color(1.0, 0.9, 0.5, 0.2 * a))
			draw_colored_polygon(PackedVector2Array([
				mp + Vector2(0, -cd),
				mp + Vector2(cd, 0),
				mp + Vector2(0, cd),
				mp + Vector2(-cd, 0),
			]), Color(1.0, 0.84, 0.38, 0.55 * a))
		if kind == "yard":
			# Sect spawn / open — louder courtyard teal double-ring.
			col = Color(0.4, 0.96, 0.9, 0.98 * a)
			rr = 3.2 + (1.0 - a) * 5.6 + 0.45 * sin(t * 11.0)
			stroke = 1.85
			draw_circle(mp, rr * 0.52, Color(0.35, 0.92, 0.84, 0.24 * a))
			draw_arc(mp, rr * 0.62, 0.0, TAU, 14, Color(0.55, 1.0, 0.94, 0.65 * a), 1.3)
		if kind == "gold":
			# Dynasty spawn / open — warm-gold double-ring (mirrors yard teal).
			col = Color(1.0, 0.86, 0.4, 0.98 * a)
			rr = 3.0 + (1.0 - a) * 5.0 + 0.4 * sin(t * 12.0)
			stroke = 1.75
			draw_circle(mp, rr * 0.5, Color(1.0, 0.78, 0.32, 0.22 * a))
			draw_arc(mp, rr * 0.58, 0.0, TAU, 14, Color(1.0, 0.92, 0.55, 0.62 * a), 1.2)
		if kind == "steel":
			# Warm steel blade pip — louder than calm cyan yard drops.
			col = Color(1.0, 0.78, 0.38, 0.95 * a)
			rr = 3.0 + (1.0 - a) * 5.5 + 0.6 * sin(t * 14.0)
			stroke = 1.8
			draw_circle(mp, rr * 0.55, Color(1.0, 0.7, 0.3, 0.22 * a))
			draw_line(mp + Vector2(-2.8, 0), mp + Vector2(2.8, 0), Color(1.0, 0.9, 0.55, 0.9 * a), 1.2)
			draw_line(mp + Vector2(0, -2.8), mp + Vector2(0, 2.8), Color(1.0, 0.9, 0.55, 0.9 * a), 1.2)
		if kind == "jade":
			# Teal/jade ring — calm heal-enter, opposite of steel/gold punch.
			col = Color(0.35, 0.98, 0.78, 0.92 * a)
			rr = 2.6 + (1.0 - a) * 4.8 + 0.35 * sin(t * 9.0)
			stroke = 1.55
			draw_circle(mp, rr * 0.45, Color(0.3, 0.9, 0.7, 0.18 * a))
			draw_arc(mp, rr * 0.55, 0.0, TAU, 12, Color(0.55, 1.0, 0.85, 0.55 * a), 1.1)
		if kind == "boss":
			# Boss drop — 赤金 diamond + ring, louder than trash gold pip.
			col = Color(1.0, 0.55, 0.28, 0.98 * a)
			rr = 3.6 + (1.0 - a) * 6.2 + 0.5 * sin(t * 13.0)
			stroke = 2.0
			draw_circle(mp, rr * 0.55, Color(1.0, 0.4, 0.18, 0.22 * a))
			draw_arc(mp, rr * 0.68, 0.0, TAU, 16, Color(1.0, 0.78, 0.4, 0.62 * a), 1.4)
			var bd := 2.4 + (1.0 - a) * 1.4
			draw_colored_polygon(PackedVector2Array([
				mp + Vector2(0, -bd),
				mp + Vector2(bd, 0),
				mp + Vector2(0, bd),
				mp + Vector2(-bd, 0),
			]), Color(1.0, 0.62, 0.3, 0.55 * a))
		if kind == "break":
			# 破绽 — warm-gold tick cross (punish window, not boss 赤金 drop).
			col = Color(1.0, 0.9, 0.42, 0.96 * a)
			rr = 3.2 + (1.0 - a) * 5.0 + 0.45 * sin(t * 14.0)
			stroke = 1.75
			draw_circle(mp, rr * 0.48, Color(1.0, 0.82, 0.35, 0.2 * a))
			draw_arc(mp, rr * 0.6, 0.0, TAU, 14, Color(1.0, 0.95, 0.55, 0.58 * a), 1.25)
			var tk := 2.8 + (1.0 - a) * 1.2
			draw_line(mp + Vector2(0, -tk), mp + Vector2(0, tk), Color(1.0, 0.96, 0.6, 0.92 * a), 1.3)
			draw_line(mp + Vector2(-tk, 0), mp + Vector2(tk, 0), Color(1.0, 0.96, 0.6, 0.92 * a), 1.3)
		if kind == "elite":
			# Elite drop — short warm crown pip, quieter than 破绽 ticks / boss 赤金.
			col = Color(1.0, 0.82, 0.38, 0.9 * a)
			rr = 2.2 + (1.0 - a) * 3.6 + 0.3 * sin(t * 12.0)
			stroke = 1.4
			draw_circle(mp, rr * 0.4, Color(1.0, 0.78, 0.32, 0.18 * a))
			draw_colored_polygon(PackedVector2Array([
				mp + Vector2(-2.2, -1.2),
				mp + Vector2(0, -3.4),
				mp + Vector2(2.2, -1.2),
			]), Color(1.0, 0.88, 0.42, 0.75 * a))
		if kind == "ash":
			# Crimson X ping — 煞地 sting, snappier than jade linger.
			col = Color(1.0, 0.38, 0.3, 0.95 * a)
			rr = 2.8 + (1.0 - a) * 5.0 + 0.45 * sin(t * 13.0)
			stroke = 1.7
			draw_circle(mp, rr * 0.4, Color(0.95, 0.2, 0.15, 0.2 * a))
			draw_line(mp + Vector2(-2.6, -2.6), mp + Vector2(2.6, 2.6), Color(1.0, 0.55, 0.42, 0.9 * a), 1.3)
			draw_line(mp + Vector2(2.6, -2.6), mp + Vector2(-2.6, 2.6), Color(1.0, 0.55, 0.42, 0.9 * a), 1.3)
		if kind == "mist":
			# Violet square fog — 滞地 hang, softer than ash sting.
			col = Color(0.62, 0.48, 1.0, 0.92 * a)
			rr = 2.5 + (1.0 - a) * 4.6 + 0.3 * sin(t * 8.0)
			stroke = 1.5
			draw_circle(mp, rr * 0.42, Color(0.45, 0.35, 0.9, 0.16 * a))
			var hs := 2.2 + (1.0 - a) * 1.2
			draw_rect(Rect2(mp.x - hs, mp.y - hs, hs * 2.0, hs * 2.0), Color(0.75, 0.65, 1.0, 0.55 * a), false, 1.2)
		draw_arc(mp, rr, 0.0, TAU, 14, col, stroke)
		draw_circle(mp, 1.7 if kind == "steel" or kind == "boss" or kind == "chest" else 1.3, Color(col.r, col.g, col.b, 0.9 * a))

func _steel_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "steel":
			continue
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / 1.65, 0.0, 1.0))
	return best

func _jade_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "jade":
			continue
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / 1.25, 0.0, 1.0))
	return best

func _ash_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "ash":
			continue
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / 1.05, 0.0, 1.0))
	return best

func _mist_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "mist":
			continue
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / 1.2, 0.0, 1.0))
	return best

func _yard_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "yard":
			continue
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / 1.15, 0.0, 1.0))
	return best

func _gold_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var k := str(raw.get("kind", ""))
		# Dynasty wipe gold + chest open loot share warm-gold frame language.
		if k != "gold" and k != "chest":
			continue
		var life_max := 1.35 if k == "chest" else 0.85
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / life_max, 0.0, 1.0))
	return best

func _boss_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "boss":
			continue
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / 1.55, 0.0, 1.0))
	return best

func _break_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "break":
			continue
		var life_max := float(raw.get("life_max", 1.2))
		if life_max <= 0.0:
			life_max = 1.2
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / life_max, 0.0, 1.0))
	return best

func _elite_ping_strength() -> float:
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("recent_spawn_pings"):
		return 0.0
	var best := 0.0
	for raw in world.call("recent_spawn_pings"):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("kind", "")) != "elite":
			continue
		best = maxf(best, clampf(float(raw.get("life", 0.0)) / 0.72, 0.0, 1.0))
	return best

## Soft jade breath while standing in 愈地 — pairs silhouette HEAL_PULSE_HZ.
func _heal_residence_strength() -> float:
	if GameState.dead:
		return 0.0
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("current_zone_effect"):
		return 0.0
	if str(world.call("current_zone_effect")) != "heal":
		return 0.0
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
	return 0.32 + 0.68 * breath

## Soft crimson breath while standing in 煞地 — pairs silhouette DAMAGE_PULSE_HZ.
func _damage_residence_strength() -> float:
	if GameState.dead:
		return 0.0
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("current_zone_effect"):
		return 0.0
	if str(world.call("current_zone_effect")) != "damage":
		return 0.0
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	return 0.34 + 0.66 * breath

## Soft violet fog breath while standing in 滞地 — pairs silhouette SLOW_PULSE_HZ.
func _slow_residence_strength() -> float:
	if GameState.dead:
		return 0.0
	var world := get_tree().get_first_node_in_group("game_world")
	if world == null or not world.has_method("current_zone_effect"):
		return 0.0
	if str(world.call("current_zone_effect")) != "slow":
		return 0.0
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0065)
	return 0.3 + 0.7 * breath

## Low-HP 赤框 — pairs HUD / player CRISIS_PULSE_HZ (0.007).
func _crisis_strength() -> float:
	if GameState.dead or GameState.hp <= 0:
		return 0.0
	if GameState.max_hp <= 0:
		return 0.0
	if float(GameState.hp) / float(GameState.max_hp) > 0.3:
		return 0.0
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
	# Louder crest — matches strengthened HUD edge / HP bar swing.
	return 0.4 + 0.6 * breath

## Kill bar ≥75% — soft rim breath; teal on yard, gold on city (pairs HUD).
func _near_clear_strength() -> float:
	if GameState.dead:
		return 0.0
	var stage := GameState.current_stage()
	if stage == null:
		return 0.0
	var kills := GameState.stage_kills()
	var target := maxi(stage.kill_target, 1)
	if kills >= stage.kill_target:
		return 0.0
	var ratio := clampf(float(kills) / float(target), 0.0, 1.0)
	if ratio < 0.75:
		return 0.0
	if kills >= stage.boss_at_kill and not stage.boss_id.is_empty():
		return 0.0
	var hz := 0.01 if (_pattern == "yard" or GameState.stage_id == "sect") else 0.009
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * hz)
	return 0.32 + 0.68 * breath

func _world_to_mini(pos: Vector2, inner: Rect2, sx: float, sy: float) -> Vector2:
	return Vector2(inner.position.x + pos.x * sx, inner.position.y + pos.y * sy)
