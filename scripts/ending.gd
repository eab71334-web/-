extends Cine
## Two endings. Normal: you escape but something keeps whispering. True (all 5 documents found):
## your own phone rings with YOUR name and YOUR voice repeating the opening call -> the night loops.


func _ready() -> void:
	_build_base()
	_run()


func _run() -> void:
	var n := Game.player_name
	await _wait(0.8)
	_sfx("musicbox", -8.0)
	await _say("طلع الفجر على مزرعة الصفصاف.", 3.5, 40)
	await _say("توقّفت التهويدة. وصمت البيت للمرة الأولى منذ خمسين سنة.", 4.0, 34)
	await _say("حليمة جلست قرب النافذة… وابتسمت.", 3.5, 34)
	if Game.ending_kind == "true":
		sub.text = "في الشاحنة…"
		await _say("أعاد كمال تشغيل شريط المسجّل.\nتهويدة بصوتين: امرأة… وطفلة.", 4.5, 32)
		_voice("شكراً…", 1.6, 0.6)
		await _say("ثم همسة صغيرة:  «شكراً… %s»" % n, 4.0, 36)
		sub.text = ""
	else:
		await _say("لكن في البيت أسراراً لم تُقرأ بعد…", 3.5, 32)
		sub.text = "اجمع الوثائق الثماني لتعرف القصة كاملة"
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
