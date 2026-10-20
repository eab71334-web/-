extends Node3D
class_name HumanRig
## Simple humanoid for other players (jacket, backpack, flashlight).

var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var t := 0.0


func build(jacket: Color) -> void:
	var skin := Util.mat(Color(0.8, 0.62, 0.5))
	var cloth := Util.mat(jacket)
	var pants := Util.mat(Color(0.12, 0.13, 0.18))
	var gear := Util.mat(Color(0.08, 0.08, 0.08))
	Util.mesh(self, Util.bmesh(Vector3(0.42, 0.6, 0.22)), cloth, Vector3(0, 1.15, 0))
	Util.mesh(self, Util.bmesh(Vector3(0.3, 0.4, 0.14)), gear, Vector3(0, 1.2, 0.18))
	Util.mesh(self, Util.sphere(0.12), skin, Vector3(0, 1.58, 0))
	Util.mesh(self, Util.cyl(0.125, 0.06), gear, Vector3(0, 1.67, -0.01))
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.1 * s, 0.88, 0)
		add_child(leg)
		Util.mesh(leg, Util.caps(0.07, 0.9), pants, Vector3(0, -0.43, 0))
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.27 * s, 1.4, 0)
		add_child(arm)
		Util.mesh(arm, Util.caps(0.05, 0.6), cloth, Vector3(0, -0.28, 0))
		if s > 0.0:
			Util.mesh(arm, Util.cyl(0.03, 0.2), gear, Vector3(0, -0.6, -0.08), Vector3(-PI / 2.0, 0, 0))
			Util.mesh(arm, Util.cyl(0.034, 0.02), Util.mat(Color(1, 0.95, 0.7), true), Vector3(0, -0.6, -0.19), Vector3(-PI / 2.0, 0, 0))
		arms.append(arm)


func animate(delta: float, speed: float) -> void:
	if legs.is_empty():
		return
	t += delta * speed * 2.2
	var amp := clampf(speed / 3.0, 0.0, 1.5)
	legs[0].rotation.x = sin(t) * 0.7 * amp
	legs[1].rotation.x = -sin(t) * 0.7 * amp
	arms[0].rotation.x = -sin(t) * 0.5 * amp
	arms[1].rotation.x = 0.5 + sin(t) * 0.2 * amp
