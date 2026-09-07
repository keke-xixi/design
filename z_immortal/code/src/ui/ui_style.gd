extends RefCounted

## Shared StyleBox helpers for 640x360 dark-cyan-gold UI.

static func panel(bg: Color = Color(0.06, 0.09, 0.12, 0.9), border: Color = Color(0.55, 0.78, 0.88, 0.75), radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func button_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.16, 0.2, 0.95)
	s.border_color = Color(0.72, 0.82, 0.55, 0.85)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

static func button_hover() -> StyleBoxFlat:
	var s := button_normal()
	s.bg_color = Color(0.16, 0.22, 0.28, 0.98)
	s.border_color = Color(0.95, 0.88, 0.55, 1.0)
	return s

static func apply_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", button_normal())
	btn.add_theme_stylebox_override("hover", button_hover())
	btn.add_theme_stylebox_override("pressed", button_hover())
	btn.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.82))

static func apply_primary_button(btn: Button) -> void:
	var n := button_normal()
	n.bg_color = Color(0.18, 0.28, 0.32, 0.98)
	n.border_color = Color(0.85, 0.78, 0.45, 0.95)
	n.set_border_width_all(2)
	var h := button_hover()
	h.bg_color = Color(0.24, 0.36, 0.4, 1.0)
	h.border_color = Color(1.0, 0.92, 0.55, 1.0)
	h.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.9))

static func apply_panel(panel: PanelContainer, accent: Color = Color(0.55, 0.78, 0.88, 0.75)) -> void:
	panel.add_theme_stylebox_override("panel", panel(Color(0.06, 0.09, 0.12, 0.9), accent))
