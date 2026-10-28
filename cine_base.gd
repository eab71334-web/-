extends Control
class_name Cine
## Shared helpers for the story cut-scenes (intro / endings): typewriter text, SFX, voice, flash, film FX.

var fx_mat: ShaderMaterial
var label: Label
var sub: Label
var flash: ColorRect
var _done := false


func _build_base() -> void:
	theme = UITheme.make()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	label = Label.new()
	label.anchor_left = 0.08
	label.anchor_right = 0.92
	label.anchor_top = 0.3
	label.anchor_bottom = 0.7
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	sub = Label.new()
	sub.anchor_left = 0.05
	sub.anchor_right = 0.95
	sub.anchor_top = 0.84
	sub.anchor_bottom = 0.84
	sub.offset_bottom = 40
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.1, 0.1))
	add_child(sub)
	var top := ColorRect.new()
	top.color = Color.BLACK
	top.anchor_right = 1.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var bot := ColorRect.new()
	bot.color = Color.BLACK
	bot.anchor_right = 1.0
	bot.anchor_top = 1.0
	bot.anchor_bottom = 1.0
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)
	create_tween().tween_property(top, "anchor_bottom", 0.11, 1.6)      # cinema letterbox closes in
	create_tween().tween_property(bot, "anchor_top", 0.89, 1.6)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = Hud.FX_SHADER
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = sh
	fx.material = fx_mat
	add_child(fx)
	fx_mat.set_shader_parameter("threat", 0.2)


func _add_skip(cb: Callable) -> void:
	var b := Button.new()
	b.text = "تخطي"
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -130
	b.offset_right = -20
	b.offset_top = 20
	b.offset_bottom = 64
	b.pressed.connect(cb)
	add_child(b)


func _process(_delta: float) -> void:
	if fx_mat != null:
		fx_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _say(text: String, secs: float, size := 34) -> void:
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.visible_ratio = 0.0
	if text != "":
		create_tween().tween_property(label, "visible_ratio", 1.0, minf(secs * 0.6, 0.06 * text.length()))
	await get_tree().create_timer(secs).timeout


func _sfx(n: String, db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = ProcAudio.get_sound(n)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _voice(text: String, pitch := 0.5, rate := 0.8) -> void:
	var v := DisplayServer.tts_get_voices_for_language("ar")
	if v.is_empty():
		v = DisplayServer.tts_get_voices_for_language("en")
	if v.is_empty():
		return
	DisplayServer.tts_speak(text, v[0], 80, pitch, rate, 0, true)


func _flash(dur: float) -> void:
	flash.color.a = 1.0
	create_tween().tween_property(flash, "color:a", 0.0, dur)
