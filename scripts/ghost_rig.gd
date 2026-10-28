extends Node3D
class_name GhostRig
## Thuraya: a mother in a long pale gown, black hair, hollow eyes. Floats. Transparent: she is mostly NOT seen.
## Same API as the old monster rig: animate(), speak_for(), style, footstep.

signal footstep

var style := "walk"
var speak_until := 0.0
var mats: Array[StandardMaterial3D] = []
var arms: Array[Node3D] = []
var head: Node3D
var jaw: MeshInstance3D
var light: OmniLight3D
var _prev := 0.0


func _m(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.9
	mats.append(m)
	return m


func _ready() -> void:
	var dress := _m(Color(0.78, 0.78, 0.8))
	var skin := _m(Color(0.7, 0.72, 0.74))
	var hair := _m(Color(0.03, 0.03, 0.04))
	var dark := _m(Color(0.0, 0.0, 0.0))
	Util.mesh(self, Util.cone(0.5, 1.7), dress, Vector3(0, 1.0, 0))
	for i in 8:
		var a := TAU * i / 8.0
		Util.mesh(self, Util.bmesh(Vector3(0.12, 0.35, 0.02)), dress, Vector3(sin(a) * 0.5, 0.25, cos(a) * 0.5), Vector3(0, a, 0))
	Util.mesh(self, Util.caps(0.17, 0.5), dress, Vector3(0, 1.6, 0))
	for s in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.24 * s, 1.78, 0)
		add_child(sh)
		Util.mesh(sh, Util.caps(0.04, 0.85), skin, Vector3(0, -0.4, 0))
		for f in 4:
			Util.mesh(sh, Util.cone(0.01, 0.25), skin, Vector3(-0.03 + f * 0.02, -0.95, 0), Vector3(PI, 0, 0))
		arms.append(sh)
	head = Node3D.new()
	head.position = Vector3(0, 1.98, 0)
	add_child(head)
	Util.mesh(head, Util.sphere(0.13), skin)
	Util.mesh(head, Util.cyl(0.17, 1.0), hair, Vector3(0, -0.45, 0.06))
	Util.mesh(head, Util.bmesh(Vector3(0.05, 0.7, 0.03)), hair, Vector3(-0.13, -0.35, -0.06))
	Util.mesh(head, Util.bmesh(Vector3(0.05, 0.7, 0.03)), hair, Vector3(0.13, -0.35, -0.06))
	for sx in [-1.0, 1.0]:
		Util.mesh(head, Util.sphere(0.03), dark, Vector3(0.05 * sx, 0.02, -0.115))
	jaw = Util.mesh(head, Util.bmesh(Vector3(0.05, 0.07, 0.02)), dark, Vector3(0, -0.06, -0.125))
	light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.75, 1.0)
	light.light_energy = 0.4
	light.omni_range = 4.0
	light.position = Vector3(0, 1.5, -0.3)
	add_child(light)


func speak_for(sec: float) -> void:
	speak_until = Time.get_ticks_msec() / 1000.0 + sec


func set_alpha(a: float) -> void:
	visible = a > 0.02
	for m in mats:
		var c := m.albedo_color
		c.a = a
		m.albedo_color = c
	if light != null:
		light.light_energy = 0.4 * a


func animate(_delta: float, speed: float, mood: int, t: float) -> void:
	if head == null:
		return
	position.y = 0.12 + sin(t * 1.3) * 0.05
	var chase := mood == 2
	var stare := mood == 3 or mood == 5
	for i in arms.size():
		var side := 1.0 if i == 0 else -1.0
		arms[i].rotation.z = side * (0.12 + sin(t * 0.9 + i) * 0.05)
		arms[i].rotation.x = -1.2 if chase else (-0.2 if stare else sin(t * 0.7 + i) * 0.05)
	head.rotation = Vector3(0.1 if not stare else 0.0, 0.0, 0.5 if stare else sin(t * 0.6) * 0.08)
	var open := 0.0
	if t < speak_until:
		open = absf(sin(t * 12.0))
	elif chase:
		open = 0.8
	jaw.scale.y = 1.0 + open * 4.0
	if speed > 0.4 and signf(sin(t * 6.0)) != signf(_prev):
		footstep.emit()
	_prev = sin(t * 6.0)
