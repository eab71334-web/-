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
var chat_panel: PanelContainer
var chat_edit: LineEdit


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

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

	_mk(root, 0.5, -24, 28).text = "·"
	prompt = _mk(root, 0.8, 0, 22)
	dbg = _mk(root, 0.93, 0, 14)
	dbg.modulate = Color(1, 1, 1, 0.5)
	objective = _mk(root, 0.0, 12, 20)
	subtitle = _mk(root, 0.68, 0, 34)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.05, 0.05))

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
	Game.fade_requested.connect(_on_dead)
	Game.game_over.connect(func(): _show_end("انتهت اللعبة… قتلك الظل", true))
	Game.game_won.connect(func(): _show_end("نجوت! لكن الظل يتعلم… الليلة %d أصعب" % Game.night, true))


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
	end_label.text = text
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
		dbg.text = "x %.1f  z %.1f   step %d" % [lp.global_position.x, lp.global_position.z, Game.step] + "   " + Game.ai_status + "   " + Game.mind_status
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
