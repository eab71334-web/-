extends Node3D
class_name HingedDoor
## A real swinging door: E opens/closes it. The ghost opens, slams and locks doors too.

var width := 1.6
var locked_flag := ""        # if set: the door only opens when Game.has_flag(locked_flag)
var open_angle := 105.0
var is_open := false
var slab: StaticBody3D
var base_y := 0.0
var _inside = null
var _tw: Tween
var _prompt_text := ""


func _ready() -> void:
	add_to_group("doors")
	base_y = rotation_degrees.y
	slab = StaticBody3D.new()
	slab.collision_layer = 8          # players collide with doors; the ghost walks through them
	slab.collision_mask = 0
	slab.position = Vector3(width / 2.0, 1.3, 0.0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 2.6, 0.08)
	bm.material = Util.grunge(Color(0.3, 0.2, 0.12))
	mi.mesh = bm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	slab.add_child(mi)
	slab.add_child(cs)
	add_child(slab)
	var trig := Area3D.new()
	trig.collision_layer = 0
	trig.collision_mask = 2
	var tcs := CollisionShape3D.new()
	var tbs := BoxShape3D.new()
	tbs.size = Vector3(width + 1.2, 2.6, 2.6)
	tcs.shape = tbs
	trig.position = Vector3(width / 2.0, 1.3, 0.0)
	trig.add_child(tcs)
	add_child(trig)
	trig.body_entered.connect(_on_enter)
	trig.body_exited.connect(_on_exit)


func _on_enter(b) -> void:
	if b.is_in_group("players") and Game.is_mine(b):
		_inside = b


func _on_exit(b) -> void:
	if b == _inside:
		_inside = null
		if Game.near_prompt == _prompt_text:
			Game.near_prompt = ""


func _is_locked() -> bool:
	return locked_flag != "" and not Game.has_flag(locked_flag)


func _process(_delta: float) -> void:
	if _inside == null or Game.typing or Game.camera_on:
		return
	_prompt_text = "مقفل" if _is_locked() else ("[E] أغلق الباب" if is_open else "[E] افتح الباب")
	Game.near_prompt = _prompt_text
	if Input.is_action_just_pressed("interact"):
		if _is_locked():
			Util.play(self, "buzz", -10.0)
			Game.subtitle.emit("الباب مقفل… شيء يمنعه من الداخل.")
		else:
			Game.hand_reach()
			toggle()


func toggle(force := -1) -> void:
	var want := (not is_open) if force < 0 else (force == 1)
	if want == is_open:
		return
	is_open = want
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "rotation_degrees:y", base_y + (open_angle if is_open else 0.0), 0.6)
	Util.play(self, "creak", -8.0)


func slam_shut() -> void:
	if _tw != null:
		_tw.kill()
	is_open = false
	_tw = create_tween()
	_tw.tween_property(self, "rotation_degrees:y", base_y, 0.15)
	Util.play(self, "slam", -2.0)
