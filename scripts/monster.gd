extends CharacterBody3D
class_name Monster
## Adaptive stalker. The AI runs on the server only; clients just see replicated position.
## States: PATROL -> (hear) INVESTIGATE -> SEARCH_HIDE -> CONFRONT (stands on your hiding spot)
##         PATROL -> (sees you) STARE for 7 s -> CHASE if you move or make noise -> KILL
## Learning: remembers where it saw you, which crates you hid behind, and gets angrier every time you survive a stare.

enum State { PATROL, INVESTIGATE, CHASE, STARE, SEARCH_HIDE, CONFRONT, KILLING, TALK }

const PATROL_SPEED := 2.4
const CHASE_SPEED := 5.0
const SIGHT_RANGE := 16.0
const KILL_RANGE := 1.7

var state: int = State.PATROL
var patrol_points: Array = []
var hide_zones: Array = []
var agent: NavigationAgent3D
var eyes: Node3D
var target: Player = null
var dest := Vector3.ZERO
var timer := 0.0
var lost_sight := 0.0
var last_known := Vector3.ZERO
var noise_pos := Vector3.ZERO
var aggression := 0.0
var ignore_until := 0
var player_trail: Array = []
var trail_timer := 0.0
var seen_t := {}
var seen_pos := {}
var current_zone: HideZone = null
var confront_noise := 0.0
var confront_victim: Player = null
var name_cd := 15.0
var brain: AIBrain
var mind: ShadowMind
var hold_t := 0.0
var _flash_t := 0.0
var _fade_t := 0.0
var _fade_total := 1.0
var script_mode := false     # true while a scripted scene (finale / door) drives him
var style := "walk"
var style_speed := 1.0
var talk_t := 0.0
var talk_dur := 4.0
var talk_outcome := "toy"
var ai_t := 3.0
var seen_post := {}
const POSTURES := ["standing", "running", "crouching", "crawling", "hiding"]
var rig
var breath: AudioStreamPlayer3D
var step_snd: AudioStreamPlayer3D
var _last_pos := Vector3.ZERO
var _speed_s := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.2
	cs.shape = cap
	cs.position.y = 1.1
	add_child(cs)
	rig = GhostRig.new()
	add_child(rig)
	eyes = Node3D.new()
	eyes.position = Vector3(0, 2.0, -0.3)
	add_child(eyes)
	breath = AudioStreamPlayer3D.new()
	breath.stream = ProcAudio.get_sound("breath")
	breath.unit_size = 5.0
	breath.max_distance = 30.0
	breath.volume_db = -4.0
	add_child(breath)
	breath.play()
	step_snd = AudioStreamPlayer3D.new()
	step_snd.stream = ProcAudio.get_sound("thud")
	step_snd.unit_size = 8.0
	step_snd.max_distance = 35.0
	step_snd.volume_db = 2.0
	add_child(step_snd)
	rig.footstep.connect(_on_footstep)

	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation", ":state"]:
		cfg.add_property(NodePath(prop))
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = cfg
	add_child(sync)

	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 1.0
	agent.radius = 0.5
	agent.height = 2.2
	add_child(agent)

	if not Game.is_host():
		return
	hide_zones = get_tree().get_nodes_in_group("hide_zones")
	brain = AIBrain.new()
	add_child(brain)
	brain.decided.connect(_on_ai)
	mind = ShadowMind.new()
	add_child(mind)
	aggression = minf(0.1 * (Game.night - 1), 0.8)
	get_tree().create_timer(4.0).timeout.connect(func(): _all("say", [mind.line("greet", Game.player_name)]))
	Game.noise_made.connect(_on_noise)
	Game.objective_changed.connect(_on_objective)
	Game.speech_heard.connect(_on_speech)
	Game.monster_freeze.connect(_on_freeze)
	Game.door_failed_sig.connect(_on_door_failed)
	_pick_patrol()


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	if not Game.is_host() or state == State.KILLING or Game.finished or script_mode:
		return
	_learn(delta)
	if state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]:
		mind.tick(delta, self)
	ai_t -= delta
	if ai_t <= 0.0 and state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]:
		ai_t = 4.0
		brain.think(_snapshot())
	if state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]:
		name_cd -= delta
		if name_cd <= 0.0:
			name_cd = randf_range(12.0, 25.0)
			var ps := _alive_players()
			if not ps.is_empty():
				var pl = ps.pick_random()
				if randf() < 0.5:
					_all("call_name", [pl.display_name])
				else:
					_all("say", [mind.line("hunt", pl.display_name)])
	match state:
		State.PATROL: _patrol(delta)
		State.INVESTIGATE: _investigate(delta)
		State.SEARCH_HIDE: _search_hide(delta)
		State.STARE: _stare(delta)
		State.CHASE: _chase(delta)
		State.CONFRONT: _confront(delta)
		State.TALK: _talk(delta)


