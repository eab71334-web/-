extends Node
## Global state: input map, objectives, noise events, death/win flow, name whispers.

signal objective_changed(text: String)
signal subtitle(text: String)
signal noise_made(pos: Vector3, loudness: float)
signal confrontation(victim_id: int, on: bool)
signal fade_requested
signal game_over
signal game_won
signal note_opened(idx: int)
signal puzzle_requested(kind: String, station: Node)
signal ritual_requested(pid: int)
signal evidence_added(id: String)
signal evp_added(id: String)
signal flag_set(k: String)
signal photo_taken
signal monster_freeze(secs: float)
signal door_failed_sig(pid: int)
signal speech_heard(pid: int, dur: float, peak: float, text: String)
signal item_added(id: String)
signal door_opened

const STARE_TIME := 7.0   # the "7 second rule"
enum Step { MEET, POWER, EVIDENCE, VOICES, PAGES, SAFE, MUSICBOX, DIG, RITUAL, ESCAPED }
const OBJECTIVES := [
	"قابل أفراد العائلة في غرفة المعيشة واسمع قصصهم (٣ على الأقل)",
	"الكهرباء مقطوعة: انزل إلى القبو من باب المطبخ وأصلح القاطع (ترتيبه مكتوب في ورقة بجانبه)",
	"صوّر ٣ أدلة خفية بالكاميرا (R): ما لا تراه العين تراه العدسة — ثم E للتصوير",
	"سجّل صوتين بجهاز التسجيل (V) في أماكن الظاهرة: غرفة الأطفال، العلّية، القبو",
	"اجمع صفحات رسم مريم الأربع المتناثرة في البيت (الأغراض: I)",
	"افتح خزنة غرفة الوالدين بتاريخ وفاة الطفلة: اليوم، الشهر، السنة (من الصفحات)",
	"اصعد إلى العلّية وخذ علبة الموسيقى من المهد",
	"اذهب إلى الحظيرة وخذ المجرفة، ثم احفر عند شجرة الصفصاف في الحديقة",
	"عد إلى العلّية: ضع حذاء ريما في المهد، شغّل العلبة… ثم لا تتحرك ولا تتكلم",
	"انتهت الليلة.",
]
const CHAPTERS := {
	0: ["الفصل الأول", "الوصول"],
	1: ["الفصل الثاني", "القبو"],
	2: ["الفصل الثالث", "ما تراه العدسة"],
	4: ["الفصل الرابع", "صفحات مريم"],
	6: ["الفصل الخامس", "العلّية"],
	7: ["الفصل السادس", "الحديقة"],
	8: ["الفصل السابع", "التهويدة"],
}
const ITEMS := {
	"key_attic": {"name": "مفتاح العلّية", "desc": "مفتاح حديدي صدئ. على حلقته خيط أحمر صغير، كأن طفلاً ربطه."},
	"music_box": {"name": "علبة الموسيقى", "desc": "علبة خشبية صغيرة منقوش عليها اسم: «ريما». تعزف لحناً بطيئاً إذا أُدير مفتاحها."},
	"shovel": {"name": "مجرفة", "desc": "مجرفة قديمة من الحظيرة. الطين اليابس على نصلها لم يُغسل منذ سنين."},
	"toy_shoe": {"name": "حذاء ريما", "desc": "حذاء طفلة صغير جداً، ما زال خيطه معقوداً. دُفن منذ أكثر من خمسين سنة… ومع ذلك دافئ."},
	"page_1": {"name": "صفحة مريم ١", "desc": "رسم لسبع شموع على كعكة، والرقم ٧ مكتوب بقلم الرصاص بخط مرتجف."},
	"page_2": {"name": "صفحة مريم ٢", "desc": "رسم لهلال في سماء مظلمة، تحته ثلاث نجوم. مكتوب: «الشهر الثالث»."},
	"page_3": {"name": "صفحة مريم ٣", "desc": "رسم لحبل عليه إحدى وعشرون عقدة، كل عقدة بيد صغيرة. مكتوب: ٢١."},
	"page_4": {"name": "صفحة مريم ٤", "desc": "خريطة بخط طفلة: البيت، الحظيرة، والبئر… وشجرة صفصاف عليها X كبيرة."},
}
const SAFE_CODE := [7, 3, 21]
const RADIO_FREQ := 97.3
const RADIO_MSG := "هنا الدكتور سالم… سجّلتُ هذه الرسالة لمن يعثر عليها. رمز الخزنة في المشرحة هو تاريخ اليوم الذي أُغلق فيه الباب: اليوم، ثم الشهر، ثم السنة. وإن سمعتَ صوتي ينادي باسمك… فلستُ أنا."

