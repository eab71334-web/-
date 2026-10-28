class_name HouseBuilder
## Procedural farmhouse "بيت الصفصاف": cellar, ground floor, upper floor, attic, garden, barn, well, willow tree.
## Floors are connected by ramps (the stairs). Doors are real swinging doors. Nothing is hand-modelled.

const WH := 3.7
const T := 0.3
const DW := 1.6
const PLASTER := Color(0.3, 0.27, 0.22)
const WOOD := Color(0.28, 0.18, 0.1)
const FLOOR := Color(0.17, 0.12, 0.09)
const GRASS := Color(0.07, 0.11, 0.06)
const STONE := Color(0.25, 0.25, 0.26)
const B := -4.0
const G := 0.0
const U := 4.0
const A := 8.0
const X0 := -14.0
const X1 := 14.0
const Z0 := -10.0
const Z1 := 10.0


static func build(root: Node3D) -> Dictionary:
	var region := NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nm.agent_max_slope = 46.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	region.navigation_mesh = nm
	root.add_child(region)
	var doors: Array = []

	# ---- slabs (floors / ceilings) with openings for the stairs
	_slab(region, G, -40.0, 40.0, -40.0, 40.0, [X0, X1, Z0, Z1], GRASS)
	_slab(region, G, X0, X1, Z0, Z1, [10.8, 13.2, 1.0, 9.0])
	_slab(region, U, X0, X1, Z0, Z1, [-1.0, 1.0, -5.0, 3.0])
	_slab(region, A, X0, X1, Z0, Z1, [11.0, 13.0, 1.0, 9.0])
	_slab(region, B, X0, X1, Z0, Z1)
	_slab(region, A + WH + T, X0, X1, Z0, Z1, [], PLASTER)
	# ---- the stairs (ramps)
	_ramp(region, 0.0, 3.0, G, -5.0, U, 2.0)          # ground -> upper (hall)
	_ramp(region, 12.0, 9.0, G, 1.0, B, 2.4)          # kitchen -> cellar
	_ramp(region, 12.0, 9.0, U, 1.0, A, 2.0)          # studio -> attic
	# rails around the hall stairwell on the upper floor
	Util.box(region, Vector3(-1.0, U + 0.5, -1.0), Vector3(0.1, 1.0, 7.6), WOOD)
	Util.box(region, Vector3(1.0, U + 0.5, -1.0), Vector3(0.1, 1.0, 7.6), WOOD)
	Util.box(region, Vector3(0.0, U + 0.5, 2.9), Vector3(2.0, 1.0, 0.1), WOOD)

	# ---- exterior walls (cellar, ground, upper, attic) + front door
	var front: HingedDoor = null
	for yb in [B, G, U, A]:
		var south_doors: Array = [0.0] if yb == G else []
		_wall_x(root, region, X0, X1, Z1, yb, south_doors, doors)
		if yb == G:
			front = doors.back()
		_wall_x(root, region, X0, X1, Z0, yb, [], doors)
		_wall_z(root, region, X0, Z0, Z1, yb, [], doors)
		_wall_z(root, region, X1, Z0, Z1, yb, [], doors)
	if Game.has_flag("entered"):
		front.locked_flag = "front_open"
	# ---- ground floor rooms
	_wall_z(root, region, -3.0, Z0, Z1, G, [-5.0, 5.0], doors)
	_wall_z(root, region, 3.0, Z0, Z1, G, [-5.0, 5.0], doors)
	_wall_x(root, region, X0, -3.0, -1.0, G, [-8.5], doors)
	_wall_x(root, region, 3.0, X1, -1.0, G, [8.5], doors)
	# ---- upper floor rooms
	_wall_z(root, region, -3.0, Z0, Z1, U, [-5.0, 5.0], doors)
	_wall_z(root, region, 3.0, Z0, Z1, U, [-5.0, 5.0], doors)
	_wall_x(root, region, X0, -3.0, 0.0, U, [], doors)
	_wall_x(root, region, 3.0, X1, 0.0, U, [], doors)
	# attic stairwell (inside the guest room): sealed, the only way in is the locked door at its foot
	_wall_z(root, region, 11.0, 3.0, 9.0, U, [], doors)
	_wall_z(root, region, 13.0, 3.0, 10.0, U, [], doors)
	_locked_door(root, region, "attic", Vector3(11.0, U + WH / 2.0, 9.5), Vector3(0.3, WH, 1.0), "key_attic")
	# ---- cellar rooms
	_wall_z(root, region, 6.0, Z0, -2.0, B, [-6.0], doors)
	_wall_x(root, region, 6.0, X1, -2.0, B, [], doors)
	_wall_z(root, region, -6.0, Z0, 4.0, B, [-3.0], doors)

	_furnish(root, region)
	_garden(root, region)
	_roof(root)

	# ---- people, tools to find, puzzle stations
	_npc(root, "saeed", Vector3(-6.0, G, 3.5), PI)
	_npc(root, "layla", Vector3(-9.5, G, 2.5), PI)
	_npc(root, "halima", Vector3(-12.3, G, 7.5), PI * 0.5)
	_npc(root, "maryam", Vector3(-4.6, G, 8.2), PI)
	_npc(root, "ziad", Vector3(-7.5, G, 0.2), PI)
	_interactable(root, Vector3(12.0, B + 1.0, -8.5), Game.Step.POWER, 0.0, 0.0, "لوحة القاطع", Color(1.0, 0.7, 0.1), false, "fuse")
	Util.box(region, Vector3(-13.5, U + 0.45, -4.0), Vector3(0.6, 0.9, 0.8), Color(0.12, 0.12, 0.14))
	_interactable(root, Vector3(-12.4, U + 1.0, -4.0), Game.Step.SAFE, 0.0, 0.0, "الخزنة", Color(0.95, 0.8, 0.3), false, "safe")
	Util.box(region, Vector3(0.0, A + 0.3, -6.0), Vector3(1.2, 0.6, 0.7), WOOD)         # the crib
	_interactable(root, Vector3(0.0, A + 1.0, -4.6), Game.Step.RITUAL, 0.0, 0.0, "ضع الحذاء وشغّل العلبة", Color(0.9, 0.8, 0.5), false, "ritual")
	_item_pickup(root, Vector3(0.0, A + 0.75, -6.0), "music_box", Game.Step.MUSICBOX)
	_item_pickup(root, Vector3(25.0, 0.95, -26.0), "shovel", Game.Step.DIG)
	var dig := DigSpot.new()
	dig.position = Vector3(14.0, 1.0, 26.0)
	dig.step_index = Game.Step.DIG
	dig.hold_time = 5.0
	dig.noise = 0.6
	dig.label = "احفر تحت الشجرة"
	var dcs := CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = Vector3(3.0, 2.5, 3.0)
	dcs.shape = dbs
	dig.add_child(dcs)
	root.add_child(dig)
	for e in [["page_1", Vector3(-12.5, G + 0.1, 9.0)], ["page_2", Vector3(7.0, G + 0.95, 9.4)], ["page_3", Vector3(6.0, U + 0.1, 6.0)], ["page_4", Vector3(-10.0, B + 0.1, -5.0)]]:
		_item_pickup(root, e[1], e[0], Game.Step.PAGES)
	for bp in [Vector3(-4.0, 0.1, 9.0), Vector3(4.5, 0.1, 0.5), Vector3(8.0, B + 0.1, 2.0), Vector3(4.5, U + 0.1, -9.0), Vector3(4.0, A + 0.1, -6.0), Vector3(22.0, 0.1, -19.0), Vector3(-2.0, 0.1, 20.0)]:
		var b := BatteryPickup.new()
		b.position = bp
		root.add_child(b)
	var note_spots := [Vector3(-13.0, 0.1, 1.0), Vector3(12.0, 0.1, -8.0), Vector3(4.0, 0.1, 8.5), Vector3(-6.0, A + 0.1, -5.0), Vector3(13.0, U + 0.1, -2.0), Vector3(11.0, B + 0.1, -0.5), Vector3(-15.0, 0.1, 16.0), Vector3(-6.0, U + 0.1, -8.0)]
	for i in note_spots.size():
		_note(root, note_spots[i], i)

	# ---- paranormal traces (only visible in the camera) and places where she is "close" (recorder)
	_evidence(root, "handprint", "hand", Vector3(3.2, U + 1.4, -3.0), PI / 2.0, "")
	_evidence(root, "writing", "mirror", Vector3(-3.2, U + 1.6, 5.0), -PI / 2.0, "ريما")
	_evidence(root, "shadow", "shadow", Vector3(0.0, U, -9.2), PI, "")
	_evidence(root, "orb", "orb", Vector3(4.0, A + 1.2, -6.0), 0.0, "")
	_spirit(root, "evp_kids", Vector3(8.5, U + 1.5, -5.0), Vector3(10, 3, 9), "هل رأيتِ ريما؟… ريما… أين ريما؟")
	_spirit(root, "evp_attic", Vector3(0.0, A + 1.5, -1.0), Vector3(24, 3, 14), "لا تتركيني… لا تتركيني وحدي…")
	_spirit(root, "evp_base", Vector3(0.0, B + 1.5, 0.0), Vector3(26, 3, 18), "الماء… تحت الشجرة… الماء…")

	# ---- hiding places (order matches Game.ZONE_NAMES) and lamps
	for p in [Vector3(-12.0, G, 6.0), Vector3(-10.0, G, -6.0), Vector3(8.0, G, 7.0), Vector3(11.0, G, -6.0), Vector3(-11.0, U, -6.0),
			Vector3(11.0, U, -6.0), Vector3(7.0, U, 6.0), Vector3(-9.0, B, -5.0), Vector3(6.0, B, 5.0), Vector3(8.0, A, 4.0)]:
		_hide_zone(root, region, p)
	_lamp(root, Vector3(-8.5, G + 3.0, 4.0), Color(1.0, 0.7, 0.4), 0.8, true)      # the family's candles
	for e in [[Vector3(-8.5, G + 3.0, -5.5), 0.7], [Vector3(8.5, G + 3.0, 4.0), 0.7], [Vector3(8.5, G + 3.0, -5.5), 0.7], [Vector3(0.0, G + 3.0, 0.0), 0.6],
			[Vector3(-8.5, U + 3.0, -5.0), 0.6], [Vector3(8.5, U + 3.0, -5.0), 0.6], [Vector3(-8.5, U + 3.0, 5.0), 0.6], [Vector3(8.5, U + 3.0, 5.0), 0.6],
			[Vector3(0.0, U + 3.0, 5.0), 0.5], [Vector3(0.0, A + 3.0, 0.0), 0.5], [Vector3(-8.0, B + 3.0, 0.0), 0.5], [Vector3(9.0, B + 3.0, -6.0), 0.5], [Vector3(0.0, B + 3.0, 5.0), 0.5]]:
		_lamp(root, e[0], Color(1.0, 0.85, 0.6), float(e[1]), false)
	_lamp(root, Vector3(25.0, 3.0, -24.0), Color(1.0, 0.8, 0.5), 0.7, true)         # barn lantern

	return {
		"region": region,
		"front": front,
		"spawns": [Vector3(-1.5, 0.05, 30.0), Vector3(0.0, 0.05, 30.0), Vector3(1.5, 0.05, 30.0), Vector3(3.0, 0.05, 30.0)],
		"patrol_points": [Vector3(-8, G, 4), Vector3(8, G, 4), Vector3(-8, G, -6), Vector3(8, G, -6), Vector3(0, G, 8),
			Vector3(-8, U, -5), Vector3(8, U, -5), Vector3(-8, U, 5), Vector3(0, U, -8),
			Vector3(-8, B, 0), Vector3(8, B, -6), Vector3(0, B, 5), Vector3(12, B, -2),
			Vector3(0, 0, 22), Vector3(14, 0, 24), Vector3(-16, 0, 17)],
		"attic_points": [Vector3(0, A, 0), Vector3(-8, A, -4), Vector3(8, A, 4)],
	}


