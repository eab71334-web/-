extends Area3D
class_name Interactable
## Generator / lever / wheel. Hold E to operate. Operating makes noise the monster hears.

var step_index := 0
var hold_time := 1.0
var noise := 0.5
var label := ""
var held := 0.0
var visual: Node3D
var _inside = null
var _noise_cd := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		b.current_interactable = self
		_inside = b


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		if b.current_interactable == self:
			b.current_interactable = null


func is_available() -> bool:
	return Game.step == step_index


func get_prompt() -> String:
	if held > 0.0:
		return "%s  %d%%" % [label, int(held / hold_time * 100.0)]
	return "[اضغط مطولاً E] " + label


func _process(delta: float) -> void:
	if _inside == null or not is_available():
		return
	if not _inside.alive or _inside.hidden:
		return
	if Input.is_action_pressed("interact"):
		if held == 0.0:
			Game.fire("make_noise", [global_position, noise])
		held += delta
		_noise_cd -= delta
		if _noise_cd <= 0.0:
			_noise_cd = 1.0
			Game.fire("make_noise", [global_position, noise * 0.6])
		if held >= hold_time:
			held = 0.0
			Game.fire("complete_step", [step_index])
	else:
		held = maxf(held - delta * 0.5, 0.0)
	if visual:
		visual.rotation.z = held * 1.2