var player_name := "Player"
var use_mic := true
var solo := true
var step: int = Step.GENERATOR
var wheel_time := 8.0
var dead_ids: Array = []
var finished := false
const AI_URL_DEFAULT := "https://api.anthropic.com/v1/messages"
var ai_key := ""
var ai_url := AI_URL_DEFAULT
var ai_model := "qwen2.5:3b"   # used with a local OpenAI-compatible server (Ollama)
var ai_status := "AI: off"
var mind_status := ""
var battery := 100.0          # shared by flashlight, camera and recorder
var camera_on := false
var recording := false
var evidence: Array = []
var evp: Array = []
var reveal_level := 0         # 0 invisible .. 4 fully visible: she only appears fully near the end
var in_zone = null            # spirit zone the player stands in (for the recorder)
var notes_found: Array = []
var near_note := -1
var near_prompt := ""
var items: Array = []
var flags: Dictionary = {}
var resume_pos := Vector3.ZERO
var has_resume_pos := false
var has_tape: bool:
	get:
		return items.has("tape")
var alarm := false
const PHONE_POS := Vector3(-18, 0, -14)
var ending_kind := "normal"
const NOTES := [
	{"t": "دفتر الجدّة حليمة", "b": "كنتُ في الخامسة حين ماتت أختي ريما في العلّية. كانت حرارتها عالية، وأمي ركضت تبحث عن الطبيب في الليل.\nحين عادت كانت ريما باردة. منذ ذلك اليوم لم تغادر أمي نافذة العلّية."},
	{"t": "رسالة الطبيب — ١٩٢١", "b": "وصلتُ متأخراً ثلاث ساعات. الطريق إلى مزرعة الصفصاف كان مغلقاً بالثلج.\nالأم ثريّا لا تبكي ولا تتكلم. تهزّ المهد الفارغ وتغنّي… وتقول إن الطفلة نائمة."},
	{"t": "قصاصة جريدة محلية", "b": "«وفاة طفلة في مزرعة الصفصاف. الأم ترفض دفنها وتغلق الباب في وجه القرية. يُقال إن اللحن يُسمع من العلّية كل ليلة عند الثالثة.»"},
	{"t": "وصية ثريّا", "b": "لن أترك بيتي ولن أترك ابنتي. كل طفل ينام في هذا البيت سأغطّيه وأغنّي له… حتى لا يبرد أحد بعد اليوم.\nإن وجدتم حذاءها… فهي لم تكن وحدها."},
	{"t": "ملاحظات الدكتورة رنا", "b": "الظاهرة ليست عدائية بل حمائية: تتفاعل مع الأطفال. التسجيلات تتكرر: «ريما؟» و«لا تتركيني».\nالفرضية: روح الأم عالقة في لحظة الفقد. تحتاج أن ترى ابنتها… أو من يشبهها."},
	{"t": "ورقة بجانب القاطع", "b": "القاطع الرئيسي — ترتيب التشغيل الصحيح:\nالأحمر… ثم الأخضر… ثم الأصفر.\nالأزرق لا تلمسه أبداً. (بخط جدّي)"},
	{"t": "ورقة مبللة قرب البئر", "b": "أخذوا ما تبقّى من ريما ودفنوه بسرعة تحت شجرة الصفصاف، حيث كانت تلعب. لم يخبروا الأم.\nالبئر لم يكن إلا ممراً للماء… الماء الذي يحمل الأصوات."},
	{"t": "من دفتر سعيد", "b": "ظننتُ أنني اشتريتُ مزرعة رخيصة. لم أعلم أن أحداً يحتاجها لتبقى في مكانها… وأن أطفالي سيصبحون جزءاً من القصة."},
]
const KEYPAD_CODE := "1307"
const FUSE_ORDER := [0, 2, 3]
const NEWS_TICKER := "   عاجل • حادثة غامضة في مستشفى الرحمة • السلطات تغلق القبو • الشرطة: لا تقتربوا من المبنى بعد منتصف الليل • وزارة الصحة تنفي وجود تجارب •   "
const NEWS_INTRO := [
	"مساء الخير. نبدأ نشرتنا من مستشفى الرحمة، حيث أعلنت السلطات إغلاق القبو الجنوبي نهائياً.",
	"الشرطة تحقق فيما جرى عند الثالثة وسبع دقائق فجراً… ولا تعليق رسمي حتى الآن.",
	"ويحذّر المتحدث الرسمي المواطنين: لا تقتربوا من المبنى بعد منتصف الليل.",
]
const NEWS_LINES := [
	"مساء الخير. من مستشفى الرحمة: الشرطة تؤكد أن المريض رقم ثلاثة عشر كان محتجزاً في الغرفة رقم صفر سبعة حين انقطع التيار عند الثالثة وسبع دقائق.",
	"الطبيب المسؤول سالم الحارثي أوقفته النيابة العامة على ذمة التحقيق، ووزارة الصحة تنفي وجود أي تجارب.",
	"شهود يقولون إن الحارس خرج من القبو وهو يردد اسمه… ثم اختفى.",
	"وفي خبر عاجل: السلطات تقرر إحراق الأرشيف وإغلاق الباب بالخرسانة.",
]
var blackout_until := 0
var chaos_until := 0
var silence_until := 0
var mute_mic_until := 0
var typing := false
var night := 1            # endless: each escape makes the next night harder
const ZONE_NAMES := ["غرفة المعيشة", "غرفة الطعام", "المطبخ", "المكتب", "غرفة الوالدين", "غرفة الأطفال", "غرفة الضيوف", "القبو (الغرب)", "القبو (الشرق)", "العلّية"]
const OBJ_POS := [Vector3(-6, 0, 3), Vector3(11, -4, -8), Vector3(8, 4, -5), Vector3(0, 4, -6), Vector3(-10, 4, -6), Vector3(0, 8, -6), Vector3(14, 0, 25), Vector3(25, 0, -24), Vector3(0, 8, -6)]
var local_player: Node = null
var threat := 0.0         # 0..1 fear level near the monster
var touch_mode := false   # true on Android/iOS


