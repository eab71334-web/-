extends Node3D
## Game scene root: builds level, spawns players + monster, atmosphere, HUD.

var info: Dictionary
var door: Node
var heart: AudioStreamPlayer
var drone: AudioStreamPlayer
var siren: AudioStreamPlayer
var finale: FinalStare
var hud: Hud
var _booted := false
var _cs_cam: Camera3D
var _was_quiet := false


func _ready() -> void:
	Game.objective_changed.connect(_on_objective)
	Game.door_opened.connect(_on_door_opened)
	Game.item_added.connect(_on_item)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	info = LevelBuilder.build(self)
	door = info["door"]
	_add_environment()
	_add_audio()
	_spawn_players()
	hud = Hud.new()
	add_child(hud)
	hud.title_card("الليلة %d" % Game.night, "٣:٠٧ فجراً")
	Game.game_won.connect(_on_won)
	Game.final_stare_requested.connect(_on_final)
	Game.touch_mode = OS.has_feature("mobile")
	if Game.touch_mode:
		add_child(TouchControls.new())
	Game.objective_changed.emit(Game.OBJECTIVES[Game.step])
	_booted = true
	var region: NavigationRegion3D = info["region"]
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var m := Monster.new()
	m.name = "Monster"
	m.position = Vector3(0, 0, -8)
	m.patrol_points = info["patrol_points"]
	add_child(m)
	m.rotation.y = PI                                        # faces you: you SEE him at the start
	m.ignore_until = Time.get_ticks_msec() + 10000           # 10 s grace: he will not spot you yet
	m.hold_t = 5.0
	m.dest = m.position
	m._set_state(0)
	if Game.has_flag("door_archive"):
		m.patrol_points.append_array(_wing_points())


func _spawn_players() -> void:
	var ids: Array = Net.names.keys()
	ids.sort()
	for i in ids.size():
		var p := Player.new()
		p.name = str(ids[i])
		p.display_name = Net.names[ids[i]]
		p.position = info["spawns"][i % 4]
		add_child(p)
	if Game.has_resume_pos and Game.solo and get_node_or_null("1") != null:
		get_node("1").position = Game.resume_pos      # continue from the last checkpoint
		Game.has_resume_pos = false


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.14, 0.18)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.03
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _add_audio() -> void:
	drone = AudioStreamPlayer.new()
	drone.stream = ProcAudio.get_sound("drone")
	drone.volume_db = -12.0
	add_child(drone)
	drone.play()
	siren = AudioStreamPlayer.new()
	siren.stream = ProcAudio.get_sound("alarm")
	siren.volume_db = -8.0
	add_child(siren)
	heart = AudioStreamPlayer.new()
	heart.stream = ProcAudio.get_sound("heart")
	heart.volume_db = -60.0
	add_child(heart)
	heart.play()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var quiet := now < Game.silence_until            # silence before the scare
	drone.volume_db = lerpf(drone.volume_db, -60.0 if quiet else -12.0, minf(delta * 4.0, 1.0))
	heart.volume_db = -60.0 if quiet else lerpf(-60.0, -3.0, Game.threat)
	heart.pitch_scale = 0.9 + Game.threat * 0.9
	if _was_quiet and not quiet:
		_boom()
	_was_quiet = quiet
	var dark := now < Game.blackout_until
	if Game.alarm and not siren.playing:
		siren.play()
	# lights flicker / die more the closer the monster is
	var chaos := 0.05 + Game.threat * 0.5 + (0.9 if now < Game.chaos_until else 0.0)
	for l in get_tree().get_nodes_in_group("lamps"):
		var base: float = l.get_meta("base")
		if dark:
			l.light_energy = 0.0
			continue
		if Game.alarm:
			l.light_color = Color(1.0, 0.08, 0.05)
			l.light_energy = base * (0.5 + 1.2 * absf(sin(now / 220.0)))
			continue
		var dead: float = l.get_meta("dead", 0.0)
		if dead <= 0.0 and randf() < chaos * delta * 4.0:
			dead = randf_range(0.05, 0.3)
		if dead > 0.0:
			dead -= delta
			l.light_energy = base * randf_range(0.0, 0.25)
		else:
			l.light_energy = lerpf(l.light_energy, base, minf(delta * 10.0, 1.0))
		l.set_meta("dead", dead)


func _on_objective(_t: String) -> void:
	if _booted:
		if Game.CHAPTERS.has(Game.step):
			var ch: Array = Game.CHAPTERS[Game.step]
			hud.title_card(ch[0], ch[1])
		if Game.step == Game.Step.LEVER:
			_cs_power()
		elif Game.step == Game.Step.WHEEL:
			_cs_morgue()
	if Game.step == Game.Step.WHEEL:
		_ring_loop()
	if Game.step == Game.Step.EXIT:
		Game.alarm = true
	if Game.step >= Game.Step.EXIT and is_instance_valid(door):
		door.queue_free()   # the heavy door opens


func _on_peer_left(id: int) -> void:
	var n := get_node_or_null(str(id))
	if n:
		n.queue_free()


func _boom() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = ProcAudio.get_sound("thud")
	p.volume_db = 6.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _on_won() -> void:
	Game.ending_kind = "true" if Game.notes_found.size() >= Game.NOTES.size() else "normal"
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/ending.tscn")


