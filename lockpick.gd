extends Control
class_name LockPick
## Lock-picking mini-game. Move the pick (drag / mouse / A-D) to find the sweet spot, hold TURN
## (button / Space / mouse) to rotate the cylinder. Pushing against resistance builds stress: pick breaks.

signal finished(success: bool)

var pick_angle := 0.0
var sweet := 0.0
var turn := 0.0
var stress := 0.0
var picks := 3
var holding := false
var active := false
var _mobile := OS.has_feature("mobile")
var _drag_idx := -1
var _turn_idx := -1
var _last_tick := 0
var _creak_cd := 0.0


func reset() -> void:
	picks = 3
	_new_lock()
	active = true


func _new_lock() -> void:
	sweet = randf_range(-65.0, 65.0)
	turn = 0.0
	stress = 0.0
	pick_angle = 0.0
	_last_tick = 0


func _turn_pos() -> Vector2:
	return Vector2(size.x - 140.0, size.y - 150.0)


func _set_angle_from_x(x: float) -> void:
	pick_angle = clampf(remap(x, size.x * 0.15, size.x * 0.85, -90.0, 90.0), -90.0, 90.0)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if _mobile:
		if event is InputEventScreenTouch:
			if event.pressed:
				if event.position.distance_to(_turn_pos()) < 90.0:
					_turn_idx = event.index
					holding = true
				elif _drag_idx == -1:
					_drag_idx = event.index
					_set_angle_from_x(event.position.x)
			else:
				if event.index == _turn_idx:
					_turn_idx = -1
					holding = false
				if event.index == _drag_idx:
					_drag_idx = -1
		elif event is InputEventScreenDrag and event.index == _drag_idx:
			_set_angle_from_x(event.position.x)
	elif event is InputEventMouseMotion:
		_set_angle_from_x(event.position.x)


func _play(n: String, db := -4.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = ProcAudio.get_sound(n)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	if not active:
		return
	if not _mobile:
		holding = Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		pick_angle = clampf(pick_angle + (float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))) * 70.0 * delta, -90.0, 90.0)
	var dist := absf(pick_angle - sweet)
	var max_turn := 90.0 * clampf(1.0 - dist / 45.0, 0.0, 1.0)
	if dist < 4.0:
		max_turn = 90.0
	if holding:
		if turn < max_turn:
			turn = minf(turn + 55.0 * delta, max_turn)
			stress = maxf(stress - delta * 0.5, 0.0)
			var step := int(turn / 10.0)
			if step != _last_tick:
				_last_tick = step
				_play("click", -10.0)
		else:
			stress += delta * (0.9 if max_turn < 25.0 else 0.5)
			_creak_cd -= delta
			if _creak_cd <= 0.0:
				_creak_cd = 0.7
				_play("creak", -16.0)
				if _mobile:
					Input.vibrate_handheld(40)
		if turn >= 89.0:
			active = false
			_play("click", 0.0)
			finished.emit(true)
	else:
		turn = maxf(turn - 120.0 * delta, 0.0)
		stress = maxf(stress - delta, 0.0)
		_last_tick = int(turn / 10.0)
	if stress >= 1.0:
		picks -= 1
		_play("slam", -14.0)
		if picks <= 0:
			active = false
			finished.emit(false)
		else:
			_new_lock()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var c := size / 2.0 + Vector2(0, -20)
	var r := minf(size.x, size.y) * 0.28
	var warm := clampf(1.0 - absf(pick_angle - sweet) / 60.0, 0.0, 1.0)
	draw_arc(c, r + 18.0, 0.0, TAU, 64, Color(0.2 + warm * 0.7, 0.15, 0.15, 0.55), 5.0)
	draw_circle(c, r, Color(0.12, 0.1, 0.09))
	draw_arc(c, r, 0.0, TAU, 64, Color(0.55, 0.5, 0.4), 4.0)
	draw_set_transform(c, deg_to_rad(turn), Vector2.ONE)
	draw_circle(Vector2.ZERO, r * 0.72, Color(0.35, 0.3, 0.2))
	draw_rect(Rect2(-r * 0.06, -r * 0.35, r * 0.12, r * 0.5), Color.BLACK)
	draw_circle(Vector2(0, -r * 0.35), r * 0.1, Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dir := Vector2.UP.rotated(deg_to_rad(pick_angle))
	var jit := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * stress * 4.0
	draw_line(c + jit, c + dir * r * 1.05 + jit, Color(0.92, 0.92, 0.96), 4.0)
	var bar := Vector2(c.x - 120.0, c.y + r + 40.0)
	draw_rect(Rect2(bar, Vector2(240, 12)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(bar, Vector2(240.0 * stress, 12)), Color(0.85, 0.1, 0.1))
	for i in picks:
		var p0 := Vector2(c.x - 40.0 + i * 40.0, c.y + r + 70.0)
		draw_line(p0, p0 + Vector2(20, 22), Color(0.92, 0.92, 0.96), 3.0)
	if _mobile:
		draw_circle(_turn_pos(), 70.0, Color(1, 1, 1, 0.38 if holding else 0.18))
		draw_string(font, _turn_pos() + Vector2(-60, 10), "أدِر", HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color(0, 0, 0, 0.9))