func _set_state(s: int) -> void:
	state = s
	lost_sight = 0.0
	if s == State.STARE:
		timer = Game.STARE_TIME


# ------------------------------------------------------------------ senses
func _alive_players() -> Array:
	return get_tree().get_nodes_in_group("players").filter(func(p): return p.alive)


func _can_see(p: Player) -> bool:
	if p.hidden:
		return false
	var to_pos := p.global_position + Vector3(0, 1.0, 0)
	var to := to_pos - eyes.global_position
	var d := to.length()
	if d > SIGHT_RANGE:
		return false
	var fwd := -global_transform.basis.z
	if d > 3.0 and fwd.dot(to.normalized()) < 0.25:
		return false
	var q := PhysicsRayQueryParameters3D.create(eyes.global_position, to_pos, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _heard(p: Player) -> bool:
	return p.noise_level * 16.0 > global_position.distance_to(p.global_position)


func _can_notice() -> bool:
	return Time.get_ticks_msec() >= ignore_until


## Learning: remember where players were seen, and which crates they vanished behind.
func _learn(delta: float) -> void:
	trail_timer -= delta
	var now := Time.get_ticks_msec()
	for p in _alive_players():
		if _can_see(p):
			seen_t[p.name] = now
			seen_pos[p.name] = p.global_position
			seen_post[p.name] = POSTURES[p.posture]
			if trail_timer <= 0.0:
				player_trail.append(p.global_position)
				mind.note_pos(p)
				if player_trail.size() > 24:
					player_trail.pop_front()
		elif p.hidden and seen_t.has(p.name) and now - seen_t[p.name] < 6000:
			var z := _nearest_zone(seen_pos[p.name])
			if z != null:
				z.score += 1.0     # "this one gets used" -> checked more often
				brain.remember("%s vanished near hide zone %d" % [p.display_name, hide_zones.find(z)])
				mind.note_zone(hide_zones.find(z))
			seen_t.erase(p.name)
	if trail_timer <= 0.0:
		trail_timer = 3.0


# ------------------------------------------------------------------ movement helpers
func _move_to(to: Vector3, speed: float, delta: float) -> bool:
	agent.target_position = to
	if agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return true
	var dir := agent.get_next_path_position() - global_position
	dir.y = clampf(dir.y, -0.8, 0.8)      # follow ramps (stairs) up and down
	if dir.length() > 0.01:
		dir = dir.normalized()
		_face_point(global_position + dir, delta, 6.0)
	velocity = dir * speed
	move_and_slide()
	return false


func _face_point(p: Vector3, delta: float, speed: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * speed, 0.0, 1.0))


# ------------------------------------------------------------------ states
func _pick_patrol() -> void:
	if mind != null and mind.choose(self):
		return
	var r := randf()
	if r < 0.35 and not player_trail.is_empty():
		dest = player_trail.pick_random()           # where you have been
	elif r < 0.6 and not hide_zones.is_empty():
		var best: HideZone = hide_zones.pick_random()
		for z in hide_zones:
			if z.score > best.score:
				best = z                            # your favourite hiding spot
		dest = best.global_position
	else:
		dest = patrol_points.pick_random()


func _patrol(delta: float) -> void:
	for p in _alive_players():
		if _can_notice() and _can_see(p):
			_on_spotted(p)
			return
		if _heard(p):
			mind.note_noise(p.noise_level)
			_start_investigate(p.global_position)
			return
	if _move_to(dest, PATROL_SPEED * style_speed, delta):
		if hold_t > 0.0:
			hold_t -= delta
			rotation.y += delta * 0.8      # stands still, listening
		else:
			_pick_patrol()


