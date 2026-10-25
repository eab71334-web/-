extends Area3D
class_name LockedDoor
## Resident-Evil style locked door: needs a key item. Once opened it stays open (saved) = a permanent shortcut.

var door_id := ""
var need_item := ""
var slab: StaticBody3D
var _inside = null
var _open := false
var _prompt_text := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	if Game.has_flag("door_" + door_id):
		_open = true
		if slab != null:
			slab.queue_free()


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		_inside = b


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		if Game.near_prompt == _prompt_text:
			Game.near_prompt = ""


func _process(_delta: float) -> void:
	if _inside == null or _open or Game.typing:
		return
	var ok := need_item == "" or Game.has_item(need_item)
	_prompt_text = "[E] افتح" if ok else "مغلق — يلزم: " + Game.item_name(need_item)
	Game.near_prompt = _prompt_text
	if Input.is_action_just_pressed("interact"):
		if ok:
			_open = true
			Game.near_prompt = ""
			Game.hand_reach()
			Game.set_flag("door_" + door_id)
			Util.play(self, "creak", -4.0)
			if slab != null:
				var tw := create_tween()
				tw.tween_property(slab, "position:y", slab.position.y - 3.8, 1.4)
				tw.tween_callback(slab.queue_free)
				tw.tween_callback(func(): Game.door_opened.emit())
		else:
			Util.play(self, "buzz", -8.0)
			Game.subtitle.emit("مغلق… يلزم: " + Game.item_name(need_item))