## The phone in B-13 rings (and the whole basement hears it) until you answer.
func _ring_loop() -> void:
	while Game.step == Game.Step.WHEEL and not Game.finished:
		if finale == null or not finale._running:
			var p := AudioStreamPlayer3D.new()
			p.stream = ProcAudio.get_sound("ring")
			p.unit_size = 10.0
			p.max_distance = 60.0
			p.volume_db = 8.0
			add_child(p)
			p.global_position = Game.PHONE_POS + Vector3(0, 1, 0)
			p.play()
			p.finished.connect(p.queue_free)
			if Game.is_host():
				Game.fire("make_noise", [Game.PHONE_POS, 1.0])
		await get_tree().create_timer(4.0).timeout


func _on_final(pid: int) -> void:
	if not Game.is_host():
		return
	var p = get_node_or_null(str(pid))
	var m = get_node_or_null("Monster")
	if p == null or m == null:
		return
	if finale == null:
		finale = FinalStare.new()
		add_child(finale)
	finale.start(p, m)


func _wing_points() -> Array:
	return [Vector3(0, 0, 24), Vector3(-10, 0, 40), Vector3(10, 0, 30), Vector3(14, 0, 42)]


func _on_door_opened() -> void:
	var region: NavigationRegion3D = info["region"]
	region.bake_navigation_mesh(true)          # the monster can now walk through the opened door
	var m = get_node_or_null("Monster")
	if m != null and Game.has_flag("door_archive"):
		for pt in _wing_points():
			if not m.patrol_points.has(pt):
				m.patrol_points.append(pt)


func _on_item(id: String) -> void:
	var lp = Game.local_player
	if lp != null and is_instance_valid(lp) and lp.vm != null:
		lp.vm.show_item(id)


# ------------------------------------------------------------------ in-engine cut-scenes
func _cs_begin() -> bool:
	if Game.local_player == null or not is_instance_valid(Game.local_player):
		return false
	Game.typing = true
	hud.bars(true)
	return true


func _cs_end() -> void:
	Game.typing = false
	hud.bars(false)
	hud.cctv(false)
	if is_instance_valid(_cs_cam):
		if Game.local_player != null and is_instance_valid(Game.local_player):
			Game.local_player.cam.make_current()
		_cs_cam.queue_free()


func _calm(m) -> bool:
	return m != null and Game.is_host() and (m.state == 0 or m.state == 1 or m.state == 4)


## Power returns: security-camera shot of the hall. The Shadow walks in, stops, turns to the lens. Lights die. Gone.
func _cs_power() -> void:
	if Game.has_flag("cs_power") or not _cs_begin():
		return
	Game.set_flag("cs_power")
	_cs_cam = Camera3D.new()
	_cs_cam.fov = 62.0
	add_child(_cs_cam)
	_cs_cam.global_position = Vector3(-19.0, 3.0, 7.4)
	_cs_cam.look_at(Vector3(3.0, 1.0, -3.0))
	_cs_cam.make_current()
	hud.cctv(true, "CAM 03   03:07:12   ● REC")
	Game.chaos_until = Time.get_ticks_msec() + 3000
	Util.play(self, "static", -6.0)
	var m = get_node_or_null("Monster")
	await get_tree().create_timer(2.4).timeout
	if _calm(m):
		m.script_mode = true
		m.state = 0
		m.style = "stalk"
		m.global_position = Vector3(2.0, 0.0, -7.0)
		m.look_at(Vector3(2.0, 0.0, 8.0), Vector3.UP)
		var tw := create_tween()
		tw.tween_property(m, "global_position", Vector3(2.0, 0.0, -1.0), 3.2)
		await tw.finished
		m.state = 3
		m.look_at(Vector3(-19.0, 0.0, 7.4), Vector3.UP)
		Util.play(self, "sting", -2.0)
		await get_tree().create_timer(1.8).timeout
	else:
		await get_tree().create_timer(2.0).timeout
	Game.blackout_until = Time.get_ticks_msec() + 1200
	Util.play(self, "slam", -6.0)
	if _calm(m) or (m != null and m.script_mode):
		m.global_position = Vector3(0.0, 0.0, -14.0)
		m.script_mode = false
		m._set_state(0)
		m._pick_patrol()
	await get_tree().create_timer(1.5).timeout
	_cs_end()


## Safe opens: drawer 13 slides out by itself, lights flicker, the camera punches in.
func _cs_morgue() -> void:
	if Game.has_flag("cs_morgue") or not _cs_begin():
		return
	Game.set_flag("cs_morgue")
	_cs_cam = Camera3D.new()
	_cs_cam.fov = 58.0
	add_child(_cs_cam)
	_cs_cam.global_position = Vector3(11.0, 1.6, 40.0)
	_cs_cam.look_at(Vector3(19.0, 1.0, 42.0))
	_cs_cam.make_current()
	await get_tree().create_timer(1.0).timeout
	Util.play(self, "creak", -2.0)
	var d = info.get("drawer")
	if d != null and is_instance_valid(d):
		create_tween().tween_property(d, "position:x", d.position.x - 1.4, 2.2)
	Game.chaos_until = Time.get_ticks_msec() + 3500
	await get_tree().create_timer(2.6).timeout
	Util.play(self, "sting", 0.0)
	create_tween().tween_property(_cs_cam, "fov", 44.0, 0.25)
	await get_tree().create_timer(1.8).timeout
	_cs_end()
