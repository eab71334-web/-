extends Area3D
class_name LoreNote
## A story document lying in the level. Press E near it to read.

var idx := 0
var _inside = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		_inside = b
		Game.near_note = idx


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		if Game.near_note == idx:
			Game.near_note = -1


func _process(_delta: float) -> void:
	if _inside != null and not Game.typing and Input.is_action_just_pressed("interact"):
		Game.open_note(idx)
