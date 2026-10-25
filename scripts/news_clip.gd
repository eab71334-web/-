extends Control
class_name NewsClip
## A 1987 TV news broadcast on a VHS tape: CRT/VHS shader, anchor, "عاجل" lower-third, scrolling ticker.
## Used by the intro and by the in-level TV. Set lines/ticker_text/whisper_name BEFORE add_child().

signal finished

const VHS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float tear = step(0.992, rnd(vec2(floor(TIME * 7.0), 1.0))) * 0.04 * sin(uv.y * 25.0 + TIME * 40.0);
	float wob = sin(uv.y * 90.0 + TIME * 8.0) * 0.0015;
	vec2 u = vec2(uv.x + wob + tear, uv.y);
	vec3 c;
	c.r = texture(screen_tex, u + vec2(0.004, 0.0)).r;
	c.g = texture(screen_tex, u).g;
	c.b = texture(screen_tex, u - vec2(0.004, 0.0)).b;
	float scan = 0.86 + 0.14 * sin(uv.y * 900.0);
	float n = rnd(uv * vec2(1920.0, 1080.0) + TIME);
	c = c * scan + (n - 0.5) * 0.14;
	float bar = smoothstep(0.0, 0.03, abs(fract(uv.y - TIME * 0.12) - 0.5) - 0.47);
	c += vec3(0.08) * (1.0 - bar);
	float vig = smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.0, 0.85)));
	c *= 1.0 - vig * 0.6;
	COLOR = vec4(c, 1.0);
}
"""

var lines: Array = []
var ticker_text := ""
var whisper_name := ""
var stage: Control
var lower_third: Label
var ticker: Label
var _glitch := false
var _t := 0.0
var _stopped := false


func _ready() -> void:
	theme = UITheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.draw.connect(_draw_stage)
	add_child(stage)

	var third := ColorRect.new()
	third.color = Color(0.55, 0.04, 0.04, 0.92)
	third.anchor_left = 0.0
	third.anchor_right = 1.0
	third.anchor_top = 0.68
	third.anchor_bottom = 0.84
	third.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(third)
	var tag := Label.new()
	tag.text = " عاجل "
	tag.add_theme_font_size_override("font_size", 30)
	tag.add_theme_color_override("font_color", Color.WHITE)
	tag.anchor_left = 0.01
	tag.anchor_top = 0.0
	tag.offset_right = 130
	tag.offset_bottom = 56
	third.add_child(tag)
	lower_third = Label.new()
	lower_third.anchor_left = 0.1
	lower_third.anchor_right = 0.99
	lower_third.anchor_top = 0.0
	lower_third.anchor_bottom = 1.0
	lower_third.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lower_third.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lower_third.add_theme_font_size_override("font_size", 26)
	lower_third.add_theme_color_override("font_color", Color.WHITE)
	third.add_child(lower_third)

	var strip := ColorRect.new()
	strip.color = Color(0.05, 0.05, 0.08, 0.95)
	strip.anchor_right = 1.0
	strip.anchor_top = 0.88
	strip.anchor_bottom = 0.96
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	ticker = Label.new()
	ticker.text = ticker_text
	ticker.add_theme_font_size_override("font_size", 24)
	ticker.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	ticker.position = Vector2(size.x, 8)
	strip.add_child(ticker)

	var stamp := Label.new()
	stamp.text = "PLAY ▶   12/03/1987   03:07"
	stamp.position = Vector2(30, 24)
	stamp.add_theme_font_size_override("font_size", 24)
	stamp.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	stamp.add_theme_constant_override("outline_size", 4)
	stamp.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(stamp)
	var logo := Label.new()
	logo.text = "قناة الأخبار ٢"
	logo.anchor_left = 1.0
	logo.anchor_right = 1.0
	logo.offset_left = -260
	logo.offset_top = 24
	logo.add_theme_font_size_override("font_size", 26)
	logo.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	add_child(logo)
	var skip := Button.new()
	skip.text = "تخطي"
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -130
	skip.offset_right = -20
	skip.offset_top = 70
	skip.offset_bottom = 114
	skip.pressed.connect(_stop)
	add_child(skip)

	var vhs := ColorRect.new()
	vhs.set_anchors_preset(Control.PRESET_FULL_RECT)
	vhs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VHS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vhs.material = mat
	add_child(vhs)
	_run()


func _process(delta: float) -> void:
	_t += delta
	ticker.position.x -= delta * 140.0
	if ticker.position.x < -ticker.size.x:
		ticker.position.x = size.x
	stage.queue_redraw()


func _draw_stage() -> void:
	var s := stage.size
	stage.draw_rect(Rect2(Vector2.ZERO, s), Color(0.09, 0.12, 0.2))
	stage.draw_rect(Rect2(0, 0, s.x, s.y * 0.1), Color(0.12, 0.16, 0.28))
	var cx := s.x * 0.5
	stage.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s.x * 0.15, s.y * 0.72), Vector2(cx - s.x * 0.09, s.y * 0.46),
		Vector2(cx + s.x * 0.09, s.y * 0.46), Vector2(cx + s.x * 0.15, s.y * 0.72)]), Color(0.12, 0.12, 0.17))
	stage.draw_circle(Vector2(cx, s.y * 0.33), s.y * 0.1, Color(0.55, 0.42, 0.38) if not _glitch else Color(0.12, 0.1, 0.1))
	if _glitch:
		for sx in [-1.0, 1.0]:
			stage.draw_circle(Vector2(cx + sx * s.y * 0.04, s.y * 0.32), s.y * 0.012, Color(1, 0.1, 0.1))
	stage.draw_rect(Rect2(0, s.y * 0.7, s.x, s.y * 0.3), Color(0.08, 0.06, 0.05))


func _stop() -> void:
	if _stopped:
		return
	_stopped = true
	DisplayServer.tts_stop()
	finished.emit()
	queue_free()


func _run() -> void:
	Util.play(self, "static", -6.0)
	await get_tree().create_timer(0.9).timeout
	for l in lines:
		if _stopped:
			return
		lower_third.text = l
		lower_third.visible_ratio = 0.0
		create_tween().tween_property(lower_third, "visible_ratio", 1.0, minf(0.045 * l.length(), 3.5))
		Util.speak(l, 0.8, 0.9)
		await get_tree().create_timer(1.6 + l.length() * 0.06).timeout
	if _stopped:
		return
	if whisper_name != "":
		_glitch = true
		Util.play(self, "static", 0.0)
		lower_third.text = "%s…" % whisper_name
		Util.speak(whisper_name, 0.2, 0.5)
		await get_tree().create_timer(2.8).timeout
		_glitch = false
	Util.play(self, "click")
	_stop()