# ------------------------------------------------------------------ building blocks
static func _sbox(region: Node, xa: float, xb: float, za: float, zb: float, cy: float, color: Color) -> void:
	if xb - xa < 0.01 or zb - za < 0.01:
		return
	Util.box(region, Vector3((xa + xb) / 2.0, cy, (za + zb) / 2.0), Vector3(xb - xa, T, zb - za), color)


static func _slab(region: Node, y_top: float, x0: float, x1: float, z0: float, z1: float, hole := [], color := FLOOR) -> void:
	var cy := y_top - T / 2.0
	if hole.is_empty():
		_sbox(region, x0, x1, z0, z1, cy, color)
		return
	var hx0: float = hole[0]
	var hx1: float = hole[1]
	var hz0: float = hole[2]
	var hz1: float = hole[3]
	_sbox(region, x0, hx0, z0, z1, cy, color)
	_sbox(region, hx1, x1, z0, z1, cy, color)
	_sbox(region, hx0, hx1, z0, hz0, cy, color)
	_sbox(region, hx0, hx1, hz1, z1, cy, color)


static func _ramp(region: Node, xc: float, za: float, ya: float, zb: float, yb: float, width: float) -> void:
	var dz := zb - za
	var dy := yb - ya
	var length := sqrt(dz * dz + dy * dy)
	var body := Util.box(region, Vector3(xc, (ya + yb) / 2.0 - 0.15, (za + zb) / 2.0), Vector3(width, T, length), WOOD)
	body.rotation.x = -atan(dy / dz)