func _on_spotted(p: Player) -> void:
	brain.remember("I saw %s %s" % [p.display_name, POSTURES[p.posture]])
	mind.reward(1.5)
	if randf() < 0.6:
		_all("say", [mind.line("spot", p.display_name)])
	target = p
	last_known = p.global_position
	if global_position.distance_to(p.global_position) < 3.5:
		_set_state(State.CHASE)      # too close: no mercy
	else:
		_set_state(State.STARE)      # freezes and fixes his eyes on you for 7 s


func _stare(delta: float) -> void:
	velocity = Vector3.ZERO
	if target == null or not is_instance_valid(target) or not target.alive:
		_set_state(State.PATROL)
		return
	var p := target
	_face_point(p.global_position, delta, 10.0)
	if _can_see(p):
		lost_sight = 0.0
		last_known = p.global_position
	else:
		lost_sight += delta
		if lost_sight > 1.5:
			_start_investigate(last_known)
			return
	if p.speed_now > 0.6 or p.noise_level > 0.5:
		mind.note_stare(true)
		_set_state(State.CHASE)      # you moved or made noise: he attacks at once
		return
	timer -= delta
	if timer <= 0.0:                  # you survived the stare
		aggression = minf(aggression + 0.15, 1.0)
		brain.remember("%s stood still under my 7-second stare and survived" % p.display_name)
		mind.note_stare(false)
		ignore_until = Time.get_ticks_msec() + 5000
		_start_investigate(p.global_position)


func _chase(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		_set_state(State.PATROL)
		return
	if _can_see(target):
		lost_sight = 0.0
		last_known = target.global_position
	else:
		lost_sight += delta
	if global_position.distance_to(target.global_position) < KILL_RANGE and not target.hidden:
		_start_kill(target)
		return
	if lost_sight > 4.0:
		_start_investigate(last_known)
		return
	_move_to(last_known, CHASE_SPEED * (1.0 + aggression * 0.15 + 0.03 * minf(Game.night - 1, 10.0)), delta)


func _start_investigate(pos: Vector3) -> void:
	noise_pos = pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	timer = 3.0
	_set_state(State.INVESTIGATE)


func _investigate(delta: float) -> void:
	for p in _alive_players():
		if _can_notice() and _can_see(p):
			_on_spotted(p)
			return
	if _move_to(noise_pos, PATROL_SPEED * 1.3, delta):
		timer -= delta
		rotation.y += delta * 1.2        # looks around
		if timer <= 0.0:
			_begin_search_hide()


func _begin_search_hide() -> void:
	var best: HideZone = null
	var best_w := -1.0
	var now := Time.get_ticks_msec()
	for z in hide_zones:
		if now - z.last_checked < 15000:
			continue
		var d := z.global_position.distance_to(noise_pos)
		if d > 10.0:
			continue
		var w := (10.0 - d) + z.score * 3.0
		if w > best_w:
			best_w = w
			best = z
	if best == null:
		_set_state(State.PATROL)
		_pick_patrol()
		return
	current_zone = best
	_set_state(State.SEARCH_HIDE)


func _search_hide(delta: float) -> void:
	for p in _alive_players():
		if _can_notice() and _can_see(p):
			_on_spotted(p)
			return
	if _move_to(current_zone.global_position + Vector3(0, 0, 2.0), PATROL_SPEED * style_speed, delta) \
			or global_position.distance_to(current_zone.global_position) < 2.8:
		_begin_confront()


func _player_in_zone(z: HideZone) -> Player:
	for p in _alive_players():
		if p.hidden and p.global_position.distance_to(z.global_position) < 3.0:
			return p
	return null


## The iconic moment: he climbs the rubble above your hiding spot and calls your name.
func _begin_confront() -> void:
	_set_state(State.CONFRONT)
	timer = 4.5
	confront_noise = 0.0
	confront_victim = _player_in_zone(current_zone)
	var vid := -1
	if confront_victim != null:
		vid = str(confront_victim.name).to_int()
	_all("_confront_ui", [vid, true])
	create_tween().tween_property(self, "position:y", current_zone.global_position.y + 0.9, 1.0)


func _confront(delta: float) -> void:
	velocity = Vector3.ZERO
	timer -= delta
	_face_point(current_zone.global_position, delta, 0.8)     # turns his head very slowly
	var v := confront_victim
	if v != null and is_instance_valid(v) and v.alive:
		confront_noise = maxf(confront_noise, v.noise_level)
		if not v.hidden:
			_end_confront(true)       # popped out of hiding
			return
		if (timer < 3.0 and timer + delta >= 3.0) or (timer < 1.5 and timer + delta >= 1.5):
			_all("call_name", [v.display_name])
	if timer <= 0.0:
		var suspicion := 0.25 + current_zone.score * 0.2 + aggression * 0.3
		_end_confront(v != null and v.alive and v.hidden and (confront_noise > 0.4 or randf() < suspicion))


func _end_confront(kill: bool) -> void:
	_all("_confront_ui", [-1, false])
	current_zone.last_checked = Time.get_ticks_msec()
	if kill and confront_victim != null:
		_start_kill(confront_victim)
		return
	if confront_victim != null and confront_victim.hidden:
		current_zone.score += 0.5     # he suspects this spot more next time
	create_tween().tween_property(self, "position:y", 0.0, 0.6)
	_set_state(State.PATROL)
	_pick_patrol()


# ------------------------------------------------------------------ events
func _on_noise(pos: Vector3, loudness: float) -> void:
	brain.remember("heard a noise (%.1f) near x=%d z=%d" % [loudness, int(pos.x), int(pos.z)])
	if state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE] \
			and global_position.distance_to(pos) < loudness * 30.0:
		_start_investigate(pos)


