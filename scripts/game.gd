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
signal speech_heard(pid: int, dur: float, peak: float, text: String)

const STARE_TIME := 7.0   # the "7 second rule"
enum Step { GENERATOR, LEVER, WHEEL, EXIT, ESCAPED }
const OBJECTIVES := [
	"تسلل إلى غرفة المولد واسحب الذراع (سيصدر ضجيجاً!)",
	"اذهب إلى غرفة المراقبة واسحب ذراع الطوارئ",
	"أدِر العجلة الهيدروليكية عند الباب الرئيسي",
	"اهرب عبر الباب الآن!",
	"نجوت!",
]

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
var ending_kind := "normal"
const NOTES := [
	{"t": "سجل الدكتور سالم — ١٢ مارس ١٩٨٧", "b": "بنيتُ التسلسل في القبو: المولد أولاً، ثم ذراع الطوارئ، ثم العجلة. أي خطأ في الترتيب يُبقي الباب مغلقاً إلى الأبد.\nالمريض ١٣ لا يصمت. يناديني باسمي قبل أن أعرّفه بنفسي… وأنا لم أخبره بشيء."},
	{"t": "تقرير الأمن — الليلة ٣:٠٧", "b": "انقطع النور في تمام الثالثة وسبع دقائق. سمعنا ثلاث طرقات من الغرفة B-13.\nثم ناداني الحارس باسمي من الداخل… والحارس كان واقفاً بجانبي."},
	{"t": "أمر إداري — سرّي للغاية", "b": "يُغلق القبو نهائياً. لا يُذكر المريض ١٣ في أي وثيقة. من يسأل عنه يُحوَّل إلى الشرطة. تُحرق الأرشيفات قبل الفجر.\n— الإدارة"},
	{"t": "ورقة ممزقة بخط المريض ١٣", "b": "لستُ غاضباً… أنا وحيد.\nكل من يفتح الباب يأخذ صوتي ويخرج، وأبقى أنا. في كل ليلة أتعلّم عنكم أكثر.\nهذه المرة سأتعلّم كيف أخرج أنا."},
	{"t": "ملاحظة بخط يدك", "b": "يا {name}… لا تُغلق الباب خلفك.\nهذا ما فعلتَه في الليلة السابقة، وهذا ما سيفعله هو بصوتك في الليلة القادمة.\nأنت لست أول من فتح B-13… أنت الأخير."},
]
var blackout_until := 0
var chaos_until := 0
var silence_until := 0
var mute_mic_until := 0
var typing := false
var night := 1            # endless: each escape makes the next night harder
const ZONE_NAMES := ["القاعة الغربية", "القاعة الشرقية", "وسط القاعة", "الجهة الشرقية", "غرفة الخروج الغربية", "غرفة الخروج الشرقية", "غرفة المولد", "غرفة المراقبة", "زاوية المولد"]
const OBJ_POS := [Vector3(-17.5, 0, 17), Vector3(17.5, 0, 17), Vector3(0, 0, -18)]
var local_player: Node = null
var threat := 0.0         # 0..1 fear level near the monster
var touch_mode := false   # true on Android/iOS


func _ready() -> void:
	load_settings()
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "crouch": KEY_C, "crawl": KEY_Z, "interact": KEY_E, "flashlight": KEY_F, "talk": KEY_T,
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
	step = Step.GENERATOR
	dead_ids.clear()
	finished = false
	local_player = null
	threat = 0.0
	blackout_until = 0
	chaos_until = 0
	silence_until = 0
	typing = false


func restart() -> void:
	if solo:
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
		save_settings()
		game_won.emit()


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
