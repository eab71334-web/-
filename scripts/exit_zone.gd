extends Area3D
class_name ExitZone
## Crossing the threshold starts the door-closing struggle (DoorQTE). Winning it ends the night.

var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body)


func _on_body(b) -> void:
	if _fired:
		return
	if b.is_in_group("players") and Game.is_mine(b) and Game.step == Game.Step.EXIT:
		_fired = true
		Game.open_puzzle("door", self)