func _ready() -> void:
	load_settings()
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "crouch": KEY_C, "crawl": KEY_Z, "interact": KEY_E, "flashlight": KEY_F, "talk": KEY_T, "inventory": KEY_I, "camera": KEY_R, "recorder": KEY_V,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)


func start_game(is_solo: bool) -> void:
	solo = is_solo
	if solo:
		Net.leave()
		Net.names = {1: player_name}
	wheel_time = 8.0 if solo else 14.0   # solo: a bit shorter, rules otherwise unchanged
	_reset()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _reset() -> void:
	dead_ids.clear()
	finished = false
	local_player = null
	threat = 0.0
	alarm = false
	near_prompt = ""
	near_note = -1
	blackout_until = 0
	chaos_until = 0
	silence_until = 0
	typing = false


func restart() -> void:
	if solo:
		load_run()          # back to the last checkpoint: the story is one continuous run
		start_game(true)
	elif multiplayer.is_server():
		_restart_all.rpc()


@rpc("authority", "call_local", "reliable")
func _restart_all() -> void:
	_reset()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


@rpc("any_peer", "call_local", "reliable")
func complete_step(s: int) -> void:
	if s != step:
		return
	step += 1
	update_reveal()
	objective_changed.emit(OBJECTIVES[step])
	radio_for(step)
	if step == Step.ESCAPED:
		finished = true
		night += 1
		clear_run()
		save_settings()
		game_won.emit()
	else:
		save_run()


@rpc("any_peer", "call_local", "unreliable")
func make_noise(pos: Vector3, loudness: float) -> void:
	noise_made.emit(pos, loudness)


@rpc("any_peer", "call_local", "reliable")
func register_death(id: int) -> void:
	if id in dead_ids:
		return
	dead_ids.append(id)
	if dead_ids.size() >= Net.names.size():
		game_over.emit()


