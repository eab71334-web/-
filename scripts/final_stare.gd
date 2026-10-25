extends Node
class_name FinalStare
## THE FINALE. The phone in room B-13 rings. When you answer, every light dies and the Shadow stands
## behind you in the dark. For 7 seconds you must NOT move and NOT make a sound (the microphone listens).
## He circles closer, whispers your name, ends up face to face... then lets you go. The alarm starts: RUN.

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
	var mic := player.noise_level
	if Game.is_mine(player) and Game.use_mic and Mic.enabled:
		mic = 0.0 if Time.get_ticks_msec() < Game.mute_mic_until else Mic.loudness   # ignore the game's own voice
		return mic > 0.5
	return mic > 0.7


func _run() -> void:
	_running = true
	monster.script_mode = true
	monster.state = 3                                   # STARE pose
	Game.fire("set_blackout", [90.0])                   # total darkness
	var p = player
	var n: String = p.display_name
	var fwd: Vector3 = -p.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	monster.global_position = Vector3(p.global_position.x - fwd.x * 7.0, 0.0, p.global_position.z - fwd.z * 7.0)
	monster._all("say", ["…%s؟" % n])
	await _wait(2.2)
	# the call: a voice that sounds like you tells you the rule
	for l in ["%s… لا تجب." % n, "لا تتحرك… ولا تتنفس.", "هو لا يرى إلا من يتحرك… ولا يسمع إلا من يتكلم.", "سبع ثوانٍ فقط."]:
		Game.whisper(l, 1.0, 0.85)
		await _wait(1.8 + l.length() * 0.05)
	Game.subtitle.emit("")
	# ---- the seven seconds ----
	var origin: Vector3 = p.global_position
	var basis: Basis = p.global_transform.basis
	var t := 0.0
	var said := [false, false, false]
	while t < 7.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if _violates(false):
			_fail()
			return
		var k := t / 7.0
		var ang := lerpf(PI, 0.0, k)
		var r := lerpf(7.0, 1.4, k * k)
		var off: Vector3 = basis * Vector3(sin(ang) * r * 0.9, 0.0, -cos(ang) * r)
		monster.global_position = Vector3(origin.x + off.x, 0.0, origin.z + off.z)
		monster.look_at(Vector3(p.global_position.x, 0.0, p.global_position.z), Vector3.UP)
		if t > 1.5 and not said[0]:
			said[0] = true
			monster._all("say", ["%s…" % n])
		if t > 3.5 and not said[1]:
			said[1] = true
			monster._all("say", ["أسمع قلبك…"])
		if t > 5.5 and not said[2]:
			said[2] = true
			monster._all("say", ["…قريب جداً."])
	# ---- face to face ----
	monster.state = 5
	monster._sting()
	p.shake(0.7)
	var hold := 0.0
	while hold < 2.5:
		await get_tree().process_frame
		hold += get_process_delta_time()
		if _violates(true):
			_fail()
			return
	monster._all("say", ["…اذهب."])
	await _wait(1.0)
	# he steps back into the dark; alarm; door unlocks; the chase begins
	var back := Vector3(origin.x - fwd.x * 12.0, 0.0, origin.z - fwd.z * 12.0)
	var tw := create_tween()
	tw.tween_property(monster, "global_position", back, 1.2)
	await tw.finished
	Game.fire("set_blackout", [0.0])
	monster.script_mode = false
	Game.fire("complete_step", [Game.Step.WHEEL])
	_running = false


func _fail() -> void:
	Game.fire("set_blackout", [0.0])
	monster.script_mode = false
	if is_instance_valid(player) and player.alive:
		monster._start_kill(player, "intercept_slam")
	_running = false
