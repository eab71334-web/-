extends Control
## Cinematic menu: flat 2D silhouette + film-grain shader (no 3D viewport: safer on iOS).

var name_edit: LineEdit
var ip_edit: LineEdit
var mic_check: CheckBox
var key_edit: LineEdit
var url_edit: LineEdit
var model_edit: LineEdit
var status: Label
var start_btn: Button
var games_box: VBoxContainer
var panel_lan: PanelContainer
var panel_set: PanelContainer
var title: Label
var bg: Control
var fx_mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	theme = UITheme.make()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_bg()
	_build_fx()
	_build_ui()
	var drone := AudioStreamPlayer.new()
	drone.stream = ProcAudio.get_sound("drone")
	drone.volume_db = -14.0
	add_child(drone)
	drone.play()
	Net.player_list_changed.connect(_on_list)
	Net.games_changed.connect(_refresh_games)
	Net.connection_failed.connect(_on_failed)
	Net.start_listen()
	_refresh_games()


func _exit_tree() -> void:
	Net.stop_listen()


# ------------------------------------------------------------------ background (2D)
func _build_bg() -> void:
	bg = Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_bg)
	add_child(bg)


## A flat 2D silhouette of the woman in the gown (safe on every GPU / driver).
func _draw_bg() -> void:
	var s := bg.size
	bg.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.0, 0.0))
	bg.draw_rect(Rect2(0.0, s.y * 0.72, s.x, s.y * 0.28), Color(0.05, 0.03, 0.03))
	var cx := s.x * 0.72
	var base := s.y * 0.9
	var h := s.y * 0.62
	var pulse := 0.5 + 0.5 * sin(_t * 1.6)
	bg.draw_circle(Vector2(cx, base - h * 0.55), h * 0.55, Color(0.25, 0.0, 0.0, 0.1 + 0.06 * pulse))
	bg.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - h * 0.22, base), Vector2(cx - h * 0.06, base - h * 0.72),
		Vector2(cx + h * 0.06, base - h * 0.72), Vector2(cx + h * 0.22, base)]), Color(0.5, 0.5, 0.54, 0.35))
	bg.draw_rect(Rect2(cx - h * 0.075, base - h * 0.95, h * 0.15, h * 0.42), Color(0.01, 0.01, 0.02, 0.9))
	bg.draw_circle(Vector2(cx, base - h * 0.85), h * 0.065, Color(0.6, 0.62, 0.65, 0.5))
	for sx in [-1.0, 1.0]:
		bg.draw_circle(Vector2(cx + sx * h * 0.025, base - h * 0.86), h * 0.01, Color(0.0, 0.0, 0.0, 0.9))


func _build_fx() -> void:
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = Hud.FX_SHADER
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = sh
	fx.material = fx_mat
	add_child(fx)
	fx_mat.set_shader_parameter("threat", 0.25)


# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	var col := VBoxContainer.new()
	col.anchor_left = 0.04
	col.anchor_right = 0.42
	col.anchor_top = 0.06
	col.anchor_bottom = 0.96
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	title = Label.new()
	title.text = "بيت الصفصاف"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0))
	col.add_child(title)
	var sub := _label(col, "تحقيق في الظواهر الخفيّة  —  ١٩٧٦", 26)
	sub.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "اسمك (سيناديك به الظل)"
	name_edit.text = Game.player_name if Game.player_name != "Player" else ""
	col.add_child(name_edit)
	if Game.has_saved_run():
		_button(col, "متابعة", _on_continue)
	_button(col, "ابدأ التحقيق (جديد)", _on_story)
	_button(col, "لعب سريع (بدون مقدمة)", _on_solo)
	_button(col, "اللعب الجماعي LAN", func(): _toggle(panel_lan))
	_button(col, "الإعدادات", func(): _toggle(panel_set))
	_button(col, "خروج", func(): get_tree().quit())
	_label(col, "الليلة %d   •   الوثائق %d/%d" % [Game.night, Game.notes_found.size(), Game.NOTES.size()], 18)
	col.modulate.a = 0.0
	create_tween().tween_property(col, "modulate:a", 1.0, 2.0)

	panel_set = _panel()
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	panel_set.add_child(sv)
	_label(sv, "الإعدادات", 26)
	mic_check = CheckBox.new()
	mic_check.text = "الوحش يسمع المايكروفون (معالجة محلية فقط)"
	mic_check.button_pressed = Game.use_mic
	sv.add_child(mic_check)
	key_edit = LineEdit.new()
	key_edit.secret = true
	key_edit.placeholder_text = "مفتاح Claude API (اختياري)"
	key_edit.text = Game.ai_key
	sv.add_child(key_edit)
	url_edit = LineEdit.new()
	url_edit.placeholder_text = "خادم ذكاء محلي (Ollama) مثل http://192.168.1.5:11434"
	url_edit.text = Game.ai_url.replace("/v1/chat/completions", "") if Game.ai_url != Game.AI_URL_DEFAULT else ""
	sv.add_child(url_edit)
	model_edit = LineEdit.new()
	model_edit.text = Game.ai_model
	sv.add_child(model_edit)
	var note := _label(sv, "بدون مفتاح أو خادم يعمل الذكاء الداخلي (بدون إنترنت) ويتعلم عنك. مع المفتاح: اسمك وملخص اللعب يُرسلان لـ Anthropic. الصوت لا يُرسل أبداً.", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(sv, "حفظ", func():
		_apply()
		panel_set.visible = false)

	panel_lan = _panel()
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	panel_lan.add_child(lv)
	_label(lv, "اللعب عبر الشبكة المحلية (LAN)", 26)
	_button(lv, "استضافة لعبة (2-4 لاعبين)", _on_host)
	status = _label(lv, "", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_btn = _button(lv, "ابدأ المطاردة", func(): Net.start_match())
	start_btn.visible = false
	_label(lv, "ألعاب قريبة على نفس الواي فاي:", 16)
	games_box = VBoxContainer.new()
	games_box.custom_minimum_size = Vector2(0, 80)
	lv.add_child(games_box)
	ip_edit = LineEdit.new()
	ip_edit.text = "192.168."
	lv.add_child(ip_edit)
	_button(lv, "انضمام بالعنوان", func(): _join_ip(ip_edit.text.strip_edges()))


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.97
	p.anchor_top = 0.08
	p.anchor_bottom = 0.08
	p.visible = false
	add_child(p)
	return p


func _toggle(p: PanelContainer) -> void:
	var was := p.visible
	panel_lan.visible = false
	panel_set.visible = false
	p.visible = not was


func _process(delta: float) -> void:
	_t += delta
	bg.queue_redraw()
	fx_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_t * 2.2))
	if randf() < 0.012:
		title.modulate = Color(1.0, randf_range(0.5, 1.0), randf_range(0.5, 1.0), 1.0)
	else:
		title.modulate = title.modulate.lerp(Color.WHITE, minf(delta * 6.0, 1.0))


# ------------------------------------------------------------------ actions
func _apply() -> void:
	var n := name_edit.text.strip_edges().left(20)
	Game.player_name = n if n != "" else "Player"
	if mic_check != null:
		Game.use_mic = mic_check.button_pressed
		Game.ai_key = key_edit.text.strip_edges()
		var u := url_edit.text.strip_edges().rstrip("/")
		Game.ai_url = Game.AI_URL_DEFAULT if u == "" else (u if u.contains("/v1/") else u + "/v1/chat/completions")
		var mdl := model_edit.text.strip_edges()
		Game.ai_model = mdl if mdl != "" else "qwen2.5:3b"
	Game.save_settings()


func _on_continue() -> void:
	_apply()
	Game.load_run()
	Game.start_game(true)


func _on_story() -> void:
	_apply()
	Game.new_run()
	Game.start_story()


func _on_solo() -> void:
	_apply()
	Game.new_run()
	Game.start_game(true)


func _on_host() -> void:
	_apply()
	Net.stop_listen()
	if Net.host() == OK:
		Net.start_broadcast()
		start_btn.visible = true
		var ips := Net.local_ips()
		status.text = "أنت المضيف. عنوانك: %s\nاللاعبون على نفس الشبكة سيرون لعبتك تلقائياً. (UDP %d و %d)" % [
			", ".join(ips) if not ips.is_empty() else "غير معروف", Net.PORT, Net.DISCOVERY_PORT]
	else:
		status.text = "تعذّرت الاستضافة"
		Net.start_listen()


func _join_ip(ip: String) -> void:
	_apply()
	Net.stop_listen()
	if Net.join(ip) == OK:
		status.text = "جارٍ الاتصال بـ %s…" % ip
	else:
		status.text = "عنوان غير صالح"
		Net.start_listen()


func _on_failed() -> void:
	status.text = "فشل الاتصال — تأكد أنكما على نفس الشبكة"
	Net.start_listen()


func _on_list() -> void:
	if not Net.names.is_empty():
		status.text = "اللاعبون: " + ", ".join(Net.names.values())


func _refresh_games() -> void:
	for c in games_box.get_children():
		c.queue_free()
	if Net.found.is_empty():
		var l := Label.new()
		l.text = "…لا توجد ألعاب (اطلب من صديقك الاستضافة)"
		games_box.add_child(l)
		return
	for ip in Net.found:
		var g: Dictionary = Net.found[ip]
		_button(games_box, "%s   (%d/%d)   %s" % [g["host"], g["players"], g["max"], ip], _join_ip.bind(ip))


func _label(parent: Node, t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _button(parent: Node, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