static func _seg(region: Node, along_x: bool, a: float, b: float, fixed: float, yb: float, color: Color) -> void:
	if b - a < 0.05:
		return
	var mid := (a + b) / 2.0
	if along_x:
		Util.box(region, Vector3(mid, yb + WH / 2.0, fixed), Vector3(b - a, WH, T), color)
	else:
		Util.box(region, Vector3(fixed, yb + WH / 2.0, mid), Vector3(T, WH, b - a), color)


static func _lintel(region: Node, along_x: bool, a: float, b: float, fixed: float, yb: float, color: Color) -> void:
	var h := WH - 2.6
	var cy := yb + 2.6 + h / 2.0
	if along_x:
		Util.box(region, Vector3((a + b) / 2.0, cy, fixed), Vector3(b - a, h, T), color)
	else:
		Util.box(region, Vector3(fixed, cy, (a + b) / 2.0), Vector3(T, h, b - a), color)


static func _wall_x(root: Node3D, region: Node, x0: float, x1: float, z: float, yb: float, door_centers: Array, door_nodes: Array) -> void:
	var cursor := x0
	var cs := door_centers.duplicate()
	cs.sort()
	for c in cs:
		_seg(region, true, cursor, c - DW / 2.0, z, yb, PLASTER)
		_lintel(region, true, c - DW / 2.0, c + DW / 2.0, z, yb, PLASTER)
		var d := HingedDoor.new()
		d.position = Vector3(c - DW / 2.0, yb, z)
		root.add_child(d)
		door_nodes.append(d)
		cursor = c + DW / 2.0
	_seg(region, true, cursor, x1, z, yb, PLASTER)


