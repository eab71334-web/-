extends Control
## Two-column menu that uses the whole screen: left = profile + solo, right = LAN co-op.

var name_edit: LineEdit
var ip_edit: LineEdit
var mic_check: CheckBox
var key_edit: LineEdit
var status: Label
var start_btn: Button
var games_box: VBoxContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	margin.add_child(cols)
	var left := _column(cols)
	var right := _column(cols)

	# ---- left: profile + solo
	_label(left, "التسلسل: الظل القاتل", 38)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "اسمك (سيناديك به الوحش)"
	name_edit.text = Game.player_name if Game.player_name != "Player" else ""
	left.add_child(name_edit)
	mic_check = CheckBox.new()
	mic_check.text = "الوحش يسمع المايكروفون (معالجة محلية فقط)"
	mic_check.button_pressed = Game.use_mic
	left.add_child(mic_check)
	key_edit = LineEdit.new()
	key_edit.secret = true
	key_edit.placeholder_text = "مفتاح Claude API (اختياري)"
	key_edit.text = Game.ai_key
	left.add_child(key_edit)
	var note := _label(left, "بدون مفتاح يعمل الذكاء الداخلي (بدون إنترنت). مع المفتاح: اسمك وملخص اللعب يُرسلان إلى Anthropic، والصوت لا يُرسل أبداً.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(left, "لعب فردي", _on_solo)
	_button(left, "خروج", func(): get_tree().quit())

	# ---- right: LAN
	_label(right, "اللعب عبر الشبكة المحلية (LAN)", 24)
	_button(right, "استضافة لعبة (2-4 لاعبين)", _on_host)
	status = _label(right, "", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_btn = _button(right, "ابدأ المطاردة", func(): Net.start_match())
	start_btn.visible = false
	_label(right, "ألعاب قريبة على نفس الواي فاي:", 16)
	games_box = VBoxContainer.new()
	games_box.custom_minimum_size = Vector2(0, 90)
	right.add_child(games_box)
	_label(right, "أو اكتب عنوان المضيف يدوياً:", 14)
	ip_edit = LineEdit.new()
	ip_edit.text = "192.168."
	right.add_child(ip_edit)
	_button(right, "انضمام", func(): _join_ip(ip_edit.text.strip_edges()))

	Net.player_list_changed.connect(_on_list)
	Net.games_changed.connect(_refresh_games)
	Net.connection_failed.connect(_on_failed)
	Net.start_listen()
	_refresh_games()


func _exit_tree() -> void:
	Net.stop_listen()


func _apply() -> void:
	var n := name_edit.text.strip_edges().left(20)
	Game.player_name = n if n != "" else "Player"
	Game.use_mic = mic_check.button_pressed
	Game.ai_key = key_edit.text.strip_edges()
	Game.save_settings()


func _on_solo() -> void:
	_apply()
	Game.start_game(true)


func _on_host() -> void:
	_apply()
	Net.stop_listen()
	if Net.host() == OK:
		Net.start_broadcast()
		start_btn.visible = true
		var ips := Net.local_ips()
		status.text = "أنت المضيف. عنوانك: %s\\nاللاعبون على نفس الشبكة سيرون لعبتك تلقائياً. (UDP %d و %d)" % [
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


func _column(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	parent.add_child(v)
	return v


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
