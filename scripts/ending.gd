extends Cine
## Two endings. Normal: you escape but something keeps whispering. True (all 5 documents found):
## your own phone rings with YOUR name and YOUR voice repeating the opening call -> the night loops.


func _ready() -> void:
	_build_base()
	_run()


func _run() -> void:
	var n := Game.player_name
	await _wait(0.8)
	_sfx("slam")
	_flash(0.1)
	await _say("أغلقتَ الباب خلفك…", 3.0, 44)
	if Game.ending_kind == "true":
		await _wait(1.2)
		_sfx("ring")
		sub.text = "المتصل: %s" % n
		await _say("", 2.6)
		var calls := [
			"أستاذ %s؟ آسف على الاتصال في هذا الوقت." % n,
			"في مستشفى الرحمة القديم باب مغلق منذ سنة ١٩٨٧…",
			"وإن سمعتَ أحداً ينادي باسمك… لا تجب.",
		]
		for l in calls:
			_voice(l, 1.0, 0.9)
			await _say(l, 1.8 + l.length() * 0.06, 32)
		sub.text = ""
		_sfx("static", -6.0)
		await _say("…هذا صوتك.", 3.0, 46)
		await _say("الليلة %d… التسلسل لا ينتهي." % Game.night, 4.0, 40)
	else:
		await _say("لكن شيئاً ما بقي يهمس باسمك…", 3.5, 38)
		sub.text = "اجمع كل الوثائق الخمس لتعرف الحقيقة"
		await _wait(2.2)
		sub.text = ""
	_show_card()


func _show_card() -> void:
	label.text = ""
	var panel := PanelContainer.new()
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.15
	panel.anchor_bottom = 0.85
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var l := Label.new()
	l.text = Game.case_text()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 26)
	v.add_child(l)
	var b1 := Button.new()
	b1.text = "الليلة التالية"
	b1.pressed.connect(func(): Game.restart())
	v.add_child(b1)
	var b2 := Button.new()
	b2.text = "القائمة الرئيسية"
	b2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	v.add_child(b2)
	add_child(panel)
