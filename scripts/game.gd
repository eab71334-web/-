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
signal final_stare_requested(pid: int)
signal monster_freeze(secs: float)
signal door_failed_sig(pid: int)
signal speech_heard(pid: int, dur: float, peak: float, text: String)
signal item_added(id: String)
signal door_opened

const STARE_TIME := 7.0   # the "7 second rule"
enum Step { GENERATOR, LEVER, ARCHIVE, MORGUE, WHEEL, EXIT, ESCAPED }
const OBJECTIVES := [
	"اقرأ وثيقة ترتيب المصاهر، ثم شغّل المولد من لوحة المصاهر (سيصدر ضجيجاً!)",
	"اعثر على شريط VHS وشاهده على التلفاز، ثم أدخل رمز الطوارئ في غرفة المراقبة",
	"خذ مفتاح الأرشيف من غرفة المراقبة، افتح البوابة الجنوبية، ثم اضبط الراديو (الكشاف يكشف ما لا تراه العين)",
	"افتح الخزنة في المشرحة (جنوب شرق الأرشيف) بتاريخ إغلاق الباب: اليوم، الشهر، السنة",
	"خذ المفتاح، افتح غرفة B-13 (غرب غرفة الخروج) وأجب على الهاتف… ثم لا تتحرك ولا تتكلم",
	"اهرب إلى الباب الرئيسي وأغلقه خلفك قبل أن يصل!",
	"نجوت!",
]
const CHAPTERS := {
	0: ["الفصل الثاني", "التسلسل"],
	2: ["الفصل الثالث", "الأرشيف"],
	3: ["الفصل الرابع", "المشرحة"],
	4: ["الفصل الخامس", "الغرفة B-13"],
	5: ["الفصل السادس", "الباب"],
}
const ITEMS := {
	"tape": {"name": "شريط VHS", "desc": "نشرة أخبار مسجّلة بتاريخ ١٢/٠٣/١٩٨٧. على الغلاف بخط اليد: ٣:٠٧."},
	"key_archive": {"name": "مفتاح الأرشيف", "desc": "مفتاح نحاسي ثقيل. عليه نقش صغير: «الأرشيف — الجنوب»."},
	"key_b13": {"name": "مفتاح B-13", "desc": "مفتاح أحمر باهت. يداك ترتجفان وأنت تمسكه… كأنه يعرفك."},
}
const SAFE_CODE := [12, 3, 87]
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
	{"t": "سجل الدكتور سالم — ١٢ مارس ١٩٨٧", "b": "بنيتُ التسلسل في القبو: المولد أولاً، ثم ذراع الطوارئ، ثم العجلة.\nترتيب لوحة المصاهر: الأحمر… ثم الأزرق… ثم الأخضر. الأصفر فخّ.\nالمريض ١٣ لا يصمت. يناديني باسمي قبل أن أعرّفه بنفسي… وأنا لم أخبره بشيء."},
	{"t": "تقرير الأمن — الليلة ٣:٠٧", "b": "انقطع النور في تمام الثالثة وسبع دقائق. سمعنا ثلاث طرقات من الغرفة B-13.\nرمز لوحة الطوارئ: رقم المريض ثم رقم غرفته (أربع خانات). التفاصيل في نشرة الأخبار المسجّلة على الشريط.\nثم ناداني الحارس باسمي من الداخل… والحارس كان واقفاً بجانبي."},
	{"t": "أمر إداري — سرّي للغاية", "b": "يُغلق القبو نهائياً. لا يُذكر المريض ١٣ في أي وثيقة. من يسأل عنه يُحوَّل إلى الشرطة. تُحرق الأرشيفات قبل الفجر.\n— الإدارة"},
	{"t": "ورقة ممزقة بخط المريض ١٣", "b": "لستُ غاضباً… أنا وحيد.\nكل من يفتح الباب يأخذ صوتي ويخرج، وأبقى أنا. في كل ليلة أتعلّم عنكم أكثر.\nهذه المرة سأتعلّم كيف أخرج أنا.\nوإن رنّ الهاتف في غرفتي فأجب… ثم لا تتحرك ولا تتنفس. هو لا يرى إلا من يتحرك، ولا يسمع إلا من يتكلم."},
	{"t": "ملاحظة بخط يدك", "b": "يا {name}… لا تُغلق الباب خلفك.\nهذا ما فعلتَه في الليلة السابقة، وهذا ما سيفعله هو بصوتك في الليلة القادمة.\nأنت لست أول من فتح B-13… أنت الأخير."},
	{"t": "محضر الشرطة رقم ٨٧/٣١٢", "b": "عُثر على باب B-13 ملحوماً من الخارج وعليه ثلاثة أقفال بترتيب غريب. استُدعي مفتّح أقفال ليلاً ففتحه… ثم اختفى هو أيضاً. اسمه مشطوب بالحبر الأسود في السجل.\nتقرر طيّ القضية.\n— العقيد ن."},
	{"t": "تفريغ شريط الدكتور سالم", "b": "اكتشفتُ أن الباب لا يُحبس به المريض… بل يُحبس به ما بداخله. المريض ١٣ لم يكن مريضاً قط؛ كان أول من فتح الباب.\nوكل من يفتحه بعده يترك له شيئاً: نوره… ثم ذاكرته… ثم صوته."},
	{"t": "سجل المشرحة", "b": "الدرج ١٣ لا يحتوي جثة. يُفتح كل ليلة عند ٣:٠٧ من الداخل.\nوجدنا بداخله ثلاثة عشر مفتاحاً… على كل مفتاح اسم مفتّح أقفال."},
]
const KEYPAD_CODE := "1307"
const FUSE_ORDER := [0, 1, 2]
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
const ZONE_NAMES := ["القاعة الغربية", "القاعة الشرقية", "وسط القاعة", "الجهة الشرقية", "غرفة الخروج الغربية", "غرفة الخروج الشرقية", "غرفة المولد", "غرفة المراقبة", "زاوية المولد"]
const OBJ_POS := [Vector3(-17.5, 0, 17), Vector3(17.5, 0, 17), Vector3(-16, 0, 29), Vector3(14, 0, 42), Vector3(-18, 0, -14)]
var local_player: Node = null
var threat := 0.0         # 0..1 fear level near the monster
var touch_mode := false   # true on Android/iOS


