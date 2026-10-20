extends Area3D
class_name ExitZone


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body)


func _on_body(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b) and Game.step == Game.Step.EXIT:
		Game.fire("complete_step", [Game.Step.EXIT])
