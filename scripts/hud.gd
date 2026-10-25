extends CanvasLayer
class_name Hud

const FX_SHADER := """
shader_type canvas_item;
uniform float threat = 0.0;
uniform float pulse = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV - 0.5;
	float vig = smoothstep(0.3, 0.9, length(uv * vec2(1.0, 0.8)));
	float g = hash(UV * vec2(1280.0, 720.0) + floor(TIME * 24.0));
	vec3 col = vec3(0.35, 0.0, 0.0) * threat * (0.4 + 0.6 * pulse);
	float a = vig * (0.5 + 0.45 * threat) + (g - 0.5) * 0.07 + threat * 0.08 * pulse;
	COLOR = vec4(col, clamp(a, 0.0, 0.95));
}
"""


var prompt: Label
var objective: Label
var subtitle: Label
var noise_bar: ProgressBar
var confront: PanelContainer
var confront_name: Label
var fade: ColorRect
var end_panel: PanelContainer
var end_label: Label
var restart_btn: Button
var _sub_t := 0.0
var fx_mat: ShaderMaterial
var dbg: Label
var chat_btn: Button
var inv_btn: Button
var bar_top: ColorRect
var bar_bot: ColorRect
var cctv_box: Control
var cctv_label: Label
var chat_panel: PanelContainer
var chat_edit: LineEdit
var note_panel: PanelContainer
var note_title: Label
var note_body: Label
var puzzle_open := false


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = UITheme.make()

	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = FX_SHADER
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = sh
	fx.material = fx_mat
	root.add_child(fx)

	chat_btn = Button.new()
	chat_btn.text = "تكلّم (T)"
	chat_btn.offset_left = 16
	chat_btn.offset_top = 64
	chat_btn.offset_right = 150
	chat_btn.offset_bottom = 108
	chat_btn.pressed.connect(_toggle_chat)
	root.add_child(chat_btn)
	inv_btn = Button.new()
	inv_btn.text = "الأغراض (I)"
	inv_btn.offset_left = 16
	inv_btn.offset_top = 116
	inv_btn.offset_right = 170
	inv_btn.offset_bottom = 160
	inv_btn.pressed.connect(_open_inventory)
	root.add_child(inv_btn)
	chat_panel = PanelContainer.new()
	chat_panel.anchor_left = 0.2
	chat_panel.anchor_right = 0.8
	chat_panel.anchor_top = 0.4
	chat_panel.anchor_bottom = 0.4
	chat_panel.offset_bottom = 60
	chat_panel.visible = false
	var hb := HBoxContainer.new()
	chat_panel.add_child(hb)
	chat_edit = LineEdit.new()
	chat_edit.placeholder_text = "قل شيئاً للظل… (اقترب منه أولاً)"
	chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_edit.text_submitted.connect(func(_t): _send_chat())
	hb.add_child(chat_edit)
	var sb := Button.new()
	sb.text = "إرسال"
	sb.pressed.connect(_send_chat)
	hb.add_child(sb)
	root.add_child(chat_panel)

	note_panel = PanelContainer.new()
	note_panel.anchor_left = 0.15
	note_panel.anchor_right = 0.85
	note_panel.anchor_top = 0.12
	note_panel.anchor_bottom = 0.88
	note_panel.visible = false
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 14)
	note_panel.add_child(nv)
	note_title = Label.new()
	note_title.add_theme_font_size_override("font_size", 28)
	note_title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.12))
	note_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(note_title)
	note_body = Label.new()
	note_body.add_theme_font_size_override("font_size", 26)
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nv.add_child(note_body)
	var nb := Button.new()
	nb.text = "إغلاق"
	nb.pressed.connect(_close_note)
	nv.add_child(nb)
	root.add_child(note_panel)

	cctv_box = Control.new()
	cctv_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	cctv_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cctv_box.visible = false
	var cv := ColorRect.new()
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csh := Shader.new()
	csh.code = NewsClip.VHS_SHADER
	var cmat := ShaderMaterial.new()
	cmat.shader = csh
	cv.material = cmat
	cctv_box.add_child(cv)
	cctv_label = Label.new()
	cctv_label.position = Vector2(40, 90)
	cctv_label.add_theme_font_size_override("font_size", 30)
	cctv_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	cctv_label.add_theme_constant_override("outline_size", 6)
	cctv_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cctv_box.add_child(cctv_label)
	root.add_child(cctv_box)
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.anchor_right = 1.0
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_top)
	bar_bot = ColorRect.new()
	bar_bot.color = Color.BLACK
	bar_bot.anchor_right = 1.0
	bar_bot.anchor_top = 1.0
	bar_bot.anchor_bottom = 1.0
	bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_bot)

	_mk(root, 0.5, -24, 28).text = "·"
	prompt = _mk(root, 0.8, 0, 22)
	dbg = _mk(root, 0.93, 0, 14)
	dbg.modulate = Color(1, 1, 1, 0.5)
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.45)
	strip.anchor_right = 1.0
	strip.offset_bottom = 56
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	objective = _mk(root, 0.0, 12, 20)
	subtitle = _mk(root, 0.68, 0, 34)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.05, 0.05))
	for l in [prompt, objective, subtitle]:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))

	noise_bar = ProgressBar.new()
	noise_bar.anchor_top = 1.0
	noise_bar.anchor_bottom = 1.0
	noise_bar.offset_left = 20
	noise_bar.offset_right = 220
	noise_bar.offset_top = -40
	noise_bar.offset_bottom = -22
	noise_bar.show_percentage = false
	noise_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(noise_bar)

	# name + health bar shown when the monster stands over your hiding spot
	confront = PanelContainer.new()
	confront.anchor_left = 0.35
	confront.anchor_right = 0.65
	confront.anchor_top = 0.55
	confront.anchor_bottom = 0.55
	confront.offset_bottom = 70
	confront.visible = false
	var vb := VBoxContainer.new()
	confront.add_child(vb)
	confront_name = Label.new()
	confront_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(confront_name)
	var hp := ProgressBar.new()
	hp.value = 100
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 14)
	vb.add_child(hp)
	root.add_child(confront)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.visible = false
	var eb := VBoxContainer.new()
	end_panel.add_child(eb)
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 30)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eb.add_child(end_label)
	restart_btn = Button.new()
	restart_btn.text = "حاول مجدداً"
	restart_btn.pressed.connect(func(): Game.restart())
	eb.add_child(restart_btn)
	root.add_child(end_panel)

	Game.objective_changed.connect(func(t): objective.text = t)
	Game.subtitle.connect(func(t):
		subtitle.text = t
		_sub_t = 2.5)
	Game.confrontation.connect(_on_confront)
	Game.note_opened.connect(_on_note)
	Game.item_added.connect(func(id: String): Game.subtitle.emit("حصلتَ على: " + Game.item_name(id)))
	Game.puzzle_requested.connect(_on_puzzle)
	Game.fade_requested.connect(_on_dead)
	Game.game_over.connect(func(): _show_end("انتهت اللعبة… قتلك الظل", true))


