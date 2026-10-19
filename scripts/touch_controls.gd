extends CanvasLayer
class_name TouchControls
## On-screen controls for phones: floating joystick (left), look-drag (right),
## buttons: E (hold) / RUN (hold) / C / Z / F. Handles raw multi-touch so
## moving and looking work at the same time.

const JOY_R := 110.0
const BTN_R := 52.0
const LOOK_SENS := 1.5

var canvas: Control
var joy_idx := -1
var joy_base := Vector2.ZERO
var joy_center := Vector2.ZERO
var joy_vec := Vector2.ZERO
var look_idx := -1
var btn_idx := {}      # touch index -> button dictionary
var buttons: Array = []
var _size := Vector2(1280, 720)


func _ready() -> void:
	layer = 9
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_paint)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	_size = get_viewport().get_visible_rect().size
	joy_base = Vector2(190, _size.y - 190)
	if joy_idx == -1:
		joy_center = joy_base
	buttons = [
		{"a": "interact", "t": "E", "p": Vector2(_size.x - 110, _size.y - 170), "hold": true, "down": false},
		{"a": "sprint", "t": "RUN", "p": Vector2(_size.x - 250, _size.y - 100), "hold": true, "down": false},
		{"a": "crouch", "t": "C", "p": Vector2(_size.x - 250, _size.y - 235), "hold": false, "down": false},
		{"a": "crawl", "t": "Z", "p": Vector2(_size.x - 110, _size.y - 310), "hold": false, "down": false},
		{"a": "flashlight", "t": "F", "p": Vector2(_size.x - 90, 90), "hold": false, "down": false},
	]
	canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position, event.relative)


func _down(i: int, pos: Vector2) -> void:
	for b in buttons:
		if pos.distance_to(b["p"]) <= BTN_R + 10.0:
			btn_idx[i] = b
			b["down"] = true
			_act(b["a"], true)
			if not b["hold"]:
				_act(b["a"], false)
			canvas.queue_redraw()
			return
	if joy_idx == -1 and pos.x < _size.x * 0.4 and pos.y > _size.y * 0.35:
		joy_idx = i
		joy_center = pos
		joy_vec = Vector2.ZERO
	elif look_idx == -1:
		look_idx = i
	canvas.queue_redraw()


func _up(i: int) -> void:
	if btn_idx.has(i):
		var b: Dictionary = btn_idx[i]
		if b["hold"]:
			_act(b["a"], false)
		b["down"] = false
		btn_idx.erase(i)
	elif i == joy_idx:
		joy_idx = -1
		joy_vec = Vector2.ZERO
		joy_center = joy_base
		_apply_move()
	elif i == look_idx:
		look_idx = -1
	canvas.queue_redraw()


func _drag(i: int, pos: Vector2, rel: Vector2) -> void:
	if i == joy_idx:
		joy_vec = ((pos - joy_center) / JOY_R).limit_length(1.0)
		_apply_move()
		canvas.queue_redraw()
	elif i == look_idx:
		var lp = Game.local_player
		if lp != null and is_instance_valid(lp):
			lp.apply_look(rel * LOOK_SENS)


func _apply_move() -> void:
	_axis("move_right", joy_vec.x)
	_axis("move_left", -joy_vec.x)
	_axis("move_back", joy_vec.y)
	_axis("move_forward", -joy_vec.y)


func _axis(action: String, v: float) -> void:
	if v > 0.15:
		_act(action, true, v)
	else:
		_act(action, false)


func _act(action: String, pressed: bool, strength := 1.0) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = strength
	Input.parse_input_event(e)


func _paint() -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_arc(joy_center, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
	canvas.draw_circle(joy_center + joy_vec * JOY_R * 0.6, 40.0, Color(1, 1, 1, 0.3))
	for b in buttons:
		var a := 0.55 if b["down"] else 0.25
		canvas.draw_circle(b["p"], BTN_R, Color(1, 1, 1, a))
		canvas.draw_string(font, b["p"] + Vector2(-30, 8), b["t"], HORIZONTAL_ALIGNMENT_CENTER, 60, 24, Color(0, 0, 0, 0.9))
