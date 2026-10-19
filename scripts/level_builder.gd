class_name LevelBuilder
## Builds the basement procedurally (no hand-made scene needed).
## Layout (top view, -Z = north):
##   north: exit room + heavy door | middle: big hall | south: generator room (W), control room (E)

const H := 3.5
const WALL := Color(0.16, 0.16, 0.18)


static func build(root: Node3D) -> Dictionary:
	var region := NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.8
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	region.navigation_mesh = nm
	root.add_child(region)

	Util.box(region, Vector3(0, -0.1, -4), Vector3(44, 0.2, 52), Color(0.1, 0.1, 0.11))
	var ceil_mi := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(42, 0.2, 42)
	cm.material = Util.mat(Color(0.05, 0.05, 0.06))
	ceil_mi.mesh = cm
	ceil_mi.position = Vector3(0, 3.6, 0)
	root.add_child(ceil_mi)

	# outer walls
	_wall(region, 0, 20.25, 41, 0.5)
	_wall(region, -20.25, 0, 0.5, 41)
	_wall(region, 20.25, 0, 0.5, 41)
	_wall(region, -11.25, -20.25, 18.5, 0.5)
	_wall(region, 11.25, -20.25, 18.5, 0.5)
	var door := Util.box(region, Vector3(0, H / 2.0, -20.25), Vector3(4, H, 0.5), Color(0.25, 0.05, 0.05))
	# inner walls
	_wall(region, -11.5, -8, 17, 0.5)
	_wall(region, 11.5, -8, 17, 0.5)
	_wall(region, -17, 8, 6, 0.5)
	_wall(region, 0, 8, 20, 0.5)
	_wall(region, 17, 8, 6, 0.5)
	_wall(region, 0, 10, 0.5, 4)
	_wall(region, 0, 18, 0.5, 4)
	_wall(region, -9, -2, 6, 0.5)
	_wall(region, 9, 2, 6, 0.5)

	# hiding spots
	for p in [Vector3(-15, 0, -4), Vector3(14, 0, -4), Vector3(-3, 0, 5), Vector3(15, 0, 4),
			Vector3(-14, 0, -14), Vector3(13, 0, -13), Vector3(-7, 0, 15), Vector3(7, 0, 15), Vector3(-17, 0, 11)]:
		_hide_zone(root, region, p)

	# objectives
	_interactable(root, Vector3(-17.5, 1.0, 17), Game.Step.GENERATOR, 1.5, 1.0, "شغّل المولد", Color(1.0, 0.7, 0.1), false)
	_interactable(root, Vector3(17.5, 1.0, 17), Game.Step.LEVER, 1.0, 0.4, "اسحب ذراع الطوارئ", Color(0.2, 0.8, 1.0), false)
	_interactable(root, Vector3(0, 1.3, -19.3), Game.Step.WHEEL, Game.wheel_time, 0.6, "أدِر العجلة الهيدروليكية", Color(0.9, 0.2, 0.2), true)

	var ez := ExitZone.new()
	ez.position = Vector3(0, 1.0, -23)
	var ecs := CollisionShape3D.new()
	var ebs := BoxShape3D.new()
	ebs.size = Vector3(8, 3, 4)
	ecs.shape = ebs
	ez.add_child(ecs)
	root.add_child(ez)
	_lamp(root, Vector3(0, 2.5, -23), Color(0.2, 1.0, 0.4), 1.5)

	for p in [Vector3(0, 3, 0), Vector3(-10, 3, 14), Vector3(10, 3, 14), Vector3(0, 3, -14)]:
		_lamp(root, p, Color(0.8, 0.75, 0.6), 0.5)

	return {
		"region": region,
		"door": door,
		"spawns": [Vector3(-3, 0.05, 4), Vector3(-1, 0.05, 4), Vector3(1, 0.05, 4), Vector3(3, 0.05, 4)],
		"patrol_points": [Vector3(0, 0, 0), Vector3(-12, 0, 0), Vector3(12, 0, 0), Vector3(0, 0, -14),
			Vector3(-12, 0, -14), Vector3(12, 0, -14), Vector3(-10, 0, 14), Vector3(10, 0, 14),
			Vector3(-16, 0, 16), Vector3(16, 0, 16), Vector3(0, 0, 6)],
	}


static func _wall(parent: Node, x: float, z: float, sx: float, sz: float) -> void:
	Util.box(parent, Vector3(x, H / 2.0, z), Vector3(sx, H, sz), WALL)


static func _lamp(parent: Node, pos: Vector3, c: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = 12.0
	parent.add_child(l)


static func _hide_zone(root: Node, region: Node, pos: Vector3) -> void:
	var z := HideZone.new()
	z.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 2.0, 3.2)
	cs.shape = bs
	cs.position.y = 1.0
	z.add_child(cs)
	root.add_child(z)
	var wood := Color(0.35 + randf() * 0.1, 0.22, 0.1)
	for dx in [-1.1, 0.0, 1.1]:
		z.crates.append(Util.box(region, pos + Vector3(dx, 0.55, -1.3), Vector3(1.1, 1.1, 1.1), wood))
	z.crates.append(Util.box(region, pos + Vector3(-0.55, 1.65, -1.3), Vector3(1, 1, 1), wood))
	z.crates.append(Util.box(region, pos + Vector3(1.4, 0.5, 0.0), Vector3(1, 1, 1), wood))


static func _interactable(root: Node, pos: Vector3, step_i: int, hold: float, noise: float, text: String, c: Color, wheel: bool) -> void:
	var a := Interactable.new()
	a.position = pos
	a.step_index = step_i
	a.hold_time = hold
	a.noise = noise
	a.label = text
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3, 2.5, 3)
	cs.shape = bs
	a.add_child(cs)
	var pivot := Node3D.new()
	var mi := MeshInstance3D.new()
	if wheel:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.35
		tm.outer_radius = 0.55
		tm.material = Util.mat(c, true)
		mi.mesh = tm
		mi.rotation_degrees.x = 90
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.9, 0.12)
		bm.material = Util.mat(c, true)
		mi.mesh = bm
		mi.position.y = 0.45
	pivot.add_child(mi)
	a.add_child(pivot)
	a.visual = pivot
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 0.8
	l.omni_range = 5.0
	l.position.y = 1.0
	a.add_child(l)
	root.add_child(a)
