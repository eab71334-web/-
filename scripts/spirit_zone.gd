extends Area3D
class_name SpiritZone
## A place where she is "close". Record audio (V) while standing here to capture her voice (EVP).

var evp_id := ""
var voice := ""
var size := Vector3(6, 3, 6)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		Game.in_zone = self


func _on_exit(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b) and Game.in_zone == self:
		Game.in_zone = null
