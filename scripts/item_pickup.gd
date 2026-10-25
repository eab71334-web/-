extends Area3D
class_name ItemPickup
## A key item lying in the world. Appears only once the story reaches `min_step`.

var item_id := ""
var min_step := 0
var _inside = null
var _prompt_text := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	if Game.has_item(item_id):
		queue_free()


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		_inside = b


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		if Game.near_prompt == _prompt_text:
			Game.near_prompt = ""


func _process(_delta: float) -> void:
	visible = Game.step >= min_step
	if _inside == null or not visible or Game.typing:
		return
	_prompt_text = "[E] خذ " + Game.item_name(item_id)
	Game.near_prompt = _prompt_text
	if Input.is_action_just_pressed("interact"):
		Game.near_prompt = ""
		Game.hand_reach()
		Game.add_item(item_id)
		queue_free()
