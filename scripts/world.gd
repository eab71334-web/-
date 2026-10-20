extends Node3D
## Game scene root: builds level, spawns players + monster, atmosphere, HUD.

var info: Dictionary
var door: Node
var heart: AudioStreamPlayer


func _ready() -> void:
	Game.objective_changed.connect(_on_objective)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	info = LevelBuilder.build(self)
	door = info["door"]
	_add_environment()
	_add_audio()
	_spawn_players()
	add_child(Hud.new())
	Game.touch_mode = OS.has_feature("mobile")
	if Game.touch_mode:
		add_child(TouchControls.new())
	Game.objective_changed.emit(Game.OBJECTIVES[Game.step])
	var region: NavigationRegion3D = info["region"]
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var m := Monster.new()
	m.name = "Monster"
	m.position = Vector3(0, 0, -13)
	m.patrol_points = info["patrol_points"]
	add_child(m)


func _spawn_players() -> void:
	var ids: Array = Net.names.keys()
	ids.sort()
	for i in ids.size():
		var p := Player.new()
		p.name = str(ids[i])
		p.display_name = Net.names[ids[i]]
		p.position = info["spawns"][i % 4]
		add_child(p)


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.045
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
	var drone := AudioStreamPlayer.new()
	drone.stream = ProcAudio.get_sound("drone")
	drone.volume_db = -12.0
	add_child(drone)
	drone.play()
	heart = AudioStreamPlayer.new()
	heart.stream = ProcAudio.get_sound("heart")
	heart.volume_db = -60.0
	add_child(heart)
	heart.play()


func _process(delta: float) -> void:
	heart.volume_db = lerpf(-60.0, -3.0, Game.threat)
	heart.pitch_scale = 0.9 + Game.threat * 0.9
	# lights flicker / die more the closer the monster is
	var chaos := 0.05 + Game.threat * 0.5
	for l in get_tree().get_nodes_in_group("lamps"):
		var base: float = l.get_meta("base")
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
	if Game.step >= Game.Step.EXIT and is_instance_valid(door):
		door.queue_free()   # the heavy door opens


func _on_peer_left(id: int) -> void:
	var n := get_node_or_null(str(id))
	if n:
		n.queue_free()
