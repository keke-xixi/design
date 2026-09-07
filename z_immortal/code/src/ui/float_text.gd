extends Node2D

@onready var _label: Label = $Label

func setup(pos: Vector2, text: String, color: Color) -> void:
	global_position = pos
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	var big := text.length() <= 3 and text.is_valid_int() and int(text) >= 20
	_label.add_theme_font_size_override("font_size", 16 if big else 12)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", pos.y - (34.0 if big else 26.0), 0.55)
	if big:
		tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.chain().tween_callback(queue_free)
