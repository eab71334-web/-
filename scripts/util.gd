class_name Util

static var _noise: NoiseTexture2D


static func mat(c: Color, emit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.5
	return m


## Dirty concrete/wood look: one shared noise texture, triplanar so no UVs needed.
static func grunge(c: Color) -> StandardMaterial3D:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_PERLIN
		fn.frequency = 0.02
		fn.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.noise = fn
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r * 1.7, c.g * 1.7, c.b * 1.7)
	m.albedo_texture = _noise
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.roughness = 0.95
	return m


static func box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = grunge(color)
	mi.mesh = bm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(mi)
	b.add_child(cs)
	parent.add_child(b)
	return b


static func mesh(parent: Node, m: Mesh, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func bmesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func caps(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 10
	c.rings = 3
	return c


static func cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return c


static func cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	return c


static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func barrel(parent: Node, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos + Vector3(0, 0.55, 0)
	b.collision_layer = 1
	b.collision_mask = 0
	var m := mat(Color(0.35, 0.16, 0.08))
	m.metallic = 0.5
	m.roughness = 0.6
	mesh(b, cyl(0.35, 1.1), m)
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 0.35
	s.height = 1.1
	cs.shape = s
	b.add_child(cs)
	parent.add_child(b)
	return b