func _mk(root: Control, ay: float, off: float, size: int) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = ay
	l.anchor_bottom = ay
	l.offset_top = off
	l.offset_bottom = off + 44
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _on_confront(vid: int, on: bool) -> void:
	confront.visible = on and vid == Game.my_id()
	confront_name.text = Game.player_name


func _on_dead() -> void:
	create_tween().tween_property(fade, "color:a", 1.0, 1.0)
	_show_end("قتلك الظل…", false)


func _show_end(text: String, with_button: bool) -> void:
	end_label.text = text + "\n\n" + Game.case_text()
	restart_btn.text = "الليلة التالية" if Game.finished else "حاول مجدداً"
	end_panel.visible = true
	restart_btn.visible = with_button and (Game.solo or Game.is_host())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if with_button:
		fade.color.a = maxf(fade.color.a, 0.6)


func _process(delta: float) -> void:
	_sub_t -= delta
	fx_mat.set_shader_parameter("threat", Game.threat)
	fx_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * (4.0 + Game.threat * 8.0)))
	if _sub_t <= 0.0:
		subtitle.text = ""
	var lp = Game.local_player
	if lp != null and is_instance_valid(lp):
		dbg.text = "x %.1f  z %.1f   step %d" % [lp.global_position.x, lp.global_position.z, Game.step] + "   " + Game.ai_status + "   " + Game.mind_status + "   M:" + _mon()
	else:
		dbg.text = "NO PLAYER"
	if lp == null or not is_instance_valid(lp) or not lp.alive:
		prompt.text = ""
		return
	var it = lp.current_interactable
	if lp.hidden:
		prompt.text = "[E] اخرج من المخبأ"
	elif it != null and it.is_available():
		prompt.text = it.get_prompt()
	elif Game.near_note >= 0:
		prompt.text = "[E] اقرأ الوثيقة"
	elif Game.near_prompt != "":
		prompt.text = Game.near_prompt
	elif lp.in_hide_zone != null:
		if lp.posture == Player.Posture.CROUCH or lp.posture == Player.Posture.CRAWL:
			prompt.text = "[E] اختبئ"
		else:
			prompt.text = "انحنِ (C) أو ازحف (Z) ثم [E] للاختباء"
	else:
		prompt.text = ""
	noise_bar.value = clampf(lp.noise_level, 0.0, 1.0) * 100.0


