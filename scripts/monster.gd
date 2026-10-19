extends CharacterBody3D
class_name Monster
## Adaptive stalker. The AI runs on the server only; clients just see replicated position.
## States: PATROL -> (hear) INVESTIGATE -> SEARCH_HIDE -> CONFRONT (stands on your hiding spot)
##         PATROL -> (sees you) STARE for 7 s -> CHASE if you move or make noise -> KILL
## Learning: remembers where it saw you, which crates you hid behind, and gets angrier every time you survive a stare.

enum State { PATROL, INVESTIGATE, CHASE, STARE, SEARCH_HIDE, CONFRONT, KILLING }

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
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.5
	bm.height = 2.2
	bm.material = Util.mat(Color(0.02, 0.02, 0.03))
	body.mesh = bm
	body.position.y = 1.1
	add_child(body)
	eyes = Node3D.new()
	eyes.position = Vector3(0, 1.9, -0.35)
	add_child(eyes)
	for x in [-0.15, 0.15]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		sm.material = Util.mat(Color(1, 0.05, 0.05), true)
		e.mesh = sm
		e.position = Vector3(x, 0, 0)
		eyes.add_child(e)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.1, 0.1)
	glow.light_energy = 0.4
	glow.omni_range = 4.0
	eyes.add_child(glow)

	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation"]:
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

	if not multiplayer.is_server():
		return
	hide_zones = get_tree().get_nodes_in_group("hide_zones")
	Game.noise_made.connect(_on_noise)
	Game.objective_changed.connect(_on_objective)
	_pick_patrol()


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or state == State.KILLING or Game.finished:
		return
	_learn(delta)
	if state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE]:
		name_cd -= delta
		if name_cd <= 0.0:
			name_cd = randf_range(12.0, 25.0)
			var ps := _alive_players()
			if not ps.is_empty():
				call_name.rpc(ps.pick_random().display_name)
	match state:
		State.PATROL: _patrol(delta)
		State.INVESTIGATE: _investigate(delta)
		State.SEARCH_HIDE: _search_hide(delta)
		State.STARE: _stare(delta)
		State.CHASE: _chase(delta)
		State.CONFRONT: _confront(delta)


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
			if trail_timer <= 0.0:
				player_trail.append(p.global_position)
				if player_trail.size() > 24:
					player_trail.pop_front()
		elif p.hidden and seen_t.has(p.name) and now - seen_t[p.name] < 6000:
			var z := _nearest_zone(seen_pos[p.name])
			if z != null:
				z.score += 1.0     # "this one gets used" -> checked more often
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
	dir.y = 0.0
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
			_start_investigate(p.global_position)
			return
	if _move_to(dest, PATROL_SPEED, delta):
		_pick_patrol()


func _on_spotted(p: Player) -> void:
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
		_set_state(State.CHASE)      # you moved or made noise: he attacks at once
		return
	timer -= delta
	if timer <= 0.0:                  # you survived the stare
		aggression = minf(aggression + 0.15, 1.0)
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
	_move_to(last_known, CHASE_SPEED * (1.0 + aggression * 0.15), delta)


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
	if _move_to(current_zone.global_position + Vector3(0, 0, 2.0), PATROL_SPEED, delta) \
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
	_confront_ui.rpc(vid, true)
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
			call_name.rpc(v.display_name)
	if timer <= 0.0:
		var suspicion := 0.25 + current_zone.score * 0.2 + aggression * 0.3
		_end_confront(v != null and v.alive and v.hidden and (confront_noise > 0.4 or randf() < suspicion))


func _end_confront(kill: bool) -> void:
	_confront_ui.rpc(-1, false)
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
	if state in [State.PATROL, State.INVESTIGATE, State.SEARCH_HIDE] \
			and global_position.distance_to(pos) < loudness * 30.0:
		_start_investigate(pos)


func _on_objective(_t: String) -> void:
	if Game.step == Game.Step.EXIT:       # wheel finished: he charges the nearest player
		var best: Player = null
		for p in _alive_players():
			if best == null or global_position.distance_to(p.global_position) < global_position.distance_to(best.global_position):
				best = p
		if best != null:
			target = best
			last_known = best.global_position
			_set_state(State.CHASE)


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
func _start_kill(victim: Player) -> void:
	state = State.KILLING
	var kind := "intercept_slam"
	if victim.hidden:
		kind = ["crush_crate", "reach_through"].pick_random()
	elif victim.posture == Player.Posture.CRAWL:
		kind = "stomp_lift"
	play_kill.rpc(str(victim.name).to_int(), kind, randi())


@rpc("authority", "call_local", "reliable")
func call_name(n: String) -> void:
	Game.whisper(n, randf_range(0.2, 0.5), randf_range(0.55, 0.8))


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
	v.on_killed_start()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var ang := rng.randf() * TAU
	var side := Vector3(sin(ang), 0.0, cos(ang))
	var mine := is_multiplayer_authority()        # server moves the monster
	var vmine := v.is_multiplayer_authority()     # victim's own peer moves the victim
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
