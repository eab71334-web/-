extends Node3D
class_name Viewmodel
## First-person arms + flashlight attached to the camera, with walk bob and look sway.

var t := 0.0
var sway := Vector2.ZERO


func _ready() -> void:
	var sleeve := Util.mat(Color(0.16, 0.19, 0.15))
	var skin := Util.mat(Color(0.78, 0.6, 0.5))
	var metal := Util.mat(Color(0.07, 0.07, 0.08))
	metal.metallic = 0.6
	metal.roughness = 0.4
	var lens := Util.mat(Color(1.0, 0.95, 0.7), true)
	var fwd := Vector3(deg_to_rad(-90.0), 0, 0)
	Util.mesh(self, Util.caps(0.045, 0.5), sleeve, Vector3(0.27, -0.33, -0.28), Vector3(deg_to_rad(-70.0), 0, 0))
	Util.mesh(self, Util.sphere(0.05), skin, Vector3(0.27, -0.27, -0.5))
	Util.mesh(self, Util.cyl(0.03, 0.22), metal, Vector3(0.27, -0.25, -0.6), fwd)
	Util.mesh(self, Util.cyl(0.034, 0.02), lens, Vector3(0.27, -0.25, -0.72), fwd)
	Util.mesh(self, Util.caps(0.045, 0.5), sleeve, Vector3(-0.28, -0.4, -0.3), Vector3(deg_to_rad(-60.0), 0, deg_to_rad(8.0)))
	Util.mesh(self, Util.sphere(0.05), skin, Vector3(-0.25, -0.34, -0.5))


func update(delta: float, speed: float, look: Vector2) -> void:
	t += delta * (1.0 + speed * 1.6)
	var amp := clampf(speed / 3.0, 0.0, 1.4)
	sway = sway.lerp(look.limit_length(60.0), minf(delta * 8.0, 1.0))
	position = Vector3(sin(t * 2.0) * 0.012 * amp + sin(t * 0.7) * 0.003, -absf(sin(t * 2.0)) * 0.015 * amp + sin(t * 1.1) * 0.003, 0.0)
	rotation = Vector3(-sway.y * 0.0012, -sway.x * 0.0012, 0.0)
