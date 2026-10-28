extends Node3D
class_name EvidenceMarker
## Paranormal traces that exist ONLY in the camera's viewfinder. Aim and press E to photograph them.

var kind := "handprint"
var id := ""
var text := ""
var captured := false


func _ready() -> void:
	add_to_group("evidence")
	var glow := Util.mat(Color(0.4, 1.0, 0.9), true)
	match kind:
		"handprint":
			Util.mesh(self, Util.bmesh(Vector3(0.1, 0.12, 0.01)), glow)
			for f in 4:
				Util.mesh(self, Util.bmesh(Vector3(0.02, 0.1, 0.01)), glow, Vector3(-0.04 + f * 0.027, 0.1, 0.0))
			Util.mesh(self, Util.bmesh(Vector3(0.025, 0.07, 0.01)), glow, Vector3(0.075, 0.0, 0.0), Vector3(0, 0, -0.7))
			scale = Vector3.ONE * 2.2
		"writing":
			var l := Label3D.new()
			l.text = text
			l.font_size = 160
			l.pixel_size = 0.004
			l.modulate = Color(0.4, 1.0, 0.9)
			l.shaded = false
			add_child(l)
		"shadow":
			var g := GhostRig.new()
			add_child(g)
			g.set_alpha(0.7)
		"orb":
			Util.mesh(self, Util.sphere(0.09), glow)
			var li := OmniLight3D.new()
			li.light_color = Color(0.5, 1.0, 0.9)
			li.light_energy = 0.6
			li.omni_range = 2.5
			add_child(li)
	visible = false


func _process(delta: float) -> void:
	visible = Game.camera_on and not captured
	if kind == "orb":
		position.y += sin(Time.get_ticks_msec() / 400.0) * 0.1 * delta


func try_capture(cam: Camera3D) -> bool:
	if captured or not Game.camera_on:
		return false
	var to := global_position - cam.global_position
	if to.length() > 9.0:
		return false
	if (-cam.global_transform.basis.z).dot(to.normalized()) < 0.9:
		return false
	captured = true
	visible = false
	return true
