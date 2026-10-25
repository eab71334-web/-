extends Control
class_name DoorQTE
## Last second: the Shadow's arm is in the doorway. Tap/press E/Space as fast as you can to slam the door shut.

signal finished(success: bool)

var p := 0.25
var t := 0.0
var _mobile := OS.has_feature("mobile")
var _done := false
var _shake := 0.0


func _ready() -> void:
	theme = UITheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.text = "أغلق الباب!! اضغط بسرعة"
	l.anchor_right = 1.0
	l.offset_top = 24
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", Color(1, 0.15, 0.1))
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(l)
	Util.play(self, "static", -8.0)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var tap := false
	if event is InputEventScreenTouch and event.pressed:
		tap = true
	elif event is InputEventMouseButton and event.pressed and not _mobile:
		tap = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_SPACE):
		tap = true
	if tap:
		p = minf(p + 0.09, 1.2)
		_shake = 1.0
		Util.play(self, "slam", -14.0)


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	p -= (0.2 + t * 0.02) * delta
	_shake = move_toward(_shake, 0.0, delta * 4.0)
	queue_redraw()
	if p >= 1.0:
		_finish(true)
	elif p <= 0.0 or t > 9.0:
		_finish(false)


func _finish(ok: bool) -> void:
	_done = true
	Util.play(self, "slam" if ok else "sting", 4.0)
	finished.emit(ok)


func _draw() -> void:
	var s := size
	var j := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 8.0 * _shake
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.15 + 0.1 * sin(Time.get_ticks_msec() / 120.0), 0.0, 0.0, 0.88))
	var fw := s.x * 0.5
	var fh := s.y * 0.66
	var fx := (s.x - fw) / 2.0
	var fy := s.y * 0.18
	draw_rect(Rect2(Vector2(fx, fy) + j, Vector2(fw, fh)), Color(0.01, 0.01, 0.02))
	var closed := clampf(p, 0.0, 1.0)
	var door_w := fw * closed
	var gx := fx + door_w
	# the arm reaching through the gap
	var hand := Vector2(gx + 18.0 + (1.0 - closed) * fw * 0.25, fy + fh * 0.5)
	draw_line(Vector2(fx + fw, fy + fh * 0.55) + j, hand + j, Color(0.45, 0.5, 0.42), 46.0)
	for i in 4:
		var a := -0.5 + i * 0.33
		draw_line(hand + j, hand + Vector2(-60.0, 0.0).rotated(a) + j, Color(0.8, 0.77, 0.65), 7.0)
	draw_rect(Rect2(Vector2(fx, fy) + j, Vector2(door_w, fh)), Color(0.28, 0.2, 0.14))
	draw_rect(Rect2(s.x * 0.25, s.y * 0.9, s.x * 0.5, 16), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(s.x * 0.25, s.y * 0.9, s.x * 0.5 * closed, 16), Color(0.9, 0.15, 0.1))
