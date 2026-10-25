extends Area3D
class_name TapePickup
## The VHS tape that contains the 1987 news report (it holds the keypad code).

var _inside = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		_inside = b
		Game.near_prompt = "[E] خذ شريط VHS"


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		Game.near_prompt = ""


func _process(_delta: float) -> void:
	if _inside != null and not Game.typing and Input.is_action_just_pressed("interact"):
		Game.hand_reach()
		Game.add_item("tape")
		Game.near_prompt = ""
		Game.subtitle.emit("حصلتَ على شريط VHS — شاهده على التلفاز في القاعة الشرقية")
		Util.play(self, "click")
		queue_free()