func whisper(text: String, pitch := 0.3, rate := 0.7) -> void:
	subtitle.emit(text)
	mute_mic_until = Time.get_ticks_msec() + int(text.length() * 90.0) + 900
	var voices := DisplayServer.tts_get_voices_for_language("ar")
	if voices.is_empty():
		voices = DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	DisplayServer.tts_speak(text, voices[0], 70, pitch, rate, 0, true)


# ---- solo-safe helpers: in single-player nothing depends on multiplayer authority/RPC ----
func is_mine(n: Node) -> bool:
	return solo or n.is_multiplayer_authority()


func is_host() -> bool:
	return solo or multiplayer.is_server()


func my_id() -> int:
	return 1 if solo else multiplayer.get_unique_id()


func fire(method: String, args: Array) -> void:
	if solo:
		callv(method, args)
	else:
		callv("rpc", [method] + args)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") != OK:
		return
	player_name = c.get_value("player", "name", player_name)
	use_mic = c.get_value("player", "mic", use_mic)
	ai_key = c.get_value("ai", "key", "")
	ai_url = c.get_value("ai", "url", AI_URL_DEFAULT)
	ai_model = c.get_value("ai", "model", ai_model)
	night = c.get_value("progress", "night", 1)
	notes_found = c.get_value("progress", "notes", [])


func save_settings() -> void:
	var c := ConfigFile.new()
	c.load("user://settings.cfg")
	c.set_value("player", "name", player_name)
	c.set_value("player", "mic", use_mic)
	c.set_value("ai", "key", ai_key)
	c.set_value("ai", "url", ai_url)
	c.set_value("ai", "model", ai_model)
	c.set_value("progress", "night", night)
	c.set_value("progress", "notes", notes_found)
	c.save("user://settings.cfg")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---- talking to the monster (voice activity from the mic, or typed text) ----
@rpc("any_peer", "call_local", "reliable")
func report_speech(pid: int, dur: float, peak: float, text: String) -> void:
	speech_heard.emit(pid, dur, peak, text)


func say_to_monster(text: String) -> void:
	var lp = local_player
	if lp == null or not is_instance_valid(lp) or not lp.alive:
		return
	subtitle.emit("أنت: " + text)
	fire("report_speech", [my_id(), 1.5, 0.4, text])


# ---- story ----
func start_story() -> void:
	get_tree().change_scene_to_file("res://scenes/intro.tscn")


func note_title(i: int) -> String:
	return str(NOTES[i]["t"])


func note_body(i: int) -> String:
	return str(NOTES[i]["b"]).replace("{name}", player_name)


func open_note(i: int) -> void:
	if not notes_found.has(i):
		notes_found.append(i)
		save_settings()
	note_opened.emit(i)


## Shareable "case file" card: what the Shadow learned about you.
func case_text() -> String:
	var lines: Array = ["ملف القضية: بيت الصفصاف", "", "المحقق: %s" % player_name, "الليلة: %d" % night,
		"الأدلة المصوّرة: %d   |   التسجيلات: %d   |   الوثائق: %d/%d" % [evidence.size(), evp.size(), notes_found.size(), NOTES.size()]]
	if FileAccess.file_exists("user://shadow_mind.json"):
		var f := FileAccess.open("user://shadow_mind.json", FileAccess.READ)
		var j = JSON.parse_string(f.get_as_text()) if f != null else null
		if j is Dictionary:
			lines.append("محاولاتك: %d  |  مرات موتك: %d  |  ختمتَ البيت: %d" % [int(j.get("games", 0)), int(j.get("deaths", 0)), int(j.get("wins", 0))])
			lines.append("")
			lines.append("ما لاحظته الروح عنك:")
			if float(j.get("run_ratio", 0.0)) > 0.4:
				lines.append("• تركض كثيراً")
			if float(j.get("stare_break", 0.5)) < 0.3:
				lines.append("• تثبت جيداً حين تشعر بها")
	return "\n".join(lines)


func open_puzzle(kind: String, station: Node) -> void:
	puzzle_requested.emit(kind, station)


# ---- finale RPCs ----
@rpc("any_peer", "call_local", "reliable")
func start_final(pid: int) -> void:
	final_stare_requested.emit(pid)


@rpc("any_peer", "call_local", "reliable")
func freeze_monster(secs: float) -> void:
	monster_freeze.emit(secs)


