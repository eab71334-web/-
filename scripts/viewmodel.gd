extends Node3D
class_name Viewmodel
## First-person hands: right hand holds the flashlight and REACHES when you interact;
## left hand raises and shows each item you pick up (spinning) before lowering it again.

var t := 0.0
var sway := Vector2.ZERO
var right: Node3D
var left: Node3D
var held: Node3D
var _item: Node3D = null


func _ready() -> void:
	var sleeve := Util.mat(Color(0.16, 0.19, 0.15))
	var skin := Util.mat(Color(0.78, 0.6, 0.5))
	var metal := Util.mat(Color(0.07, 0.07, 0.08))
	metal.metallic = 0.6
	metal.roughness = 0.4
	var lens := Util.mat(Color(1.0, 0.95, 0.7), true)
	var fwd := Vector3(deg_to_rad(-90.0), 0, 0)
	right = Node3D.new()
	add_child(right)
	Util.mesh(right, Util.caps(0.045, 0.5), sleeve, Vector3(0.27, -0.33, -0.28), Vector3(deg_to_rad(-70.0), 0, 0))
	Util.mesh(right, Util.sphere(0.05), skin, Vector3(0.27, -0.27, -0.5))
	Util.mesh(right, Util.cyl(0.03, 0.22), metal, Vector3(0.27, -0.25, -0.6), fwd)
	Util.mesh(right, Util.cyl(0.034, 0.02), lens, Vector3(0.27, -0.25, -0.72), fwd)
	left = Node3D.new()
	add_child(left)
	Util.mesh(left, Util.caps(0.045, 0.5), sleeve, Vector3(-0.28, -0.4, -0.3), Vector3(deg_to_rad(-60.0), 0, deg_to_rad(8.0)))
	Util.mesh(left, Util.sphere(0.05), skin, Vector3(-0.25, -0.34, -0.5))
	held = Node3D.new()
	held.position = Vector3(-0.25, -0.28, -0.52)
	left.add_child(held)


## Right hand pushes forward (opening doors, pressing buttons, grabbing).
func reach() -> void:
	var tw := create_tween()
	tw.tween_property(right, "position:z", -0.2, 0.14).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(right, "position:z", 0.0, 0.3)


## Left hand lifts a newly found item into view, turns it, then lowers it.
func show_item(id: String) -> void:
	if _item != null and is_instance_valid(_item):
		_item.queue_free()
	_item = ItemModel.build(id)
	held.add_child(_item)
	held.rotation = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(left, "position", Vector3(0.18, 0.2, -0.1), 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(held, "rotation:y", TAU * 1.5, 2.2)
	tw.tween_interval(0.3)
	tw.tween_property(left, "position", Vector3.ZERO, 0.4)
	tw.tween_callback(func():
		if _item != null and is_instance_valid(_item):
			_item.queue_free()
		_item = null)


func update(delta: float, speed: float, look: Vector2) -> void:
	t += delta * (1.0 + speed * 1.6)
	var amp := clampf(speed / 3.0, 0.0, 1.4)
	sway = sway.lerp(look.limit_length(60.0), minf(delta * 8.0, 1.0))
	position = Vector3(sin(t * 2.0) * 0.012 * amp + sin(t * 0.7) * 0.003, -absf(sin(t * 2.0)) * 0.015 * amp + sin(t * 1.1) * 0.003, 0.0)
	rotation = Vector3(-sway.y * 0.0012, -sway.x * 0.0012, 0.0)
