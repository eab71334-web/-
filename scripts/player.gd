extends CharacterBody3D
class_name Player
## First-person player. Posture + noise level are what the monster senses.

enum Posture { STAND, RUN, CROUCH, CRAWL, HIDING }

const SPEEDS := {0: 3.0, 1: 5.5, 2: 1.6, 3: 0.8}
const MOUSE_SENS := 0.0025

var display_name := "Player"
var posture: int = Posture.STAND
var noise_level := 0.0     # 0..1.5, replicated: monster hears based on this
var speed_now := 0.0       # replicated: monster sees movement based on this
var alive := true
var hidden := false
var locked := false
var in_hide_zone: HideZone = null
var current_interactable: Interactable = null
var crouch_on := false
var crawl_on := false

var head: Node3D
var cam: Camera3D
var light: SpotLight3D
var shape: CapsuleShape3D
var col: CollisionShape3D
var pitch := 0.0
var _shake := 0.0


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	add_to_group("players")
	collision_layer = 2
	collision_mask = 1


func _ready() -> void:
	col = CollisionShape3D.new()
	shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.near = 0.05
	head.add_child(cam)
	light = SpotLight3D.new()
	light.spot_range = 16.0
	light.spot_angle = 38.0
	light.light_energy = 2.0
	head.add_child(light)

	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation", ":noise_level", ":speed_now", ":posture", ":hidden"]:
		cfg.add_property(NodePath(prop))
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = cfg
	add_child(sync)

	if is_multiplayer_authority():
		cam.current = true
		Game.local_player = self
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		light.visible = false
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.35
		cm.height = 1.8
		cm.material = Util.mat(Color(0.2, 0.4, 0.8))
		mi.mesh = cm
		mi.position.y = 0.9
		add_child(mi)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or locked or not alive:
		return
	if event is InputEventMouseMotion:
		if not Game.touch_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_look(event.relative)
	elif event.is_action_pressed("crouch") and not hidden:
		crouch_on = not crouch_on
		crawl_on = false
	elif event.is_action_pressed("crawl") and not hidden:
		crawl_on = not crawl_on
		crouch_on = false
	elif event.is_action_pressed("flashlight"):
		light.visible = not light.visible
	elif event.is_action_pressed("interact"):
		_toggle_hide()
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func apply_look(rel: Vector2) -> void:
	if not is_multiplayer_authority() or locked or not alive:
		return
	rotate_y(-rel.x * MOUSE_SENS)
	pitch = clampf(pitch - rel.y * MOUSE_SENS, -1.4, 1.4)
	head.rotation.x = pitch


func _toggle_hide() -> void:
	if hidden:
		hidden = false
		posture = Posture.CROUCH
		crouch_on = true
		crawl_on = false
	elif in_hide_zone != null and (crouch_on or crawl_on) \
			and (current_interactable == null or not current_interactable.is_available()):
		hidden = true
		posture = Posture.HIDING


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if locked or not alive:
		velocity = Vector3.ZERO
		speed_now = 0.0
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if hidden:
		velocity = Vector3.ZERO
		speed_now = 0.0
		posture = Posture.HIDING
	else:
		if Input.is_action_pressed("sprint") and input != Vector2.ZERO and not crouch_on and not crawl_on:
			posture = Posture.RUN
		elif crawl_on:
			posture = Posture.CRAWL
		elif crouch_on:
			posture = Posture.CROUCH
		else:
			posture = Posture.STAND
		var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
		var spd: float = SPEEDS[posture]
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
		move_and_slide()
		speed_now = Vector2(velocity.x, velocity.z).length()
	noise_level = _compute_noise()
	_update_body(delta)


func _compute_noise() -> float:
	var base := 0.02
	if speed_now > 0.2:
		match posture:
			Posture.RUN: base = 1.0
			Posture.STAND: base = 0.45
			Posture.CROUCH: base = 0.2
			Posture.CRAWL: base = 0.1
	if hidden:
		base = 0.05
	var mic := Mic.loudness if Game.use_mic and Mic.enabled else 0.0
	return clampf(base + mic, 0.0, 1.5)


func _update_body(delta: float) -> void:
	var head_h := 1.6
	var cap_h := 1.8
	match posture:
		Posture.CROUCH:
			head_h = 1.0
			cap_h = 1.1
		Posture.CRAWL:
			head_h = 0.45
			cap_h = 0.7
		Posture.HIDING:
			head_h = 0.6
			cap_h = 0.7
	head.position.y = move_toward(head.position.y, head_h, delta * 3.0)
	shape.height = move_toward(shape.height, cap_h, delta * 3.0)
	col.position.y = shape.height * 0.5


func _process(delta: float) -> void:
	if _shake > 0.0:
		cam.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.1
		_shake = move_toward(_shake, 0.0, delta * 0.8)
	elif cam.position != Vector3.ZERO:
		cam.position = Vector3.ZERO


# ---- called by the monster's kill sequence --------------------------------
func on_killed_start() -> void:
	alive = false
	locked = true
	hidden = false
	velocity = Vector3.ZERO
	current_interactable = null


func face_point(p: Vector3) -> void:
	var d := p - head.global_position
	rotation.y = atan2(-d.x, -d.z)
	pitch = clampf(asin(d.y / maxf(d.length(), 0.001)), -1.4, 1.4)
	head.rotation.x = pitch


func look_down() -> void:
	pitch = -1.3
	head.rotation.x = pitch


func shake(strength: float) -> void:
	_shake = strength


func finish_death() -> void:
	Game.fade_requested.emit()
	Game.register_death.rpc(str(name).to_int())
