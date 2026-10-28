extends Node3D
class_name Npc
## A member of the family: press E to hear their story / mission. Lines depend on how far the investigation is.

const COLORS := {"saeed": Color(0.3, 0.25, 0.2), "layla": Color(0.5, 0.2, 0.3), "halima": Color(0.2, 0.2, 0.25), "maryam": Color(0.6, 0.5, 0.7), "ziad": Color(0.3, 0.5, 0.4)}
const SCALES := {"saeed": 1.0, "layla": 0.96, "halima": 0.9, "maryam": 0.93, "ziad": 0.7}

var id := "saeed"
var rig: HumanRig
var _inside = null
var _busy := false
var _prompt_text := ""


func _ready() -> void:
	rig = HumanRig.new()
	add_child(rig)
	rig.build(COLORS.get(id, Color(0.4, 0.4, 0.4)))
	rig.scale = Vector3.ONE * float(SCALES.get(id, 1.0))
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 2.4, 3.2)
	cs.shape = bs
	a.position.y = 1.2
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_on_enter)
	a.body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		_inside = b


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		if Game.near_prompt == _prompt_text:
			Game.near_prompt = ""


func _process(delta: float) -> void:
	rig.animate(delta, 0.0)
	if _inside == null or _busy or Game.typing or Game.camera_on:
		return
	var d: Vector3 = _inside.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(delta * 4.0, 1.0))      # turns toward you
	_prompt_text = "[E] تحدّث مع " + str(Game.FAMILY[id]["name"])
	Game.near_prompt = _prompt_text
	if Input.is_action_just_pressed("interact"):
		_talk()


func _talk() -> void:
	_busy = true
	Game.near_prompt = ""
	var f: Dictionary = Game.FAMILY[id]
	for l in Game.family_lines(id):
		Game.subtitle.emit("%s: %s" % [f["name"], l])
		Util.speak(l, float(f["pitch"]), 0.95)
		await get_tree().create_timer(1.4 + l.length() * 0.06).timeout
	Game.set_flag("talked_" + id)
	_busy = false