static func _wall_z(root: Node3D, region: Node, x: float, z0: float, z1: float, yb: float, door_centers: Array, door_nodes: Array) -> void:
	var cursor := z0
	var cs := door_centers.duplicate()
	cs.sort()
	for c in cs:
		_seg(region, false, cursor, c - DW / 2.0, x, yb, PLASTER)
		_lintel(region, false, c - DW / 2.0, c + DW / 2.0, x, yb, PLASTER)
		var d := HingedDoor.new()
		d.position = Vector3(x, yb, c - DW / 2.0)
		d.rotation.y = -PI / 2.0
		root.add_child(d)
		door_nodes.append(d)
		cursor = c + DW / 2.0
	_seg(region, false, cursor, z1, x, yb, PLASTER)


static func _prop(region: Node, yb: float, x: float, z: float, sx: float, sy: float, sz: float, color := WOOD) -> void:
	Util.box(region, Vector3(x, yb + sy / 2.0, z), Vector3(sx, sy, sz), color)


static func _lamp(parent: Node, pos: Vector3, c: Color, energy: float, always: bool) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = 9.0
	l.add_to_group("lamps")
	l.set_meta("base", energy)
	l.set_meta("always", always)
	parent.add_child(l)


static func _npc(root: Node, id: String, pos: Vector3, rot: float) -> void:
	var n := Npc.new()
	n.id = id
	n.position = pos
	n.rotation.y = rot
	root.add_child(n)