func _on_objective(_t: String) -> void:
	pass


func _nearest_zone(pos: Vector3) -> HideZone:
	var best: HideZone = null
	for z in hide_zones:
		if best == null or z.global_position.distance_to(pos) < best.global_position.distance_to(pos):
			best = z
	return best


func _find_player(id: int) -> Player:
	for p in get_tree().get_nodes_in_group("players"):
		if str(p.name).to_int() == id:
			return p
	return null


# ------------------------------------------------------------------ dynamic kills
func _start_kill(victim: Player, force_kind := "") -> void:
	state = State.KILLING
	brain.remember("I caught and killed %s" % victim.display_name)
	var kind := "intercept_slam"
	if victim.hidden:
		kind = ["crush_crate", "reach_through"].pick_random()
	elif victim.posture == Player.Posture.CRAWL:
		kind = "stomp_lift"
	if force_kind != "":
		kind = force_kind
	mind.reward(3.0)
	mind.on_kill(victim, kind)
	_all("play_kill", [str(victim.name).to_int(), kind, randi()])


@rpc("authority", "call_local", "reliable")
func call_name(n: String) -> void:
	Game.whisper(n, randf_range(0.2, 0.5), randf_range(0.55, 0.8))
	rig.speak_for(1.4)


@rpc("authority", "call_local", "reliable")
func _confront_ui(vid: int, on: bool) -> void:
	Game.confrontation.emit(vid, on)


