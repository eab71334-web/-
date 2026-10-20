extends Node3D
class_name MonsterRig
## Procedural emaciated stalker: hunched, long dragging arms with claws, skull-like head,
## hinged jaw with teeth, glowing eyes, ribcage, exposed spine, tattered shroud.
## Mood numbers = Monster.State: 0 patrol, 1 investigate, 2 chase, 3 stare, 4 search, 5 confront, 6 kill.

signal footstep

var hips: Array[Node3D] = []
var knees: Array[Node3D] = []
var shoulders: Array[Node3D] = []
var elbows: Array[Node3D] = []
var rags: Array[Node3D] = []
var spine: Node3D
var head: Node3D
var jaw: Node3D
var eye_mat: StandardMaterial3D
var eye_light: OmniLight3D
var phase := 0.0
var _prev_sin := 0.0
var _twitch_t := 0.0
var _twitch := Vector3.ZERO


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _ready() -> void:
	var skin := Util.mat(Color(0.52, 0.54, 0.48))
	skin.roughness = 0.8
	var flesh := Util.mat(Color(0.30, 0.1, 0.09))
	flesh.roughness = 0.3
	var dark := Util.mat(Color(0.02, 0.02, 0.025))
	var bone := Util.mat(Color(0.8, 0.76, 0.63))
	var cloth := Util.mat(Color(0.06, 0.055, 0.05))
	eye_mat = Util.mat(Color(1.0, 0.06, 0.02), true)
	eye_mat.emission_energy_multiplier = 4.0

	# legs (order: left, right)
	for s in [-1.0, 1.0]:
		var hip := _pivot(self, Vector3(0.17 * s, 1.15, 0.0))
		Util.mesh(hip, Util.caps(0.075, 0.6), skin, Vector3(0, -0.25, 0))
		var knee := _pivot(hip, Vector3(0, -0.5, 0))
		Util.mesh(knee, Util.caps(0.055, 0.7), skin, Vector3(0, -0.3, 0))
		var foot := _pivot(knee, Vector3(0, -0.62, 0))
		Util.mesh(foot, Util.bmesh(Vector3(0.1, 0.05, 0.28)), skin, Vector3(0, 0.0, -0.08))
		for f in 3:
			Util.mesh(foot, Util.cone(0.015, 0.16), bone, Vector3(-0.03 + f * 0.03, 0.0, -0.3), Vector3(-PI / 2.0, 0, 0))
		hips.append(hip)
		knees.append(knee)

	# torso: abdomen, chest, exposed ribs, spine knobs, open wound
	spine = _pivot(self, Vector3(0, 1.15, 0))
	spine.rotation.x = -0.35
	Util.mesh(spine, Util.caps(0.13, 0.5), skin, Vector3(0, 0.25, 0))
	Util.mesh(spine, Util.caps(0.17, 0.7), skin, Vector3(0, 0.78, 0))
	for i in 6:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.155 - i * 0.003
		ring.outer_radius = 0.19 - i * 0.003
		ring.rings = 12
		ring.ring_segments = 6
		Util.mesh(spine, ring, bone, Vector3(0, 0.55 + i * 0.085, 0))
	for i in 7:
		Util.mesh(spine, Util.sphere(0.03), bone, Vector3(0, 0.3 + i * 0.1, 0.17))
	Util.mesh(spine, Util.bmesh(Vector3(0.16, 0.2, 0.03)), flesh, Vector3(0.03, 0.8, -0.17))

	# arms (order: left, right)
	for s in [-1.0, 1.0]:
		var sh := _pivot(spine, Vector3(0.27 * s, 1.1, 0))
		Util.mesh(sh, Util.sphere(0.07), skin)
		Util.mesh(sh, Util.caps(0.05, 0.8), skin, Vector3(0, -0.38, 0))
		var el := _pivot(sh, Vector3(0, -0.75, 0))
		Util.mesh(el, Util.sphere(0.055), bone)
		Util.mesh(el, Util.caps(0.04, 0.9), skin, Vector3(0, -0.42, 0))
		var hand := _pivot(el, Vector3(0, -0.85, 0))
		Util.mesh(hand, Util.bmesh(Vector3(0.09, 0.12, 0.035)), skin, Vector3(0, -0.04, 0))
		for f in 4:
			Util.mesh(hand, Util.cone(0.012, 0.3), bone, Vector3(-0.03 + f * 0.02, -0.22, 0), Vector3(PI, 0, 0))
		shoulders.append(sh)
		elbows.append(el)

	# neck + head
	var neck := _pivot(spine, Vector3(0, 1.28, -0.02))
	neck.rotation.x = -0.5
	Util.mesh(neck, Util.caps(0.04, 0.4), skin, Vector3(0, 0.18, 0))
	head = _pivot(neck, Vector3(0, 0.4, 0))
	head.rotation.x = 0.45
	var cr := Util.mesh(head, Util.sphere(0.16), skin, Vector3(0, 0.08, 0))
	cr.scale = Vector3(0.82, 1.3, 0.95)
	Util.mesh(head, Util.bmesh(Vector3(0.22, 0.035, 0.06)), dark, Vector3(0, 0.11, -0.135), Vector3(0.15, 0, 0))
	for s in [-1.0, 1.0]:
		var sock := Util.mesh(head, Util.sphere(0.045), dark, Vector3(0.065 * s, 0.07, -0.13))
		sock.scale = Vector3(1, 1, 0.6)
		Util.mesh(head, Util.sphere(0.022), eye_mat, Vector3(0.065 * s, 0.07, -0.15))
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(1, 0.1, 0.05)
	eye_light.light_energy = 0.7
	eye_light.omni_range = 5.0
	eye_light.position = Vector3(0, 0.07, -0.25)
	head.add_child(eye_light)
	Util.mesh(head, Util.bmesh(Vector3(0.12, 0.03, 0.14)), dark, Vector3(0, -0.09, -0.07))
	for i in 7:
		Util.mesh(head, Util.cone(0.007, 0.05), bone, Vector3(-0.054 + i * 0.018, -0.105, -0.13), Vector3(PI, 0, 0))
	jaw = _pivot(head, Vector3(0, -0.1, -0.02))
	Util.mesh(jaw, Util.bmesh(Vector3(0.11, 0.04, 0.15)), skin, Vector3(0, -0.02, -0.07))
	for i in 7:
		Util.mesh(jaw, Util.cone(0.007, 0.05), bone, Vector3(-0.054 + i * 0.018, 0.02, -0.14))

	# tattered shroud
	for i in 5:
		var rag := _pivot(spine, Vector3(-0.2 + i * 0.1, 1.05, 0.14))
		Util.mesh(rag, Util.bmesh(Vector3(0.09, 0.75 + (i % 2) * 0.25, 0.012)), cloth, Vector3(0, -0.4, 0))
		rags.append(rag)
	for i in 4:
		var sk := _pivot(self, Vector3(-0.15 + i * 0.1, 1.1, 0.08))
		Util.mesh(sk, Util.bmesh(Vector3(0.08, 0.5, 0.01)), cloth, Vector3(0, -0.25, 0))
		rags.append(sk)


