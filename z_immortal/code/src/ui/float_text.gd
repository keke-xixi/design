extends Node2D

@onready var _label: Label = $Label

func setup(pos: Vector2, text: String, color: Color) -> void:
	global_position = pos
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	# Larger pop for chunky hits / combo shouts so early combat reads as punchy.
	var shizhan := text == "市斩"
	var slashish := text == "斩" or shizhan or text == "收刀" or text.begins_with("斩") or text.ends_with("斩")
	var breakish := text == "破" or text.begins_with("破")
	var combo_count := text.ends_with("连") or text.ends_with("连!")
	var comboish := slashish or breakish or combo_count or text.begins_with("伤+")
	var big := text.length() <= 3 and text.is_valid_int() and int(text) >= 16
	var critish := text.length() <= 3 and text.is_valid_int() and int(text) >= 28
	# Dynasty 市斩 + combo shouts get a warm-gold trail (no extra hitstop).
	var gold_trail := shizhan or combo_count or (slashish and text == "斩" and GameState.combo >= 2)
	# Sect first「斩」— calm teal trail (pairs 市斩 gold; not 破绽).
	var sect_first_zhan := text == "斩" and GameState.early_kill_hook() and GameState.combo <= 1 and GameState.stage_id == "sect"
	# 破/破绽 mirror with teal trail — opposite of 市斩 warm gold.
	var teal_trail := breakish or sect_first_zhan
	var size := 12
	if slashish:
		# 市斩/收刀 are two glyphs — slightly smaller than single 斩 but still loud.
		if text == "收刀":
			size = 25
		elif shizhan:
			# Dynasty 市斩 — a touch louder than before so the glyph pops.
			size = 26 if GameState.early_kill_hook() else 22
		elif sect_first_zhan:
			# Sect first blood — match 市斩 loudness with teal language.
			size = 28
		else:
			size = 26 if GameState.early_kill_hook() else 22
			if gold_trail:
				size += 1
	elif breakish:
		# Slightly louder「破」so the punish glyph matches 市斩 punch.
		size = 26 if text == "破" else 24
	elif comboish:
		# Combo count floats sit slightly bigger with the trail.
		if combo_count:
			size = 20
		elif text.begins_with("伤+"):
			size = 16
		else:
			size = 18
	elif critish:
		size = 18
	elif big:
		size = 15
	_label.add_theme_font_size_override("font_size", size)
	if gold_trail:
		# Warm-gold shadow under the glyph — reads as a slash trail.
		_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.72, 0.28, 0.78))
		_label.add_theme_constant_override("shadow_offset_x", 3)
		_label.add_theme_constant_override("shadow_offset_y", 2)
	elif teal_trail:
		# Teal-jade shadow — heal/破绽 family vs slash gold.
		_label.add_theme_color_override("font_shadow_color", Color(0.25, 0.95, 0.78, 0.78))
		_label.add_theme_constant_override("shadow_offset_x", 3)
		_label.add_theme_constant_override("shadow_offset_y", 2)
	var rise := 26.0
	if slashish:
		rise = 54.0 if shizhan else (56.0 if sect_first_zhan else 52.0)
	elif breakish:
		rise = 50.0
	elif comboish:
		rise = 46.0 if combo_count else 44.0
	elif critish:
		rise = 38.0
	elif big:
		rise = 32.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", pos.y - rise, 0.5)
	if big or comboish or critish or breakish or sect_first_zhan:
		var peak := 1.42 if slashish else (1.35 if breakish else (1.28 if comboish else (1.2 if critish else 1.12)))
		if shizhan:
			peak = 1.48
		elif sect_first_zhan:
			peak = 1.5
		elif teal_trail:
			peak = 1.4
		elif gold_trail and combo_count:
			peak = 1.32
		scale = Vector2(0.72 if slashish or breakish else 0.82, 0.72 if slashish or breakish else 0.82)
		tw.tween_property(self, "scale", Vector2(peak, peak), 0.11).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.12)
	if slashish:
		# Micro wobble after pop — sequential so it reads as a hit.
		var wob := create_tween()
		wob.tween_property(self, "rotation", 0.1, 0.05)
		wob.tween_property(self, "rotation", -0.08, 0.06)
		wob.tween_property(self, "rotation", 0.0, 0.08)
	elif teal_trail:
		# Soft opposite wobble — reads as a pierce, not a slash.
		var wob2 := create_tween()
		wob2.tween_property(self, "rotation", -0.08, 0.05)
		wob2.tween_property(self, "rotation", 0.06, 0.06)
		wob2.tween_property(self, "rotation", 0.0, 0.08)
	if gold_trail:
		_spawn_warm_gold_trail(size)
	elif teal_trail:
		_spawn_teal_trail(size)
	tw.chain().tween_callback(queue_free)

## Soft ghost glyphs lag behind — warm-gold trail without extra hitstop.
func _spawn_warm_gold_trail(font_size: int) -> void:
	for i in 2:
		var ghost := Label.new()
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.text = _label.text
		ghost.add_theme_font_size_override("font_size", maxi(font_size - 2 - i, 10))
		ghost.add_theme_color_override("font_color", Color(1.0, 0.82 - i * 0.08, 0.38, 0.5 - i * 0.16))
		ghost.position = _label.position + Vector2(-4.0 - float(i) * 5.0, 3.0 + float(i) * 4.0)
		ghost.z_index = -1 - i
		add_child(ghost)
		var gtw := create_tween()
		gtw.set_parallel(true)
		gtw.tween_property(ghost, "position", ghost.position + Vector2(-8.0 - float(i) * 5.0, 10.0 + float(i) * 5.0), 0.42)
		gtw.tween_property(ghost, "modulate:a", 0.0, 0.38).set_delay(0.04 + float(i) * 0.05)

## Soft ghost glyphs — teal/jade trail for 破/破绽 (mirror of gold slash trail).
func _spawn_teal_trail(font_size: int) -> void:
	for i in 2:
		var ghost := Label.new()
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.text = _label.text
		ghost.add_theme_font_size_override("font_size", maxi(font_size - 2 - i, 10))
		ghost.add_theme_color_override("font_color", Color(0.35 + i * 0.05, 0.95 - i * 0.06, 0.82 - i * 0.05, 0.5 - i * 0.16))
		ghost.position = _label.position + Vector2(4.0 + float(i) * 5.0, 3.0 + float(i) * 4.0)
		ghost.z_index = -1 - i
		add_child(ghost)
		var gtw := create_tween()
		gtw.set_parallel(true)
		gtw.tween_property(ghost, "position", ghost.position + Vector2(8.0 + float(i) * 5.0, 10.0 + float(i) * 5.0), 0.42)
		gtw.tween_property(ghost, "modulate:a", 0.0, 0.38).set_delay(0.04 + float(i) * 0.05)