func _toggle_chat() -> void:
	chat_panel.visible = not chat_panel.visible
	Game.typing = chat_panel.visible
	if chat_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		chat_edit.grab_focus()
	elif not Game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _send_chat() -> void:
	var t := chat_edit.text.strip_edges()
	chat_edit.text = ""
	if t != "":
		Game.say_to_monster(t.left(120))
	chat_panel.visible = false
	Game.typing = false
	if not Game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("talk") and not chat_edit.has_focus():
		_toggle_chat()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not chat_edit.has_focus():
		_open_inventory()
		get_viewport().set_input_as_handled()


func _mon() -> String:
	var m = get_parent().get_node_or_null("Monster")
	if m == null:
		return "NOT SPAWNED"
	return "%d @%.0f,%.0f" % [m.state, m.global_position.x, m.global_position.z]


func _on_note(i: int) -> void:
	note_title.text = Game.note_title(i)
	note_body.text = Game.note_body(i) + "\n\n(%d/%d)" % [Game.notes_found.size(), Game.NOTES.size()]
	note_body.visible_ratio = 0.0
	note_panel.visible = true
	Game.typing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	create_tween().tween_property(note_body, "visible_ratio", 1.0, 0.03 * note_body.text.length())


func _close_note() -> void:
	note_panel.visible = false
	Game.typing = false
	if not Game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Fade-in from black with a big title ("الليلة 1 — 3:07 فجراً").
func title_card(text: String, subtitle_text: String) -> void:
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var l := Label.new()
	l.text = text + "\n" + subtitle_text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 1.2)
	tw.tween_interval(1.8)
	tw.set_parallel(true)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_property(cover, "color:a", 0.0, 2.0)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)
	tw.tween_callback(cover.queue_free)


func _lock_ui(on: bool) -> void:
	puzzle_open = on
	Game.typing = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not Game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_puzzle(kind: String, station) -> void:
	if puzzle_open:
		return
	if kind == "phone":
		Util.play(self, "click")
		Game.fire("start_final", [Game.my_id()])
		return
	_lock_ui(true)
	if kind == "door":
		Game.fire("freeze_monster", [10.0])
		var q := DoorQTE.new()
		q.finished.connect(func(ok: bool):
			if is_instance_valid(q):
				q.queue_free()
			_lock_ui(false)
			if ok:
				Game.fire("complete_step", [Game.Step.EXIT])
			else:
				Game.fire("door_failed", [Game.my_id()]))
		add_child(q)
		return
	if kind == "tv":
		Game.fire("make_noise", [station.global_position, 0.5])      # the TV is loud
		var c := NewsClip.new()
		if Game.has_tape:
			c.lines = Game.NEWS_LINES
			c.ticker_text = Game.NEWS_TICKER
			c.whisper_name = Game.player_name
		else:
			c.lines = ["…لا توجد إشارة. ربما يلزم شريط."]
			c.ticker_text = "   لا توجد إشارة   "
		c.finished.connect(func(): _lock_ui(false))
		add_child(c)
		return
	var p := PuzzleUI.new()
	p.kind = kind
	p.station = station
	p.solved.connect(func():
		if is_instance_valid(p):
			p.queue_free()
		_lock_ui(false)
		if kind == "safe":
			Game.add_item("key_b13")
		if station.step_index >= 0:
			Game.fire("complete_step", [station.step_index]))
	p.closed.connect(func():
		if is_instance_valid(p):
			p.queue_free()
		_lock_ui(false))
	add_child(p)


## Cinematic letterbox bars (in-engine cut-scenes).
func bars(on: bool) -> void:
	create_tween().tween_property(bar_top, "anchor_bottom", 0.12 if on else 0.0, 0.8)
	create_tween().tween_property(bar_bot, "anchor_top", 0.88 if on else 1.0, 0.8)


## Security-camera / VHS look for a shot.
func cctv(on: bool, text := "") -> void:
	cctv_box.visible = on
	cctv_label.text = text


func _open_inventory() -> void:
	if puzzle_open:
		return
	_lock_ui(true)
	var ins := ItemInspect.new()
	ins.closed.connect(func():
		if is_instance_valid(ins):
			ins.queue_free()
		_lock_ui(false))
	add_child(ins)
