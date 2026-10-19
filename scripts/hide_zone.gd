extends Area3D
class_name HideZone
## A pile of crates the player can crouch behind. The monster learns which ones get used.

var score := 0.0            # learned by the monster
var last_checked := 0       # msec
var crates: Array = []


func _ready() -> void:
	add_to_group("hide_zones")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players"):
		b.in_hide_zone = self


func _on_exit(b) -> void:
	if b.is_in_group("players") and b.in_hide_zone == self:
		b.in_hide_zone = null


func shatter() -> void:
	for c in crates:
		if not is_instance_valid(c):
			continue
		for i in 4:
			var rb := RigidBody3D.new()
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * 0.25
			bm.material = Util.mat(Color(0.36, 0.22, 0.1))
			mi.mesh = bm
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			rb.add_child(mi)
			rb.add_child(cs)
			get_parent().add_child(rb)
			rb.global_position = c.global_position + Vector3(randf() - 0.5, 0.6 + randf(), randf() - 0.5)
			rb.apply_central_impulse(Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3)))
		c.queue_free()
	crates.clear()
