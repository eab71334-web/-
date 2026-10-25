extends Control
class_name PuzzleUI
## Two real puzzles. "fuse": insert fuses in the order written in a document. "keypad": 4-digit code
## that you can only learn by finding the VHS tape and watching the TV broadcast. Mistakes make NOISE.

signal solved
signal closed

const FUSE_COLORS := [Color(0.9, 0.15, 0.15), Color(0.2, 0.4, 0.95), Color(0.2, 0.8, 0.3), Color(0.95, 0.8, 0.15)]
const FUSE_NAMES := ["أحمر", "أزرق", "أخضر", "أصفر"]

var kind := "fuse"
var station: Node3D = null
var status: Label
var disp: Label
var leds: Array = []
var _seq: Array = []
var _code := ""
var _wrong := 0
var _lock_until := 0
var slider: HSlider
var freq_label: Label
var hiss: AudioStreamPlayer
var _tuned_t := 0.0
var _speaking := false
var _msg_t := 0.0
var _noise_t := 0.0
var _done := false
var dials := [0, 0, 0]
var dial_labels: Array = []


func _ready() -> void:
	theme = UITheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.25
	panel.anchor_right = 0.75
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = {"fuse": "لوحة المصاهر", "keypad": "لوحة رمز الطوارئ", "radio": "الراديو", "safe": "خزنة الدكتور سالم"}.get(kind, "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.12))
	v.add_child(title)
	if kind == "fuse":
		_build_fuse(v)
	elif kind == "radio":
		_build_radio(v)
	elif kind == "safe":
		_build_safe(v)
	else:
		_build_keypad(v)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): closed.emit())
	v.add_child(close)


func _desc(parent: Node, t: String) -> void:
	var d := Label.new()
	d.text = t
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(d)


func _noise(l: float) -> void:
	if station != null and is_instance_valid(station):
		Game.fire("make_noise", [station.global_position, l])


