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
	# south wall has a gate to the Archive wing: a LockedDoor that needs the archive key
	_wall(region, -11.25, 20.25, 18.5, 0.5)
	_wall(region, 11.25, 20.25, 18.5, 0.5)
	_locked_door(root, region, "archive", Vector3(0, H / 2.0, 20.25), Vector3(4, H, 0.5), "key_archive")
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
			Vector3(-9, 0, -14), Vector3(13, 0, -13), Vector3(-7, 0, 15), Vector3(7, 0, 15), Vector3(-17, 0, 11)]:
		_hide_zone(root, region, p)

	# objectives
	_interactable(root, Vector3(-17.5, 1.0, 17), Game.Step.GENERATOR, 1.5, 1.0, "لوحة المصاهر", Color(1.0, 0.7, 0.1), false, "fuse")
	_interactable(root, Vector3(17.5, 1.0, 17), Game.Step.LEVER, 1.0, 0.4, "لوحة رمز الطوارئ", Color(0.2, 0.8, 1.0), false, "keypad")
	_interactable(root, Vector3(-18.0, 1.0, -14.0), Game.Step.WHEEL, 0.0, 0.0, "أجب على الهاتف", Color(0.9, 0.2, 0.2), false, "phone")
	_phone_prop(root, region)

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

	_props(root, region)
	_interactable(root, Vector3(18.0, 1.0, -1.0), -1, 0.0, 0.0, "شغّل التلفاز", Color(0.5, 0.7, 1.0), false, "tv")
	_tv_prop(root, region)
	_tape(root, Vector3(-18.0, 0.1, -11.0))
	# room B-13 (the phone room): closed, its door needs the B-13 key
	_wall(region, -17.75, -16.5, 4.5, 0.5)
	_wall(region, -17.75, -11.5, 4.5, 0.5)
	_wall(region, -15.5, -15.75, 0.5, 1.5)
	_wall(region, -15.5, -12.25, 0.5, 1.5)
	_locked_door(root, region, "b13", Vector3(-15.5, H / 2.0, -14.0), Vector3(0.5, H, 2.0), "key_b13")
	Util.box(region, Vector3(-17.2, 0.25, -12.7), Vector3(2.0, 0.5, 0.9), Color(0.25, 0.25, 0.27))   # iron bed
	# the archive key sits on a cabinet in the control room (appears after the keypad is solved)
	Util.box(region, Vector3(14.0, 0.4, 19.3), Vector3(1.4, 0.8, 0.7), Color(0.2, 0.14, 0.1))
	_item_pickup(root, Vector3(14.0, 0.95, 18.9), "key_archive", Game.Step.ARCHIVE)
	var drawer := _wing_south(root, region)
	var note_spots := [Vector3(-4, 0.1, 0), Vector3(14, 0.1, 15), Vector3(-14, 0.1, 19), Vector3(9, 0.1, -15), Vector3(3, 0.1, -17.5), Vector3(-8, 0.1, 12), Vector3(0, 0.1, 27), Vector3(12, 0.1, 44)]
	for i in note_spots.size():
		_note(root, note_spots[i], i)

	return {
		"region": region,
		"door": door,
		"drawer": drawer,
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
	l.add_to_group("lamps")
	l.set_meta("base", energy)
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


static func _interactable(root: Node, pos: Vector3, step_i: int, hold: float, noise: float, text: String, c: Color, wheel: bool, puzzle := "") -> void:
	var a: Interactable = PuzzleStation.new() if puzzle != "" else Interactable.new()
	if puzzle != "":
		a.set("kind", puzzle)
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


static func _props(root: Node, region: Node) -> void:
	for p in [Vector3(-18, 0, -18), Vector3(17.5, 0, -18), Vector3(-18.5, 0, 6.5), Vector3(18.5, 0, -6.5),
			Vector3(5, 0, -4.5), Vector3(-19, 0, 19), Vector3(19, 0, 19), Vector3(-4, 0, 19)]:
		Util.barrel(region, p)
	var pipe := Util.mat(Color(0.08, 0.08, 0.09))
	for z in [-14.0, -4.0, 4.0, 13.0, 18.0]:
		Util.mesh(root, Util.cyl(0.12, 40.0), pipe, Vector3(0, 3.2, z), Vector3(0, 0, PI / 2.0))
	var blood := Util.mat(Color(0.28, 0.015, 0.015))
	blood.roughness = 0.25
	for b in [Vector3(-14, 0.02, -6), Vector3(-2, 0.02, 6.5), Vector3(12, 0.02, -2),
			Vector3(-6, 0.02, 12), Vector3(1, 0.02, -17), Vector3(8, 0.02, 13)]:
		var q := QuadMesh.new()
		q.size = Vector2(randf_range(1.2, 2.4), randf_range(1.5, 3.0))
		Util.mesh(root, q, blood, b, Vector3(-PI / 2.0, randf() * TAU, 0.0))


static func _note(root: Node, pos: Vector3, idx: int) -> void:
	var n := LoreNote.new()
	n.idx = idx
	n.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 2.0, 2.4)
	cs.shape = bs
	n.add_child(cs)
	Util.mesh(n, Util.bmesh(Vector3(0.32, 0.015, 0.42)), Util.mat(Color(0.9, 0.85, 0.65), true), Vector3.ZERO, Vector3(0, randf() * TAU, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.9, 0.6)
	l.light_energy = 0.35
	l.omni_range = 3.0
	l.position.y = 0.4
	n.add_child(l)
	root.add_child(n)


static func _tv_prop(root: Node, region: Node) -> void:
	Util.box(region, Vector3(19.2, 0.4, -1.0), Vector3(1.0, 0.8, 1.4), Color(0.2, 0.14, 0.1))
	Util.mesh(root, Util.bmesh(Vector3(0.8, 0.6, 0.9)), Util.mat(Color(0.05, 0.05, 0.06)), Vector3(19.2, 1.1, -1.0))
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.5)
	Util.mesh(root, q, Util.mat(Color(0.45, 0.6, 0.8), true), Vector3(18.74, 1.1, -1.0), Vector3(0, -PI / 2.0, 0))
	_lamp(root, Vector3(18.3, 1.2, -1.0), Color(0.5, 0.65, 1.0), 0.6)


