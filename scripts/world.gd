extends Node3D
## Game scene root: builds level, spawns players + monster, shows HUD.

var info: Dictionary
var door: Node


func _ready() -> void:
	Game.objective_changed.connect(_on_objective)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	info = LevelBuilder.build(self)
	door = info["door"]
	_add_environment()
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
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _on_objective(_t: String) -> void:
	if Game.step >= Game.Step.EXIT and is_instance_valid(door):
		door.queue_free()   # the heavy door opens


func _on_peer_left(id: int) -> void:
	var n := get_node_or_null(str(id))
	if n:
		n.queue_free()
