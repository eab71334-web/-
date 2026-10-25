class_name ItemModel
## Tiny procedural 3D models for inventory items (used in the first-person hand and in the inspect screen).


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"key_archive", "key_b13":
			var brass := Util.mat(Color(0.78, 0.6, 0.2) if id == "key_archive" else Color(0.55, 0.1, 0.08))
			brass.metallic = 0.8
			brass.roughness = 0.35
			Util.mesh(root, Util.cyl(0.012, 0.14), brass, Vector3(0, 0, 0), Vector3(0, 0, PI / 2.0))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.018
			ring.outer_radius = 0.034
			Util.mesh(root, ring, brass, Vector3(-0.085, 0, 0), Vector3(PI / 2.0, 0, 0))
			Util.mesh(root, Util.bmesh(Vector3(0.012, 0.03, 0.008)), brass, Vector3(0.05, -0.016, 0))
			Util.mesh(root, Util.bmesh(Vector3(0.012, 0.022, 0.008)), brass, Vector3(0.068, -0.012, 0))
		"tape":
			Util.mesh(root, Util.bmesh(Vector3(0.19, 0.03, 0.104)), Util.mat(Color(0.04, 0.04, 0.045)))
			Util.mesh(root, Util.bmesh(Vector3(0.1, 0.031, 0.04)), Util.mat(Color(0.85, 0.82, 0.7)), Vector3(0, 0.001, 0.0))
			Util.mesh(root, Util.cyl(0.016, 0.032), Util.mat(Color(0.15, 0.15, 0.15)), Vector3(-0.04, 0.002, 0))
			Util.mesh(root, Util.cyl(0.016, 0.032), Util.mat(Color(0.15, 0.15, 0.15)), Vector3(0.04, 0.002, 0))
		_:
			Util.mesh(root, Util.bmesh(Vector3(0.08, 0.08, 0.08)), Util.mat(Color(0.5, 0.5, 0.5)))
	return root