## The kill is built on the spot from the victim's posture/position + a random seed,
## so it is never the same animation twice.
@rpc("authority", "call_local", "reliable")
func play_kill(victim_id: int, kind: String, seed_val: int) -> void:
	var v := _find_player(victim_id)
	if v == null:
		return
	state = State.KILLING
	Game.confrontation.emit(victim_id, false)
	_sting()
	v.on_killed_start()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var ang := rng.randf() * TAU
	var side := Vector3(sin(ang), 0.0, cos(ang))
	var mine := Game.is_host()        # server moves the monster
	var vmine := Game.is_mine(v)     # victim's own peer moves the victim
	var vpos := v.global_position
	var mpos := vpos + side * 1.5
	mpos.y = vpos.y
	if mine:
		position.y = 0.0
	match kind:
		"crush_crate":
			var z := _nearest_zone(vpos)
			if z != null:
				z.shatter()
			if mine:
				global_position = vpos + Vector3(0, 2.2, 0)
				create_tween().tween_property(self, "global_position:y", vpos.y, 0.25) \
					.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			if vmine:
				v.face_point(vpos + Vector3(0, 3.0, 0))
				v.shake(0.8)
			Game.whisper(v.display_name, 0.25, 0.6)
		"reach_through":
			mpos = vpos + side * 2.4
			mpos.y = vpos.y
			if mine:
				global_position = mpos
				look_at(Vector3(vpos.x, global_position.y, vpos.z), Vector3.UP)
			var arm := _spawn_arm()
			create_tween().tween_property(arm, "scale:z", 2.6, 0.35)
			if vmine:
				v.face_point(mpos + Vector3(0, 2.0, 0))
				create_tween().tween_property(v, "global_position", vpos + side * 1.1, 0.7).set_delay(0.4)
				v.shake(0.4)
			Game.whisper(v.display_name, 0.4, 0.7)
		"stomp_lift":
			var corner := Vector3(clampf(vpos.x + side.x * 3.0, -19.0, 19.0), vpos.y + 1.3, clampf(vpos.z + side.z * 3.0, -19.0, 19.0))
			if mine:
				global_position = mpos
				look_at(Vector3(vpos.x, global_position.y, vpos.z), Vector3.UP)
				var tm := create_tween()
				tm.tween_interval(0.6)
				tm.tween_property(self, "global_position", Vector3(corner.x, 0.0, corner.z) + side * 0.9, 0.9)
			if vmine:
				v.look_down()
				var tv := create_tween()
				tv.tween_interval(0.6)
				tv.tween_property(v, "global_position", corner, 0.9).set_trans(Tween.TRANS_QUAD)
				tv.tween_callback(v.face_point.bind(corner + side * 0.9 + Vector3(0, 2.0, 0)))
				v.shake(0.6)
			Game.whisper(v.display_name, 0.5, 0.55)
		_:  # intercept_slam
			if mine:
				global_position = vpos + side * 6.0
				look_at(Vector3(vpos.x, global_position.y, vpos.z), Vector3.UP)
				create_tween().tween_property(self, "global_position", vpos + side * 1.0, 0.18)
			if vmine:
				v.face_point(vpos + side * 6.0 + Vector3(0, 2.0, 0))
				var thrown := vpos - side * 3.0
				thrown.x = clampf(thrown.x, -19.0, 19.0)
				thrown.z = clampf(thrown.z, -19.0, 19.0)
				var t := create_tween()
				t.tween_interval(0.18)
				t.tween_property(v, "global_position", thrown, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
				t.parallel().tween_property(v.cam, "rotation:z", rng.randf_range(-1.5, 1.5), 0.35)
				v.shake(1.0)
			Game.whisper(v.display_name, 0.7, 0.8)
	if vmine:
		get_tree().create_timer(2.2).timeout.connect(v.finish_death)
	if mine:
		get_tree().create_timer(4.0).timeout.connect(_resume)


func _spawn_arm() -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 1.2, -0.4)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.18, 1.0)
	bm.material = Util.mat(Color(0.03, 0.03, 0.04))
	mi.mesh = bm
	mi.position.z = -0.5
	pivot.add_child(mi)
	pivot.scale.z = 0.2
	add_child(pivot)
	get_tree().create_timer(2.0).timeout.connect(pivot.queue_free)
	return pivot


func _resume() -> void:
	if not _alive_players().is_empty() and not Game.finished:
		position.y = 0.0
		_set_state(State.PATROL)
		_pick_patrol()


# ------------------------------------------------------------------ look & sound
func _process(delta: float) -> void:
	if rig == null:
		return
	var flat := Vector3(global_position.x - _last_pos.x, 0.0, global_position.z - _last_pos.z)
	_last_pos = global_position
	_speed_s = lerpf(_speed_s, minf(flat.length() / maxf(delta, 0.001), 7.0), minf(delta * 8.0, 1.0))
	rig.style = style
	rig.animate(delta, _speed_s, state, Time.get_ticks_msec() / 1000.0)
	rig.set_alpha(_vis_alpha())
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0 and script_mode:
			global_position = Vector3(0, 40, 0)
	if _fade_t > 0.0:
		_fade_t -= delta
	breath.pitch_scale = 1.4 if state == State.CHASE else 0.9


func _on_footstep() -> void:
	step_snd.pitch_scale = randf_range(0.8, 1.2)
	step_snd.play()


