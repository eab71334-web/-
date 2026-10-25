extends Cine
## Story opening: 3:07 AM call -> arrive at the abandoned hospital -> pick the lock of door B-13 -> a voice says your name.

var lock: LockPick


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
	var clip := NewsClip.new()
	clip.lines = Game.NEWS_INTRO
	clip.ticker_text = Game.NEWS_TICKER
	add_child(clip)
	await clip.finished
	_flash(0.2)
	await _wait(1.0)
	_sfx("ring")
	await _say("٣:٠٧ فجراً", 3.2, 64)
	sub.text = "متصل مجهول"
	var calls := [
		"أستاذ %s؟ آسف على الاتصال في هذا الوقت." % n,
		"أنت مفتّح الأقفال الوحيد الذي لم يفشل أبداً… صحيح؟",
		"في مستشفى الرحمة القديم باب مغلق منذ سنة ١٩٨٧. الغرفة B-13.",
		"سأدفع ثلاثة أضعاف الأجر… لكن لا تتأخر.",
		"وإن سمعتَ أحداً ينادي باسمك… لا تجب.",
	]
	for l in calls:
		_voice(l, 0.5, 0.8)
		await _say(l, 1.8 + l.length() * 0.06)
	sub.text = ""
	_sfx("click")
	await _say("مستشفى الرحمة\nأُغلق عام ١٩٨٧", 4.0, 42)
	_sfx("creak", -6.0)

	label.text = ""
	sub.text = "افتح قفل الباب B-13"
	lock = LockPick.new()
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lock)
	move_child(lock, 3)
	var ok := false
	for attempt in 3:
		lock.reset()
		ok = await lock.finished
		if ok:
			break
		sub.text = "انكسرت الأدوات… حاول مجدداً"
		await _wait(1.5)
		sub.text = "افتح قفل الباب B-13"
	lock.queue_free()
	if not ok:
		sub.text = "…الباب ينفتح من الداخل"
		_sfx("creak")
		await _wait(2.5)
	sub.text = ""
	for i in 3:
		_sfx("click")
		await _wait(0.45)
	_sfx("creak")
	await _wait(2.2)
	_voice(n, 0.25, 0.55)
	_sfx("static", -6.0)
	await _say("%s…" % n, 3.0, 48)
	_sfx("slam")
	_flash(0.15)
	label.text = ""
	await _wait(1.6)
	label.add_theme_color_override("font_color", Color(0.8, 0.08, 0.08))
	await _say("التسلسل\nالظل القاتل", 3.5, 60)
	_finish()
