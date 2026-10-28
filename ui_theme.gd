class_name UITheme
## One dark-red horror theme for every menu / HUD panel.

const RED := Color(0.72, 0.06, 0.06)


static func _box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", _box(Color(0.08, 0.02, 0.02, 0.88), Color(0.5, 0.05, 0.05), 1))
	t.set_stylebox("hover", "Button", _box(Color(0.30, 0.04, 0.04, 0.95), RED, 2))
	t.set_stylebox("pressed", "Button", _box(Color(0.5, 0.06, 0.06, 1.0), RED, 2))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(1, 0.3, 0.3), 2))
	t.set_color("font_color", "Button", Color(0.92, 0.86, 0.82))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "LineEdit", _box(Color(0.05, 0.05, 0.06, 0.9), Color(0.35, 0.08, 0.08), 1))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.07, 0.05, 0.05, 0.95), RED, 2))
	t.set_color("font_color", "LineEdit", Color(0.9, 0.85, 0.8))
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.45, 0.45))
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.03, 0.015, 0.015, 0.92), Color(0.45, 0.05, 0.05), 1, 6))
	t.set_color("font_color", "Label", Color(0.9, 0.85, 0.82))
	t.set_color("font_color", "CheckBox", Color(0.9, 0.85, 0.82))
	return t