# ------------------------------------------------------------------ fuse box
func _build_fuse(v: VBoxContainer) -> void:
	_desc(v, "ركّب المصاهر الثلاثة بالترتيب الصحيح (ترتيبه مكتوب في وثيقة في القاعة). الخطأ يُحدث ماساً كهربائياً وصوتاً عالياً يسمعه الظل.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for i in Game.FUSE_ORDER.size():
		var led := ColorRect.new()
		led.custom_minimum_size = Vector2(36, 36)
		led.color = Color(0.15, 0.15, 0.15)
		row.add_child(led)
		leds.append(led)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(btns)
	for i in 4:
		var b := Button.new()
		b.text = FUSE_NAMES[i]
		b.custom_minimum_size = Vector2(0, 90)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = FUSE_COLORS[i].darkened(0.35)
		sb.set_corner_radius_all(8)
		var sh := StyleBoxFlat.new()
		sh.bg_color = FUSE_COLORS[i]
		sh.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(_fuse.bind(i))
		btns.add_child(b)


func _fuse(i: int) -> void:
	_seq.append(i)
	var idx := _seq.size() - 1
	if i != Game.FUSE_ORDER[idx]:
		Util.play(self, "spark")
		_noise(1.0)
		status.text = "ماس كهربائي! الصوت سيُسمع… ابدأ من جديد."
		_seq.clear()
		for l in leds:
			l.color = Color(0.15, 0.15, 0.15)
		return
	Util.play(self, "click")
	leds[idx].color = Color(0.2, 0.9, 0.3)
	status.text = "صحيح…"
	if _seq.size() == Game.FUSE_ORDER.size():
		status.text = "عاد التيار."
		solved.emit()


# ------------------------------------------------------------------ keypad
func _build_keypad(v: VBoxContainer) -> void:
	_desc(v, "أدخل الرمز المكوّن من أربع خانات. (رقم المريض ثم رقم غرفته — شاهد شريط التلفاز). الخطأ يُحدث إنذاراً يسمعه الظل.")
	disp = Label.new()
	disp.text = "----"
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disp.add_theme_font_size_override("font_size", 56)
	disp.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	v.add_child(disp)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✓"]:
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(_key.bind(k))
		grid.add_child(b)


func _input(event: InputEvent) -> void:
	if kind != "keypad" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.unicode >= 48 and event.unicode <= 57:
		_key(char(event.unicode))
	elif event.keycode == KEY_BACKSPACE:
		_key("⌫")
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_key("✓")


func _key(k: String) -> void:
	if Time.get_ticks_msec() < _lock_until:
		return
	if k == "⌫":
		_code = _code.left(maxi(_code.length() - 1, 0))
	elif k == "✓":
		_submit()
		return
	elif _code.length() < 4:
		_code += k
	Util.play(self, "beep", -6.0)
	disp.text = _code + "-".repeat(4 - _code.length())


func _submit() -> void:
	if _code == Game.KEYPAD_CODE:
		status.text = "تم فتح القفل."
		Util.play(self, "click")
		solved.emit()
		return
	_wrong += 1
	Util.play(self, "buzz")
	_noise(0.9)
	_code = ""
	disp.text = "----"
	if _wrong >= 3:
		_wrong = 0
		_lock_until = Time.get_ticks_msec() + 15000
		_noise(1.0)
		status.text = "القفل مغلق 15 ثانية… الإنذار يعمل!"
	else:
		status.text = "رمز خاطئ."


func _exit_tree() -> void:
	if kind == "radio":
		DisplayServer.tts_stop()


# ------------------------------------------------------------------ radio (tune to the hidden frequency)
func _build_radio(v: VBoxContainer) -> void:
	_desc(v, "اضبط التردد حتى يصفو الصوت. (التردد مكتوب في مكان لا يُرى إلا بضوء الكشاف.) الراديو عالٍ… والظل يسمع.")
	freq_label = Label.new()
	freq_label.text = "90.0 MHz"
	freq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	freq_label.add_theme_font_size_override("font_size", 52)
	freq_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	v.add_child(freq_label)
	slider = HSlider.new()
	slider.min_value = 88.0
	slider.max_value = 108.0
	slider.step = 0.1
	slider.value = 90.0
	slider.custom_minimum_size = Vector2(0, 60)
	slider.value_changed.connect(func(f: float): freq_label.text = "%.1f MHz" % f)
	v.add_child(slider)
	hiss = AudioStreamPlayer.new()
	hiss.stream = ProcAudio.get_sound("hiss")
	hiss.volume_db = -8.0
	add_child(hiss)
	hiss.play()


func _process(delta: float) -> void:
	if kind != "radio" or slider == null or _done:
		return
	var d := absf(slider.value - Game.RADIO_FREQ)
	hiss.volume_db = lerpf(-36.0, -8.0, clampf(d / 4.0, 0.0, 1.0))
	_noise_t += delta
	if _noise_t > 5.0:
		_noise_t = 0.0
		_noise(0.4)
	if d < 0.15:
		_tuned_t += delta
		if _tuned_t > 0.8 and not _speaking:
			_speaking = true
			_msg_t = 0.0
			status.text = Game.RADIO_MSG
			Util.speak(Game.RADIO_MSG, 0.6, 0.85)
		if _speaking:
			_msg_t += delta
			if _msg_t > 2.0 + Game.RADIO_MSG.length() * 0.065:
				_done = true
				solved.emit()
	else:
		_tuned_t = 0.0
		if _speaking:
			DisplayServer.tts_stop()
			_speaking = false
		status.text = "تشويش…" if d > 1.5 else "…الإشارة تقترب"


# ------------------------------------------------------------------ dial safe (RE2-style combination)
func _build_safe(v: VBoxContainer) -> void:
	_desc(v, "أدِر الأقراص الثلاثة إلى تاريخ اليوم الذي أُغلق فيه الباب: اليوم، ثم الشهر، ثم السنة (آخر رقمين). تلميح: الوثائق والشريط يذكرانه.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for i in 3:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		row.add_child(col)
		var up10 := Button.new()
		up10.text = "▲▲"
		up10.pressed.connect(_dial.bind(i, 10))
		col.add_child(up10)
		var up := Button.new()
		up.text = "▲"
		up.pressed.connect(_dial.bind(i, 1))
		col.add_child(up)
		var l := Label.new()
		l.text = "00"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 56)
		l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
		col.add_child(l)
		dial_labels.append(l)
		var dn := Button.new()
		dn.text = "▼"
		dn.pressed.connect(_dial.bind(i, -1))
		col.add_child(dn)
		var dn10 := Button.new()
		dn10.text = "▼▼"
		dn10.pressed.connect(_dial.bind(i, -10))
		col.add_child(dn10)
	var open := Button.new()
	open.text = "فتح الخزنة"
	open.pressed.connect(_try_safe)
	v.add_child(open)


func _dial(i: int, d: int) -> void:
	dials[i] = posmod(int(dials[i]) + d, 100)
	dial_labels[i].text = "%02d" % dials[i]
	Util.play(self, "click", -8.0)


func _try_safe() -> void:
	if dials == Game.SAFE_CODE:
		status.text = "…انفتحت الخزنة."
		Util.play(self, "click")
		solved.emit()
	else:
		Util.play(self, "buzz")
		_noise(0.8)
		status.text = "لم تنفتح. التاريخ خاطئ."
