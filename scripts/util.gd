class_name Util

static func mat(c: Color, emit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.5
	return m

static func box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat(color)
	mi.mesh = bm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(mi)
	b.add_child(cs)
	parent.add_child(b)
	return b