func animate(delta: float, speed: float, mood: int, t: float) -> void:
	if spine == null:
		return
	var k := minf(delta * 8.0, 1.0)
	var chase := mood == 2
	var stare := mood == 3
	var confront := mood == 5
	var kill := mood == 6
	var amp := clampf(speed / 3.0, 0.0, 1.6)
	if speed > 0.15:
		phase += delta * (3.0 + speed * 1.5)
	var sw := sin(phase)
	var reach := 0.0
	if chase or kill:
		reach = 1.3
	elif confront:
		reach = 0.5
	elif stare:
		reach = 0.15
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		hips[i].rotation.x = lerpf(hips[i].rotation.x, sw * side * 0.65 * amp, k)
		knees[i].rotation.x = lerpf(knees[i].rotation.x, -maxf(0.0, sw * side) * 0.8 * amp, k)
		shoulders[i].rotation.x = lerpf(shoulders[i].rotation.x, reach - sw * side * 0.35 * amp + sin(t * 0.9 + i) * 0.04, k)
		shoulders[i].rotation.z = lerpf(shoulders[i].rotation.z, side * 0.1, k)
		elbows[i].rotation.x = lerpf(elbows[i].rotation.x, (0.5 if chase else 0.12) + sin(t * 1.3 + i) * 0.05, k)

	var lean := -0.35
	if chase:
		lean = -0.75
	elif stare:
		lean = -0.1
	elif confront:
		lean = -0.95
	elif kill:
		lean = -0.6
	spine.rotation.x = lerpf(spine.rotation.x, lean, k * 0.6)
	spine.scale.y = 1.0 + sin(t * 2.2) * 0.012
	position.y = absf(sw) * 0.05 * amp

	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.5, 2.8)
		_twitch = Vector3(randf_range(-0.25, 0.25), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4))
	var h := Vector3(0.45, 0, 0) + _twitch
	if stare:
		h = Vector3(0.45, 0.0, 0.6)       # unnatural tilt, locked on you
	elif chase:
		h = Vector3(0.3, sin(t * 28.0) * 0.1, sin(t * 19.0) * 0.12)
	elif confront:
		h = Vector3(0.2 + sin(t * 0.6) * 0.2, sin(t * 0.5) * 0.5, 0.25)
	head.rotation = head.rotation.lerp(h, minf(delta * (14.0 if chase else 5.0), 1.0))

	var jo := 0.08 + sin(t * 1.3) * 0.04
	if chase:
		jo = 0.9 + sin(t * 26.0) * 0.12
	elif kill:
		jo = 1.0
	elif confront:
		jo = 0.55
	elif stare:
		jo = 0.3
	jaw.rotation.x = lerpf(jaw.rotation.x, -jo * 0.8, k)

	var hot := chase or stare or confront
	eye_mat.emission_energy_multiplier = (8.0 if hot else 4.0) + randf()
	eye_light.light_energy = 1.4 if hot else 0.6

	for i in rags.size():
		rags[i].rotation.x = sin(t * 1.7 + i) * 0.08 + amp * 0.3
		rags[i].rotation.z = sin(t * 1.3 + i * 2.0) * 0.05

	if amp > 0.25 and signf(sw) != signf(_prev_sin):
		footstep.emit()
	_prev_sin = sw
