extends Node3D
## Game scene root: the farmhouse, the family, the investigator's tools, the ghost and her haunting.

var info: Dictionary
var hud: Hud
var finale: Ritual
var monster
var drone: AudioStreamPlayer
var wind: AudioStreamPlayer
var heart: AudioStreamPlayer
var _booted := false
var _cs_cam: Camera3D


func _ready() -> void:
	Game.objective_changed.connect(_on_objective)
	Game.door_opened.connect(_on_door_opened)
	Game.item_added.connect(_on_item)
	Game.game_won.connect(_on_won)
	Game.ritual_requested.connect(_on_ritual)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	info = HouseBuilder.build(self)
	_add_environment()
	_add_audio()
	_spawn_players()
	hud = Hud.new()
	add_child(hud)
	Game.touch_mode = OS.has_feature("mobile")
	if Game.touch_mode:
		add_child(TouchControls.new())
	add_child(QuestDirector.new())
	add_child(HauntDirector.new())
	_entry_trigger()
	Game.objective_changed.emit(Game.OBJECTIVES[Game.step])
	_booted = true
	hud.title_card("بيت الصفصاف", "الليلة %d" % Game.night)
	if not Game.has_flag("arrived"):
		Game.set_flag("arrived")
		_cs_arrival()
	var region: NavigationRegion3D = info["region"]
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_ghost()


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


func _spawn_ghost() -> void:
	var m := Monster.new()
	m.name = "Monster"
	m.patrol_points = info["patrol_points"]
	m.position = Vector3(0, 40, 0)
	add_child(m)
	monster = m
	if Game.has_flag("door_attic"):
		m.patrol_points.append_array(info["attic_points"])
	_apply_phase()


## Before the investigation heats up she only haunts (events). From PAGES on she can hunt you.
func _apply_phase() -> void:
	if monster == null:
		return
	if Game.hunt_enabled():
		if monster.script_mode and monster.global_position.y > 30.0:
			monster.global_position = Vector3(0.0, 4.0, -8.0)      # she starts in the upper hall
			monster._set_state(0)
			monster._pick_patrol()
		if finale == null or not finale._running:
			monster.script_mode = false
	else:
		monster.script_mode = true


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.015, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.11, 0.16)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.07)
	env.fog_density = 0.02
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.3
	moon.rotation_degrees = Vector3(-55, 40, 0)
	add_child(moon)


func _add_audio() -> void:
	drone = AudioStreamPlayer.new()
	drone.stream = ProcAudio.get_sound("drone")
	drone.volume_db = -16.0
	add_child(drone)
	drone.play()
	wind = AudioStreamPlayer.new()
	wind.stream = ProcAudio.get_sound("hiss")
	wind.volume_db = -34.0
	add_child(wind)
	wind.play()
	heart = AudioStreamPlayer.new()
	heart.stream = ProcAudio.get_sound("heart")
	heart.volume_db = -60.0
	add_child(heart)
	heart.play()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dark := now < Game.blackout_until
	heart.volume_db = lerpf(-60.0, -3.0, Game.threat)
	heart.pitch_scale = 0.9 + Game.threat * 0.9
	var power := Game.step >= Game.Step.EVIDENCE            # the fuse box in the cellar brings the lights back
	var chaos := 0.03 + Game.threat * 0.4 + (0.9 if now < Game.chaos_until else 0.0)
	for l in get_tree().get_nodes_in_group("lamps"):
		var base: float = l.get_meta("base")
		var always: bool = l.get_meta("always", false)
		if dark or (not power and not always):
			l.light_energy = 0.0
			continue
		if always:
			l.light_energy = base * (0.8 + 0.2 * sin(now / 130.0 + l.global_position.x))     # candles
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


# ------------------------------------------------------------------ story events
func _on_objective(_t: String) -> void:
	_apply_phase()
	if _booted and Game.CHAPTERS.has(Game.step):
		var ch: Array = Game.CHAPTERS[Game.step]
		hud.title_card(ch[0], ch[1])


func _entry_trigger() -> void:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = Vector3(0, 1.0, 7.6)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 2.0, 2.0)
	cs.shape = bs
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_on_entry)


## Classic: the moment you step inside, the front door slams shut behind you and will not open again.
func _on_entry(b) -> void:
	if not b.is_in_group("players") or not Game.is_mine(b) or Game.has_flag("entered"):
		return
	Game.set_flag("entered")
	var front = info["front"]
	if front != null and is_instance_valid(front):
		front.slam_shut()
		front.locked_flag = "front_open"
	Game.subtitle.emit("الباب انغلق خلفك…")


func _cs_arrival() -> void:
	var lp = Game.local_player
	if lp == null or not is_instance_valid(lp):
		return
	Game.typing = true
	hud.bars(true)
	_cs_cam = Camera3D.new()
	_cs_cam.fov = 60.0
	add_child(_cs_cam)
	_cs_cam.global_position = Vector3(8.0, 2.4, 44.0)
	_cs_cam.look_at(Vector3(0.0, 4.5, 0.0))
	_cs_cam.make_current()
	var tw := create_tween()
	tw.tween_property(_cs_cam, "global_position", Vector3(1.0, 1.9, 33.0), 6.0)
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(lp):
		lp.cam.make_current()
	if is_instance_valid(_cs_cam):
		_cs_cam.queue_free()
	hud.bars(false)
	Game.typing = false
	var msg := "هنا الشاحنة. ادخل وقابل العائلة في غرفة المعيشة أولاً. وانتبه لبطاريتك: الكشاف والكاميرا والمسجّل يتشاركونها."
	Game.subtitle.emit("[الراديو • الدكتورة رنا] " + msg)
	Util.speak(msg, 1.2, 0.95)


func _on_door_opened() -> void:
	var region: NavigationRegion3D = info["region"]
	region.bake_navigation_mesh(true)          # the ghost can now use the opened door
	if monster != null and Game.has_flag("door_attic"):
		for pt in info["attic_points"]:
			if not monster.patrol_points.has(pt):
				monster.patrol_points.append(pt)


func _on_item(id: String) -> void:
	var lp = Game.local_player
	if lp != null and is_instance_valid(lp) and lp.vm != null:
		lp.vm.show_item(id)


func _on_ritual(pid: int) -> void:
	if not Game.is_host():
		return
	var p = get_node_or_null(str(pid))
	if p == null or monster == null:
		return
	if finale == null:
		finale = Ritual.new()
		add_child(finale)
	finale.start(p, monster)


func _on_won() -> void:
	Game.ending_kind = "true" if Game.notes_found.size() >= Game.NOTES.size() else "normal"
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/ending.tscn")


func _on_peer_left(id: int) -> void:
	var n := get_node_or_null(str(id))
	if n:
		n.queue_free()
