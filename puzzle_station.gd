extends Interactable
class_name PuzzleStation
## A fuse box / keypad / TV in the level. Press E to open its puzzle (Interactable plumbing is reused).

var kind := "fuse"


func is_available() -> bool:
	return step_index < 0 or Game.step == step_index


func get_prompt() -> String:
	if kind == "tv" and not Game.has_tape:
		return "[E] " + label + " (لا إشارة)"
	return "[E] " + label


func _process(_delta: float) -> void:
	if _inside == null or Game.typing or not is_available():
		return
	if Input.is_action_just_pressed("interact"):
		Game.open_puzzle(kind, self)