func _sting() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = ProcAudio.get_sound("sting")
	p.volume_db = 2.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _all(method: String, args: Array) -> void:
	if Game.solo:
		callv(method, args)
	else:
		callv("rpc", [method] + args)


# ------------------------------------------------------------------ LLM director
## Only what the monster could have sensed: no omniscient positions.
func _snapshot() -> Dictionary:
	var now := Time.get_ticks_msec()
	var ps: Array = []
	for p in _alive_players():
		var ago := -1.0
		if seen_t.has(p.name):
			ago = snappedf((now - seen_t[p.name]) / 1000.0, 0.1)
		var at := []
		if seen_pos.has(p.name):
			at = [int(seen_pos[p.name].x), int(seen_pos[p.name].z)]
		ps.append({
			"name": p.display_name,
			"visible_now": _can_see(p),
			"heard_now": _heard(p),
			"seconds_since_seen": ago,
			"last_seen_at": at,
			"last_seen_as": seen_post.get(p.name, "unknown"),
		})
	var zs: Array = []
	for i in hide_zones.size():
		var z: HideZone = hide_zones[i]
		zs.append({"i": i, "at": [int(z.global_position.x), int(z.global_position.z)], "player_used_times": z.score,
			"checked_s_ago": snappedf((now - z.last_checked) / 1000.0, 1.0) if z.last_checked > 0 else -1})
	return {
		"my_state": State.keys()[state],
		"i_am_at": [int(global_position.x), int(global_position.z)],
		"aggression": snappedf(aggression, 0.05),
		"objective_players_follow": Game.OBJECTIVES[Game.step],
		"players": ps,
		"hide_zones": zs,
	}


func _on_ai(d: Dictionary) -> void:
	var line := str(d.get("line", "")).left(80)
	if line != "":
		_all("say", [line])
	if not (state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]):
		return      # the LLM only steers calm states; chase/stare/kill stay rule-based and fair
	match str(d.get("intent", "")):
		"investigate":
			var best := ""
			for n in seen_t:
				if best == "" or seen_t[n] > seen_t[best]:
					best = n
			if best != "":
				_start_investigate(seen_pos[best])
		"search_hide":
			var zi := int(d.get("zone", -1))
			if zi >= 0 and zi < hide_zones.size():
				current_zone = hide_zones[zi]
				noise_pos = current_zone.global_position
				_set_state(State.SEARCH_HIDE)
		"ambush":
			if not player_trail.is_empty():
				dest = player_trail.back()
				_set_state(State.PATROL)


@rpc("authority", "call_local", "reliable")
func say(text: String) -> void:
	Game.whisper(text, randf_range(0.2, 0.45), 0.65)
	rig.speak_for(text.length() * 0.09 + 0.8)


# ------------------------------------------------------------------ hearing you speak
func _on_speech(pid: int, dur: float, peak: float, text: String) -> void:
	var p := _find_player(pid)
	if p == null or not p.alive:
		return
	if state in [State.CHASE, State.KILLING, State.CONFRONT, State.TALK]:
		return
	var intent := ShadowTalk.intent(text) if text != "" else ShadowTalk.voice_intent(peak)
	brain.remember("%s spoke to me (%s)" % [p.display_name, intent])
	if global_position.distance_to(p.global_position) > 7.0:
		if state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]:
			_start_investigate(p.global_position)      # heard a voice somewhere
		return
	if mind.should_talk(intent, state == State.STARE, aggression):
		_begin_talk(p, intent)
	elif state != State.STARE:
		target = p
		_set_state(State.STARE)                        # answers with silence: stares instead


func _begin_talk(p: Player, intent: String) -> void:
	target = p
	_set_state(State.TALK)
	talk_outcome = mind.decide(intent, aggression)
	var line := ShadowTalk.reply(intent, mind.talk_context(p.display_name))
	talk_t = 0.0
	talk_dur = 3.0 + line.length() * 0.06
	mind.note_talk(intent)
	_all("say", [line])


