extends Node
## Global state: input map, objectives, noise events, death/win flow, name whispers.

signal objective_changed(text: String)
signal subtitle(text: String)
signal noise_made(pos: Vector3, loudness: float)
signal confrontation(victim_id: int, on: bool)
signal fade_requested
signal game_over
signal game_won

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
var local_player: Node = null
var touch_mode := false   # true on Android/iOS


func _ready() -> void:
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "crouch": KEY_C, "crawl": KEY_Z, "interact": KEY_E, "flashlight": KEY_F,
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
	var voices := DisplayServer.tts_get_voices_for_language("ar")
	if voices.is_empty():
		voices = DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	DisplayServer.tts_speak(text, voices[0], 70, pitch, rate, 0, true)