@rpc("any_peer", "call_local", "reliable")
func door_failed(pid: int) -> void:
	door_failed_sig.emit(pid)


@rpc("any_peer", "call_local", "reliable")
func set_blackout(secs: float) -> void:
	blackout_until = Time.get_ticks_msec() + int(secs * 1000.0)


# ---- inventory, flags, checkpoints (one continuous run) ----
func has_item(id: String) -> bool:
	return items.has(id)


func item_name(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", id))


func add_item(id: String) -> void:
	if items.has(id):
		return
	items.append(id)
	item_added.emit(id)
	save_run()


func has_flag(k: String) -> bool:
	return flags.has(k)


func set_flag(k: String) -> void:
	flags[k] = true
	save_run()
	flag_set.emit(k)


func hand_reach() -> void:
	var lp = local_player
	if lp != null and is_instance_valid(lp) and lp.vm != null:
		lp.vm.reach()


func has_saved_run() -> bool:
	var c := ConfigFile.new()
	return c.load("user://settings.cfg") == OK and c.has_section_key("run", "step")


func save_run() -> void:
	var c := ConfigFile.new()
	c.load("user://settings.cfg")
	c.set_value("run", "step", step)
	c.set_value("run", "items", items)
	c.set_value("run", "flags", flags)
	c.set_value("run", "evidence", evidence)
	c.set_value("run", "evp", evp)
	c.set_value("run", "battery", battery)
	var lp = local_player
	if lp != null and is_instance_valid(lp):
		c.set_value("run", "pos", lp.global_position)
	c.save("user://settings.cfg")


func load_run() -> bool:
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") != OK or not c.has_section_key("run", "step"):
		return false
	step = int(c.get_value("run", "step", 0))
	items = c.get_value("run", "items", [])
	flags = c.get_value("run", "flags", {})
	evidence = c.get_value("run", "evidence", [])
	evp = c.get_value("run", "evp", [])
	battery = float(c.get_value("run", "battery", 100.0))
	update_reveal()
	if c.has_section_key("run", "pos"):
		resume_pos = c.get_value("run", "pos", Vector3.ZERO)
		has_resume_pos = true
	return true


func clear_run() -> void:
	step = Step.GENERATOR
	items = []
	flags = {}
	evidence = []
	evp = []
	battery = 100.0
	reveal_level = 0
	has_resume_pos = false
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") == OK:
		c.erase_section("run")
		c.save("user://settings.cfg")


func new_run() -> void:
	clear_run()


# ---- the haunting: battery, evidence, recordings, reveal level ----
func consume(x: float) -> void:
	battery = maxf(battery - x, 0.0)
	if battery <= 0.0:
		camera_on = false


func add_battery(x: float) -> void:
	battery = minf(battery + x, 100.0)


func add_evidence(id: String) -> void:
	if evidence.has(id):
		return
	evidence.append(id)
	evidence_added.emit(id)
	save_run()


func add_evp(id: String) -> void:
	if evp.has(id):
		return
	evp.append(id)
	evp_added.emit(id)
	save_run()


## She only shows herself fully near the end: before that, traces, shadows, and what the lens sees.
func update_reveal() -> void:
	if step >= Step.DIG:
		reveal_level = 3
	elif step >= Step.PAGES:
		reveal_level = 2
	elif step >= Step.EVIDENCE:
		reveal_level = 1
	else:
		reveal_level = 0


func hunt_enabled() -> bool:
	return step >= Step.PAGES and step < Step.ESCAPED


const FAMILY := {
	"saeed": {"name": "سعيد (الأب)", "pitch": 0.6, "lines": {
		0: ["لا أؤمن بهذه الخرافات… لكنني لم أنم منذ ثلاثة أيام.", "الكهرباء انقطعت مساء الأمس. القاطع الرئيسي في القبو، تدخل من باب المطبخ.", "جدي ترك ورقة بجانب القاطع بترتيب التشغيل. وخذ بطارية معك… الظلام هناك لا يرحم."],
		2: ["أرى أن الأنوار عادت. لا أعرف ما الذي تفعلونه… لكن أكملوا. أطفالي يخافون."],
		6: ["العلّية؟ لم أصعد إليها منذ اشتريتُ البيت. كان البائع يقول إنها مغلقة لسبب."],
	}},
	"layla": {"name": "ليلى (الأم)", "pitch": 1.0, "lines": {
		0: ["كل ليلة عند الثالثة تُغلق أبواب غرفة الأطفال وحدها… وأسمع امرأة تغنّي.", "لا أريد أن أهرب. أريد أن أفهم ماذا تريد منا.", "صوّروا ما تجدونه بالكاميرا… زوجي لا يصدّق إلا ما يراه."],
		3: ["إن سمعتَ التهويدة فلا تخف. هي لا تؤذي أحداً… بل تغطّي الأطفال كأنها أمهم."],
	}},
	"halima": {"name": "الجدّة حليمة", "pitch": 0.85, "lines": {
		0: ["هذا البيت لا يريد أن يؤذيكم… يريد شيئاً أُخذ منه.", "سجّلوا صوتها في غرفة الأطفال وفي العلّية… ستفهمون ما تريد."],
		5: ["علبة الموسيقى كانت لأختي الصغيرة… ريما. لا تسأل أكثر."],
		7: ["تحت الصفصاف… حيث كنا نلعب أنا وهي. احفر هناك."],
	}},
	"maryam": {"name": "مريم (١٦ سنة)", "pitch": 1.4, "lines": {
		0: ["أرسم وأنا نائمة… وأستيقظ والأوراق مبعثرة في كل مكان.", "هناك أربع صفحات. تحمل أرقاماً… لا أعرف معناها."],
		4: ["هل وجدتَ الصفحات؟ التاريخ مخبّأ فيها… اليوم، ثم الشهر، ثم السنة."],
	}},
	"ziad": {"name": "زياد (١٠ سنوات)", "pitch": 1.7, "lines": {
		0: ["السيدة تغنّي لي كل ليلة. تقول إنها وحيدة.", "هي لا تخيفني… لكنها تبكي كثيراً."],
		7: ["السيدة تجلس تحت الشجرة في الحديقة… تنتظر أحداً."],
	}},
}
const RADIO := {
	1: ["الدكتورة رنا", "هنا الشاحنة. ابدأ بالقبو. كمال يراقب الأجهزة. انتبه لبطاريتك: الكشاف والكاميرا والمسجّل يتشاركونها.", 1.2],
	2: ["كمال", "عادت الكهرباء. الآن الكاميرا: اضغط R وانظر بعدستك ما لا تراه عيناك. ثلاثة أدلة: بصمات، ظل، كتابة.", 0.7],
	3: ["الدكتورة رنا", "ممتاز. الآن المسجّل: اضغط V وقف في غرفة الأطفال أو العلّية. الأرواح تتكلم بين الفراغات.", 1.2],
	4: ["كمال", "الظاهرة تشتد. صفحات مريم هي المفتاح. وإن سمعتَ خطوات خلفك… لا تلتفت بسرعة.", 0.7],
	5: ["الدكتورة رنا", "التاريخ في الصفحات: اليوم والشهر والسنة. الخزنة في غرفة الوالدين.", 1.2],
	6: ["كمال", "العلّية. خذ ما فيها بهدوء… الحرارة هناك تنخفض بشكل غريب.", 0.7],
	7: ["الدكتورة رنا", "الحظيرة ثم الشجرة. هي لا تريد إيذاءنا… هي تبحث عن ابنتها.", 1.2],
	8: ["كمال", "ضع الحذاء في المهد وشغّل العلبة. وحين تظهر… لا تتحرك ولا تتكلم. أي حركة تعني أنها ستظنك ابنتها.", 0.7],
}


func family_lines(id: String) -> Array:
	var f: Dictionary = FAMILY[id]
	var best := -1
	for k in f["lines"]:
		if int(k) <= step and int(k) > best:
			best = int(k)
	return f["lines"][best] if best >= 0 else []


func radio_for(s: int) -> void:
	if not RADIO.has(s):
		return
	var r: Array = RADIO[s]
	subtitle.emit("[الراديو • %s] %s" % [r[0], r[1]])
	Util.speak(str(r[1]), float(r[2]), 0.95)


@rpc("any_peer", "call_local", "reliable")
func start_ritual(pid: int) -> void:
	ritual_requested.emit(pid)