static func _tape(root: Node, pos: Vector3) -> void:
	var t := TapePickup.new()
	t.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 2.0, 2.4)
	cs.shape = bs
	t.add_child(cs)
	Util.mesh(t, Util.bmesh(Vector3(0.2, 0.03, 0.12)), Util.mat(Color(0.03, 0.03, 0.03)), Vector3.ZERO, Vector3(0, randf() * TAU, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.2, 0.2)
	l.light_energy = 0.5
	l.omni_range = 2.5
	l.position.y = 0.3
	t.add_child(l)
	root.add_child(t)


static func _phone_prop(root: Node, region: Node) -> void:
	Util.box(region, Vector3(-19.4, 0.35, -14.0), Vector3(0.8, 0.7, 0.9), Color(0.2, 0.14, 0.1))
	Util.mesh(root, Util.bmesh(Vector3(0.3, 0.12, 0.25)), Util.mat(Color(0.35, 0.03, 0.03)), Vector3(-19.3, 0.76, -14.0))
	Util.mesh(root, Util.bmesh(Vector3(0.22, 0.05, 0.07)), Util.mat(Color(0.1, 0.1, 0.1)), Vector3(-19.3, 0.86, -14.0))
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.1, 0.1)
	l.light_energy = 0.6
	l.omni_range = 3.5
	l.position = Vector3(-19.0, 1.1, -14.0)
	root.add_child(l)


static func _locked_door(root: Node, region: Node, id: String, pos: Vector3, size: Vector3, item: String) -> void:
	var slab := Util.box(region, pos, size, Color(0.22, 0.1, 0.08))
	var d := LockedDoor.new()
	d.door_id = id
	d.need_item = item
	d.slab = slab
	d.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x + 3.0, size.y, size.z + 3.0)
	cs.shape = bs
	d.add_child(cs)
	root.add_child(d)


static func _item_pickup(root: Node, pos: Vector3, id: String, min_step: int) -> void:
	var p := ItemPickup.new()
	p.item_id = id
	p.min_step = min_step
	p.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.2, 2.0, 2.2)
	cs.shape = bs
	p.add_child(cs)
	var m := ItemModel.build(id)
	m.scale = Vector3.ONE * 2.0
	m.rotation.y = randf() * TAU
	p.add_child(m)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.4)
	l.light_energy = 0.5
	l.omni_range = 2.5
	l.position.y = 0.3
	p.add_child(l)
	root.add_child(p)