func _talk(delta: float) -> void:
	velocity = Vector3.ZERO
	if target == null or not is_instance_valid(target) or not target.alive:
		_set_state(State.PATROL)
		return
	_face_point(target.global_position, delta, 6.0)
	talk_t += delta
	if target.noise_level > 0.85 or target.speed_now > 3.5:
		_set_state(State.CHASE)          # you shouted or bolted in the middle of the conversation
		return
	if talk_t < talk_dur:
		return
	var c := mind.talk_context(target.display_name)
	match talk_outcome:
		"spare":
			_all("say", [ShadowTalk.outcome_line("spare", c)])
			ignore_until = Time.get_ticks_msec() + 12000
			dest = patrol_points.pick_random()
			style = "stalk"
			_set_state(State.PATROL)
		"punish":
			_all("say", [ShadowTalk.outcome_line("punish", c)])
			_set_state(State.CHASE)
		_:
			_all("say", [ShadowTalk.outcome_line("toy", c)])
			_set_state(State.STARE)


# ------------------------------------------------------------------ horror tricks (called by ShadowMind)
func trick_appear(secs: float) -> void:
	if not (state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]):
		return
	if aggression < 0.25 and randf() > 0.35:
		return
	var ps := _alive_players()
	if ps.is_empty():
		return
	var p = ps.pick_random()
	await get_tree().create_timer(0.6).timeout          # lights die... then he is just THERE
	if state == State.KILLING or not is_instance_valid(p) or not p.alive:
		return
	var fwd: Vector3 = -p.global_transform.basis.z
	var spot := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p.global_position + fwd * 8.0)
	global_position = Vector3(spot.x, 0.0, spot.z)
	look_at(Vector3(p.global_position.x, global_position.y, p.global_position.z), Vector3.UP)
	target = p
	_set_state(State.STARE)


func trick_peek() -> void:
	if not (state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]):
		return
	var ps := _alive_players()
	if ps.is_empty():
		return
	var p = ps.pick_random()
	var fwd: Vector3 = -p.global_transform.basis.z
	dest = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p.global_position + fwd * 14.0)
	hold_t = 7.0
	style = "stalk"
	_set_state(State.PATROL)


@rpc("authority", "call_local", "reliable")
func fx_steps(pid: int) -> void:
	if Game.my_id() != pid:
		return
	var lp = Game.local_player
	if lp == null or not is_instance_valid(lp):
		return
	var snd := AudioStreamPlayer3D.new()
	snd.stream = ProcAudio.get_sound("thud")
	snd.unit_size = 6.0
	snd.volume_db = 4.0
	get_tree().current_scene.add_child(snd)
	var back: Vector3 = lp.global_transform.basis.z
	for i in 5:
		if not is_instance_valid(lp):
			break
		snd.global_position = lp.global_position + back * (9.0 - i * 1.6) + Vector3(0, 0.1, 0)
		snd.pitch_scale = randf_range(0.8, 1.1)
		snd.play()
		await get_tree().create_timer(0.55).timeout
	snd.queue_free()


func _on_freeze(secs: float) -> void:
	script_mode = true
	state = State.STARE
	get_tree().create_timer(secs).timeout.connect(func(): script_mode = false)


func _on_door_failed(pid: int) -> void:
	var p := _find_player(pid)
	if p != null:
		script_mode = false
		_start_kill(p, "reach_through")


# ------------------------------------------------------------------ she is mostly NOT seen
func flash(pos: Vector3, secs: float) -> void:
	global_position = pos
	var lp = Game.local_player
	if lp != null and is_instance_valid(lp):
		look_at(Vector3(lp.global_position.x, pos.y, lp.global_position.z), Vector3.UP)
	_flash_t = secs


func fade_out(secs: float) -> void:
	_fade_total = secs
	_fade_t = secs


func _vis_alpha() -> float:
	var a := 0.0
	var lp = Game.local_player
	var d := 99.0
	if lp != null and is_instance_valid(lp):
		d = global_position.distance_to(lp.global_position)
	if Game.reveal_level >= 4:
		a = 1.0
	elif Game.camera_on and d < 14.0:
		a = 0.75                                  # only the lens can see her
	elif _flash_t > 0.0:
		a = 0.55                                  # a shadow at the end of the hall
	elif Game.reveal_level >= 3 and d < 9.0:
		a = 0.15 + 0.12 * sin(Time.get_ticks_msec() / 90.0)
	elif state == State.KILLING:
		a = 1.0
	if _fade_t > 0.0:
		a *= _fade_t / _fade_total
	return a
