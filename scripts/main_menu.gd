extends Control

var name_edit: LineEdit
var ip_edit: LineEdit
var mic_check: CheckBox
var status: Label
var start_btn: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	_label(box, "التسلسل: الظل القاتل", 40)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "اسمك (سيناديك به الوحش)"
	name_edit.text = Game.player_name if Game.player_name != "Player" else ""
	box.add_child(name_edit)
	mic_check = CheckBox.new()
	mic_check.text = "الوحش يسمع المايكروفون (معالجة محلية فقط)"
	mic_check.button_pressed = Game.use_mic
	box.add_child(mic_check)

	_button(box, "لعب فردي", _on_solo)
	_button(box, "استضافة لعب تعاوني (2-4)", _on_host)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "عنوان IP للمضيف"
	box.add_child(ip_edit)
	_button(box, "انضمام", _on_join)
	start_btn = _button(box, "ابدأ المطاردة", func(): Net.start_match())
	start_btn.visible = false
	status = _label(box, "", 18)
	_button(box, "خروج", func(): get_tree().quit())

	Net.player_list_changed.connect(_on_list)
	Net.connection_failed.connect(func(): status.text = "فشل الاتصال")


func _apply() -> void:
	var n := name_edit.text.strip_edges().left(20)
	Game.player_name = n if n != "" else "Player"
	Game.use_mic = mic_check.button_pressed


func _on_solo() -> void:
	_apply()
	Game.start_game(true)


func _on_host() -> void:
	_apply()
	if Net.host() == OK:
		start_btn.visible = true
		status.text = "بانتظار اللاعبين… (منفذ UDP %d)" % Net.PORT
	else:
		status.text = "تعذّرت الاستضافة"


func _on_join() -> void:
	_apply()
	if Net.join(ip_edit.text.strip_edges()) == OK:
		status.text = "جارٍ الاتصال…"
	else:
		status.text = "عنوان غير صالح"


func _on_list() -> void:
	status.text = "اللاعبون: " + ", ".join(Net.names.values())


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
