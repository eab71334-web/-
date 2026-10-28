extends Control
class_name Viewfinder
## Camera viewfinder overlay (corners, REC dot, battery). Visible while the camera is on.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	visible = Game.camera_on
	if visible:
		queue_redraw()


func _draw() -> void:
	var s := size
	var m := 60.0
	var l := 70.0
	var c := Color(1, 1, 1, 0.85)
	for sx in [0.0, 1.0]:
		for sy in [0.0, 1.0]:
			var p := Vector2(lerpf(m, s.x - m, sx), lerpf(m, s.y - m, sy))
			var dx := l if sx == 0.0 else -l
			var dy := l if sy == 0.0 else -l
			draw_line(p, p + Vector2(dx, 0), c, 3.0)
			draw_line(p, p + Vector2(0, dy), c, 3.0)
	draw_line(s / 2.0 + Vector2(-14, 0), s / 2.0 + Vector2(14, 0), c, 2.0)
	draw_line(s / 2.0 + Vector2(0, -14), s / 2.0 + Vector2(0, 14), c, 2.0)
	var font := ThemeDB.fallback_font
	if int(Time.get_ticks_msec() / 500.0) % 2 == 0:
		draw_circle(Vector2(m + 20, m + 20), 8.0, Color(1, 0.1, 0.1))
	draw_string(font, Vector2(m + 40, m + 30), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(s.x - m - 230, m + 30), "BAT %d%%" % int(Game.battery), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(s.x / 2.0 - 130, s.y - m - 10), "[E] التقط صورة", HORIZONTAL_ALIGNMENT_CENTER, 260, 24, Color(1, 1, 1, 0.8))
