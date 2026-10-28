extends Node
class_name Ritual
## THE FINAL SCENE. Music box playing, the attic in total darkness, and Thuraya fully visible for the first time.
## Stay perfectly still and silent while she walks toward you. Halima's voice calls from downstairs. If you
## move or make a sound she thinks you are leaving her child again.

var monster
var player
var _running := false


func start(p, m) -> void:
	if _running:
		return
	player = p
	monster = m
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _violates(lenient: bool) -> bool:
	if not is_instance_valid(player) or not player.alive:
		return true
	if player.speed_now > (1.5 if lenient else 0.25):
		return true
	if lenient:
		return false
	if Game.is_mine(player) and Game.use_mic and Mic.enabled:
		return Mic.loudness > 0.5 and Time.get_ticks_msec() >= Game.mute_mic_until
	return player.noise_level > 0.7


func _run() -> void:
	_running = true
	monster.script_mode = true
	Game.reveal_level = 4
	Game.fire("set_blackout", [200.0])
	var p = player
	var n: String = p.display_name
	var box := AudioStreamPlayer3D.new()
	box.stream = ProcAudio.get_sound("musicbox")
	box.unit_size = 8.0
	box.volume_db = 2.0
	add_child(box)
	box.global_position = Vector3(0, 9.0, -6)
	box.play()
	# she appears at the far side of the attic
	var best := p.global_position
	for dir in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var c: Vector3 = p.global_position + dir * 8.0
		c.x = clampf(c.x, -11.0, 11.0)
		c.z = clampf(c.z, -7.0, 7.0)
		if c.distance_to(p.global_position) > best.distance_to(p.global_position):
			best = c
	var origin: Vector3 = p.global_position
	var start := Vector3(best.x, 8.0, best.z)
	monster.state = 3
	monster.global_position = start
	await _wait(3.0)
	Game.whisper("%s…" % n, 0.45, 0.6)
	await _wait(2.5)
	var t := 0.0
	var paused := 0.0
	var called := false
	while t < 22.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		if _violates(t > 17.0):
			_fail()
			return
		if t > 9.0 and not called:
			called = true
			Game.whisper("أمي…؟ أنا حليمة… لا تؤذيهم.", 0.85, 0.75)      # the grandmother, from downstairs
			paused = 3.5
		if paused > 0.0:
			paused -= dt
			monster.look_at(Vector3(0, 8.0, 8.0), Vector3.UP)           # she turns toward the voice
			continue
		t += dt
		var k := t / 22.0
		var pos := start.lerp(origin + (start - origin).normalized() * 1.4, k)
		monster.global_position = Vector3(pos.x, 8.0, pos.z)
		monster.look_at(Vector3(origin.x, 8.0, origin.z), Vector3.UP)
	Game.whisper("ريما…؟", 0.5, 0.55)
	monster._sting()
	await _wait(3.0)
	monster.fade_out(3.0)
	await _wait(3.2)
	box.queue_free()
	Game.reveal_level = 0
	Game.fire("set_blackout", [0.0])
	monster.global_position = Vector3(0, 40.0, 0)
	Game.set_flag("front_open")
	Game.fire("complete_step", [Game.Step.RITUAL])
	_running = false


func _fail() -> void:
	Game.fire("set_blackout", [0.0])
	monster.script_mode = false
	if is_instance_valid(player) and player.alive:
		monster._start_kill(player, "reach_through")
	_running = false