static func _evidence(root: Node, kind: String, id: String, pos: Vector3, rot: float, text: String) -> void:
	var m := EvidenceMarker.new()
	m.kind = kind
	m.id = id
	m.text = text
	m.position = pos
	m.rotation.y = rot
	root.add_child(m)


static func _spirit(root: Node, id: String, pos: Vector3, size: Vector3, voice: String) -> void:
	var z := SpiritZone.new()
	z.evp_id = id
	z.voice = voice
	z.size = size
	z.position = pos
	root.add_child(z)


static func _furnish(root: Node, region: Node) -> void:
	# living room
	_prop(region, G, -8.0, 8.8, 3.2, 0.8, 1.0, Color(0.3, 0.15, 0.12))
	_prop(region, G, -8.0, 5.6, 1.4, 0.5, 0.8)
	_prop(region, G, -13.5, 4.0, 0.6, 2.0, 2.0, STONE)
	# dining room
	_prop(region, G, -8.5, -5.5, 3.0, 0.8, 1.4)
	for p in [Vector2(-10.0, -7.0), Vector2(-7.0, -7.0), Vector2(-10.0, -4.0), Vector2(-7.0, -4.0)]:
		_prop(region, G, p.x, p.y, 0.5, 0.9, 0.5)
	# kitchen
	_prop(region, G, 7.0, 9.4, 5.0, 0.9, 1.0, Color(0.35, 0.33, 0.3))
	_prop(region, G, 7.0, 4.0, 2.0, 0.8, 1.2)
	# study
	_prop(region, G, 9.0, -6.5, 2.0, 0.8, 1.0)
	_prop(region, G, 9.0, -9.6, 5.0, 2.2, 0.5, Color(0.22, 0.15, 0.1))
	# parents' room, kids' room, bathroom, guest room (upper)
	_prop(region, U, -9.0, -7.5, 2.0, 0.6, 2.2, Color(0.3, 0.3, 0.35))
	_prop(region, U, -12.0, -8.5, 1.6, 2.2, 0.7)
	_prop(region, U, 8.5, -8.0, 1.0, 0.5, 2.0, Color(0.35, 0.3, 0.4))
	_prop(region, U, 11.0, -8.0, 1.0, 0.5, 2.0, Color(0.35, 0.3, 0.4))
	_prop(region, U, -9.0, 8.5, 2.0, 0.6, 1.0, Color(0.7, 0.7, 0.72))
	_prop(region, U, 6.0, 8.5, 2.0, 0.7, 1.0)
	# cellar: boiler + shelves
	_prop(region, B, 10.0, -7.0, 1.6, 2.0, 1.6, Color(0.2, 0.2, 0.22))
	_prop(region, B, -10.0, 2.0, 3.0, 2.0, 0.6)
	# attic: boxes and a covered shape
	_prop(region, A, 6.0, -5.0, 1.4, 1.0, 1.4)
	_prop(region, A, -7.0, 3.0, 1.4, 1.2, 1.0)


