extends Node3D
class_name HiddenWriting
## Writing on the wall that is invisible to the naked eye: it only shows while your flashlight is on and aimed at it.

var text := ""
var label: Label3D


func _ready() -> void:
	label = Label3D.new()
	label.text = text
	label.font_size = 220
	label.pixel_size = 0.004
	label.outline_size = 14
	label.shaded = false
	label.double_sided = true
	label.modulate = Color(0.85, 0.05, 0.05, 0.0)
	add_child(label)


func _process(delta: float) -> void:
	var lp = Game.local_player
	var a := 0.0
	if lp != null and is_instance_valid(lp) and lp.light.visible:
		var to: Vector3 = global_position - lp.cam.global_position
		var d := to.length()
		if d < 9.0 and (-lp.cam.global_transform.basis.z).dot(to.normalized()) > 0.9:
			a = clampf(1.2 - d / 9.0, 0.0, 1.0)
	label.modulate.a = lerpf(label.modulate.a, a, minf(delta * 6.0, 1.0))
