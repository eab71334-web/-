extends Interactable
class_name DigSpot
## Hold E with the shovel to dig under the willow. Digging is loud.


func is_available() -> bool:
	return Game.step == step_index


func get_prompt() -> String:
	if not Game.has_item("shovel"):
		return "الأرض هنا طريّة… تحتاج مجرفة"
	if held > 0.0:
		return "%s  %d%%" % [label, int(held / hold_time * 100.0)]
	return "[اضغط مطولاً E] " + label


func _process(delta: float) -> void:
	if _inside == null or not is_available() or not Game.has_item("shovel") or Game.typing:
		return
	if Input.is_action_pressed("interact"):
		held += delta
		_noise_cd -= delta
		if _noise_cd <= 0.0:
			_noise_cd = 0.8
			Util.play(self, "thud", -6.0)
			Game.fire("make_noise", [global_position, 0.6])
		if held >= hold_time:
			held = 0.0
			Game.add_item("toy_shoe")
	else:
		held = maxf(held - delta * 0.5, 0.0)