static func _roof(root: Node) -> void:
	var m := Util.mat(Color(0.08, 0.07, 0.07))
	var north := Util.mesh(root, Util.bmesh(Vector3(30.0, 0.3, 10.6)), m, Vector3(0, 13.6, -5.0))
	north.rotation.x = -0.29
	var south := Util.mesh(root, Util.bmesh(Vector3(30.0, 0.3, 10.6)), m, Vector3(0, 13.6, 5.0))
	south.rotation.x = 0.29


static func _cyl_body(region: Node, pos: Vector3, r: float, h: float, color: Color) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	Util.mesh(b, Util.cyl(r, h), Util.grunge(color))
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	b.add_child(cs)
	region.add_child(b)


static func _garden(root: Node3D, region: Node) -> void:
	Util.box(region, Vector3(-20.0, 1.5, 38.0), Vector3(36.0, 3.0, 0.5), STONE)      # south wall with a gate gap
	Util.box(region, Vector3(20.0, 1.5, 38.0), Vector3(36.0, 3.0, 0.5), STONE)
	Util.box(region, Vector3(0.0, 1.5, -38.0), Vector3(76.0, 3.0, 0.5), STONE)
	Util.box(region, Vector3(-38.0, 1.5, 0.0), Vector3(0.5, 3.0, 76.0), STONE)
	Util.box(region, Vector3(38.0, 1.5, 0.0), Vector3(0.5, 3.0, 76.0), STONE)
	# the willow tree + swing
	_cyl_body(region, Vector3(16.0, 3.0, 24.0), 0.5, 6.0, Color(0.2, 0.14, 0.1))
	Util.mesh(root, Util.sphere(3.6), Util.mat(Color(0.1, 0.17, 0.09)), Vector3(16.0, 7.4, 24.0))
	var leaf := Util.mat(Color(0.12, 0.2, 0.1))
	for i in 16:
		var a := TAU * i / 16.0
		Util.mesh(root, Util.bmesh(Vector3(0.05, 3.6, 0.05)), leaf, Vector3(16.0 + cos(a) * 3.2, 4.8, 24.0 + sin(a) * 3.2))
	Util.mesh(root, Util.bmesh(Vector3(0.04, 4.0, 0.04)), Util.mat(Color(0.5, 0.4, 0.3)), Vector3(13.0, 4.0, 24.1))
	Util.mesh(root, Util.bmesh(Vector3(0.04, 4.0, 0.04)), Util.mat(Color(0.5, 0.4, 0.3)), Vector3(13.4, 4.0, 24.1))
	Util.mesh(root, Util.bmesh(Vector3(0.7, 0.06, 0.3)), Util.mat(Color(0.3, 0.2, 0.12)), Vector3(13.2, 1.9, 24.1))
	# the well
	Util.box(region, Vector3(-16.0, 0.5, 18.0), Vector3(1.8, 1.0, 1.8), STONE)
	Util.mesh(root, Util.bmesh(Vector3(1.2, 0.02, 1.2)), Util.mat(Color(0.0, 0.0, 0.0)), Vector3(-16.0, 1.01, 18.0))
	# the barn (north-east of the house)
	Util.box(region, Vector3(25.0, 2.0, -30.0), Vector3(10.4, 4.0, 0.4), PLASTER)
	Util.box(region, Vector3(20.0, 2.0, -24.0), Vector3(0.4, 4.0, 12.0), PLASTER)
	Util.box(region, Vector3(30.0, 2.0, -24.0), Vector3(0.4, 4.0, 12.0), PLASTER)
	Util.box(region, Vector3(21.5, 2.0, -18.0), Vector3(3.0, 4.0, 0.4), PLASTER)
	Util.box(region, Vector3(28.5, 2.0, -18.0), Vector3(3.0, 4.0, 0.4), PLASTER)
	Util.box(region, Vector3(25.0, 4.2, -24.0), Vector3(11.0, 0.4, 13.0), Color(0.12, 0.1, 0.09))
	_prop(region, 0.0, 28.0, -28.0, 2.0, 1.2, 1.2, Color(0.5, 0.4, 0.15))
	_prop(region, 0.0, 22.0, -28.0, 2.0, 1.2, 1.2, Color(0.5, 0.4, 0.15))


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