## The Archive wing (south) with the radio, hidden writing, and the Morgue with drawer 13 + the safe.
static func _wing_south(root: Node3D, region: Node) -> Node3D:
	Util.box(region, Vector3(0, -0.1, 33), Vector3(44, 0.2, 26), Color(0.1, 0.1, 0.11))
	var ceil_mi := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(42, 0.2, 26)
	cm.material = Util.mat(Color(0.05, 0.05, 0.06))
	ceil_mi.mesh = cm
	ceil_mi.position = Vector3(0, 3.6, 33)
	root.add_child(ceil_mi)
	_wall(region, -20.25, 33, 0.5, 26)
	_wall(region, 20.25, 33, 0.5, 26)
	_wall(region, 0, 46.25, 41, 0.5)
	for z in [25.0, 30.0, 35.0]:
		for x in [-14.0, -7.0, 7.0, 14.0]:
			Util.box(region, Vector3(x, 1.1, z), Vector3(5.0, 2.2, 0.8), Color(0.22, 0.15, 0.1))
	# radio desk (west wall) — puzzle station
	Util.box(region, Vector3(-19.2, 0.4, 29.0), Vector3(1.0, 0.8, 1.6), Color(0.2, 0.14, 0.1))
	Util.mesh(root, Util.bmesh(Vector3(0.5, 0.3, 0.3)), Util.mat(Color(0.12, 0.1, 0.08)), Vector3(-19.2, 0.95, 29.0))
	Util.mesh(root, Util.sphere(0.04), Util.mat(Color(0.2, 1.0, 0.4), true), Vector3(-18.93, 0.98, 29.1))
	_interactable(root, Vector3(-17.8, 1.0, 29.0), Game.Step.ARCHIVE, 0.0, 0.0, "الراديو", Color(0.3, 0.9, 0.5), false, "radio")
	# the frequency is written on the far wall in ink you can only see with the flashlight
	var hw := HiddenWriting.new()
	hw.text = "٩٧٫٣"
	hw.position = Vector3(-6.0, 1.8, 45.95)
	hw.rotation.y = PI
	root.add_child(hw)
	# morgue: open doorway, drawers, drawer 13, the safe
	_wall(region, 10.0, 38.0, 4.0, 0.5)
	_wall(region, 18.0, 38.0, 4.0, 0.5)
	_wall(region, 8.0, 42.0, 0.5, 8.0)
	var steel := Color(0.45, 0.46, 0.5)
	for z in [39.4, 40.7, 42.0, 43.3, 44.6]:
		for y in [0.45, 1.35, 2.25]:
			if z == 42.0 and y == 1.35:
				continue
			Util.box(region, Vector3(19.0, y, z), Vector3(2.0, 0.8, 0.95), steel)
	var drawer := Util.box(region, Vector3(19.0, 1.35, 42.0), Vector3(2.0, 0.8, 0.95), steel)
	var tag := Label3D.new()
	tag.text = "13"
	tag.font_size = 96
	tag.pixel_size = 0.005
	tag.position = Vector3(-1.02, 0.0, 0.0)
	tag.rotation.y = -PI / 2.0
	tag.modulate = Color(0.9, 0.1, 0.1)
	drawer.add_child(tag)
	Util.box(region, Vector3(8.6, 1.0, 42.0), Vector3(0.7, 0.9, 0.8), Color(0.12, 0.12, 0.14))
	Util.mesh(root, Util.sphere(0.07), Util.mat(Color(0.95, 0.8, 0.3), true), Vector3(8.93, 1.05, 42.0))
	_interactable(root, Vector3(9.8, 1.0, 42.0), Game.Step.MORGUE, 0.0, 0.0, "الخزنة", Color(0.95, 0.8, 0.3), false, "safe")
	_hide_zone(root, region, Vector3(-10, 0, 42))
	_hide_zone(root, region, Vector3(1, 0, 29))
	_lamp(root, Vector3(0, 3, 28), Color(0.8, 0.75, 0.6), 0.5)
	_lamp(root, Vector3(-6, 3, 41), Color(0.8, 0.75, 0.6), 0.5)
	_lamp(root, Vector3(14, 3, 42), Color(0.6, 0.8, 1.0), 0.7)
	return drawer
