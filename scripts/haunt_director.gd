extends Node
class_name HauntDirector
## Builds dread with rhythm: distant sounds, doors that move, flicker, falling objects, a shadow at the end of a hall.
## It never lets her show herself fully (that is saved for the ritual). More events as the investigation advances.

var tension := 0.2
var cd := 14.0
var last := ""
var world: Node3D

const EVENTS := ["door", "steps_above", "hum", "flicker", "object", "shadow", "slam_far", "blackout"]
const MIN_PHASE := {"door": 0, "steps_above": 0, "hum": 0, "flicker": 0, "object": 1, "shadow": 1, "slam_far": 1, "blackout": 2}


func _process(delta: float) -> void:
	if Game.step < Game.Step.POWER or Game.step >= Game.Step.RITUAL or Game.typing:
		return
	var lp = Game.local_player
	if lp == null or not is_instance_valid(lp) or not lp.alive:
		return
	cd -= delta
	tension = minf(tension + delta * (0.03 + 0.012 * Game.step), 1.6)
	if tension >= 1.0 and cd <= 0.0:
		_fire(lp)


func _fire(lp) -> void:
	var phase := Game.reveal_level
	var pool: Array = []
	for e in EVENTS:
		if int(MIN_PHASE[e]) <= phase and e != last:
			pool.append(e)
	var pick: String = pool.pick_random()
	last = pick
	cd = maxf(randf_range(26.0, 50.0) - 6.0 * phase, 14.0)
	tension = 0.2
	var now := Time.get_ticks_msec()
	var pp: Vector3 = lp.global_position
	match pick:
		"door":
			_door(pp, 3.0, 14.0, -1)
		"slam_far":
			_door(pp, 12.0, 40.0, 0)
		"steps_above":
			_steps(pp)
		"hum":
			_hum(pp)
		"flicker":
			Game.chaos_until = now + 4000
		"blackout":
			Game.blackout_until = now + 2200
		"object":
			_object(lp)
		"shadow":
			_shadow(lp)


func _door(pp: Vector3, dmin: float, dmax: float, force: int) -> void:
	var cands: Array = []
	for d in get_tree().get_nodes_in_group("doors"):
		var dist: float = d.global_position.distance_to(pp)
		if dist >= dmin and dist <= dmax and absf(d.global_position.y - pp.y) < 2.5 and d.locked_flag == "":
			cands.append(d)
	if cands.is_empty():
		return
	var d = cands.pick_random()
	if force == 0:
		d.slam_shut()
	else:
		d.toggle()


func _steps(pp: Vector3) -> void:
	var snd := AudioStreamPlayer3D.new()
	snd.stream = ProcAudio.get_sound("thud")
	snd.unit_size = 6.0
	snd.volume_db = 4.0
	get_tree().current_scene.add_child(snd)
	var base := pp + Vector3(randf_range(-5.0, 5.0), 4.0, randf_range(-5.0, 5.0))
	for i in 6:
		snd.global_position = base + Vector3(i * 0.7, 0, i * 0.4)
		snd.pitch_scale = randf_range(0.8, 1.1)
		snd.play()
		await get_tree().create_timer(0.6).timeout
	snd.queue_free()


func _hum(pp: Vector3) -> void:
	var snd := AudioStreamPlayer3D.new()
	snd.stream = ProcAudio.get_sound("hum")
	snd.unit_size = 8.0
	snd.volume_db = 0.0
	get_tree().current_scene.add_child(snd)
	var a := randf() * TAU
	snd.global_position = pp + Vector3(cos(a) * 14.0, 0.5, sin(a) * 14.0)
	snd.play()
	snd.finished.connect(snd.queue_free)


func _object(lp) -> void:
	var rb := RigidBody3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.1
	cm.height = 0.05
	cm.material = Util.mat(Color(0.85, 0.85, 0.8))
	mi.mesh = cm
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.12
	sh.height = 0.05
	cs.shape = sh
	rb.add_child(mi)
	rb.add_child(cs)
	get_tree().current_scene.add_child(rb)
	var fwd: Vector3 = -lp.global_transform.basis.z
	rb.global_position = lp.global_position + fwd * 3.0 + Vector3(0, 1.4, 0)
	rb.apply_central_impulse(fwd * 1.5 + Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)))
	Util.play(self, "thud", -4.0)
	get_tree().create_timer(10.0).timeout.connect(rb.queue_free)


## A dark figure at the far end of a hall for a moment. Only if you are looking that way.
func _shadow(lp) -> void:
	var m = get_tree().current_scene.get_node_or_null("Monster")
	if m == null or not Game.is_host():
		return
	var fwd: Vector3 = -lp.cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized().rotated(Vector3.UP, randf_range(-0.4, 0.4))
	var spot: Vector3 = lp.global_position + fwd * randf_range(9.0, 13.0)
	var nav := get_tree().current_scene.get_world_3d().navigation_map
	spot = NavigationServer3D.map_get_closest_point(nav, spot)
	if absf(spot.y - lp.global_position.y) > 1.5:
		return
	m.flash(spot, 0.9)