func _ready() -> void:
	load_settings()
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "crouch": KEY_C, "crawl": KEY_Z, "interact": KEY_E, "flashlight": KEY_F, "talk": KEY_T, "inventory": KEY_I,
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
	objective_changed.emit(OBJECTIVES[step])
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
	var lines: Array = ["ملف القضية B-13", "", "الاسم: %s" % player_name, "الليلة: %d" % night,
		"الوثائق المكتشفة: %d/%d" % [notes_found.size(), NOTES.size()]]
	if FileAccess.file_exists("user://shadow_mind.json"):
		var f := FileAccess.open("user://shadow_mind.json", FileAccess.READ)
		var j = JSON.parse_string(f.get_as_text()) if f != null else null
		if j is Dictionary:
			lines.append("ليالٍ لعبتها: %d  |  مرات موتك: %d  |  نجاتك: %d" % [int(j.get("games", 0)), int(j.get("deaths", 0)), int(j.get("wins", 0))])
			lines.append("")
			lines.append("ما تعلّمه الظل عنك:")
			if float(j.get("run_ratio", 0.0)) > 0.4:
				lines.append("• تركض كثيراً")
			if float(j.get("stare_break", 0.5)) < 0.3:
				lines.append("• تثبت جيداً تحت نظرته")
			var best := -1
			var bv := 0.0
			var zu = j.get("zone_use", {})
			if zu is Dictionary:
				for k in zu:
					if float(zu[k]) > bv:
						bv = float(zu[k])
						best = int(k)
			if best >= 0 and best < ZONE_NAMES.size():
				lines.append("• تختبئ غالباً في " + ZONE_NAMES[best])
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
	if c.has_section_key("run", "pos"):
		resume_pos = c.get_value("run", "pos", Vector3.ZERO)
		has_resume_pos = true
	return true


func clear_run() -> void:
	step = Step.GENERATOR
	items = []
	flags = {}
	has_resume_pos = false
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") == OK:
		c.erase_section("run")
		c.save("user://settings.cfg")


func new_run() -> void:
	clear_run()
