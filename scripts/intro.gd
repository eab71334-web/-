extends Cine
## Opening: 1976, the van at the end of the valley, Dr. Rana briefs you over the radio.


func _ready() -> void:
	_build_base()
	_add_skip(_finish)
	_run()


func _finish() -> void:
	if _done:
		return
	_done = true
	DisplayServer.tts_stop()
	Game.start_game(true)


func _run() -> void:
	var n := Game.player_name
	await _wait(1.2)
	await _say("١٩٧٦", 3.0, 70)
	await _say("وادي الصفصاف", 2.5, 44)
	sub.text = "الراديو • الدكتورة رنا"
	var lines := [
		"%s… هنا الدكتورة رنا. وصلتنا مكالمة من عائلة المنصوري." % n,
		"مزرعة معزولة في آخر الوادي. أبواب تُغلق وحدها، وتهويدة تُسمع عند الثالثة كل ليلة.",
		"الأطفال يتكلمون مع «سيدة» لا يراها أحد. الأب لا يصدّق… والأم لم تنم منذ أسبوع.",
		"ستدخل أنت: الكاميرا، جهاز التسجيل، والكشاف. كمال وأنا في الشاحنة نراقب الأجهزة.",
		"بطاريتك محدودة… فاستعملها بحكمة. ولا تثق بما تراه عيناك فقط.",
	]
	for l in lines:
		_voice(l, 1.2, 0.9)
		await _say(l, 1.8 + l.length() * 0.06, 30)
	sub.text = ""
	_sfx("hum", -6.0)
	await _say("عائلة من خمسة أشخاص…\nوبيت يتذكّر.", 4.0, 38)
	label.add_theme_color_override("font_color", Color(0.8, 0.08, 0.08))
	await _say("بيت الصفصاف", 3.5, 64)
	_finish()
