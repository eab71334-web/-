extends Area3D
class_name BatteryPickup
## +35% battery. The pack is limited and shared by flashlight, camera and recorder.

var _inside = null
const TEXT := "[E] خذ بطارية"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.2, 2.0, 2.2)
	cs.shape = bs
	add_child(cs)
	Util.mesh(self, Util.cyl(0.04, 0.12), Util.mat(Color(0.9, 0.75, 0.1)), Vector3(0, 0.06, 0), Vector3(0, 0, PI / 2.0))
	Util.mesh(self, Util.cyl(0.02, 0.02), Util.mat(Color(0.8, 0.8, 0.8)), Vector3(0.07, 0.06, 0), Vector3(0, 0, PI / 2.0))
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		_inside = b


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		if Game.near_prompt == TEXT:
			Game.near_prompt = ""


func _process(_delta: float) -> void:
	if _inside == null or Game.typing or Game.camera_on:
		return
	Game.near_prompt = TEXT
	if Input.is_action_just_pressed("interact"):
		Game.near_prompt = ""
		Game.hand_reach()
		Game.add_battery(35.0)
		Game.subtitle.emit("بطارية +35%")
		Util.play(self, "click")
		queue_free()
