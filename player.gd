extends CharacterBody3D
class_name Player
## First-person player. Posture + noise level are what the monster senses.

enum Posture { STAND, RUN, CROUCH, CRAWL, HIDING }

const SPEEDS := {0: 3.0, 1: 5.5, 2: 1.6, 3: 0.8}
const MOUSE_SENS := 0.0025
const SUIT_COLORS := [Color(0.2, 0.35, 0.6), Color(0.6, 0.25, 0.2), Color(0.25, 0.5, 0.3), Color(0.55, 0.45, 0.15)]

var display_name := "Player"
var posture: int = Posture.STAND
var noise_level := 0.0     # replicated: monster hears based on this
var speed_now := 0.0       # replicated: monster sees movement based on this
var alive := true
var hidden := false
var locked := false
var in_hide_zone: HideZone = null
var current_interactable: Interactable = null
var crouch_on := false
var crawl_on := false
var flash_on := true

var head: Node3D
var cam: Camera3D
var light: SpotLight3D
var shape: CapsuleShape3D
var col: CollisionShape3D
var vm: Viewmodel
var rig: HumanRig
var pitch := 0.0
var _shake := 0.0
var _bob_t := 0.0
var _look_delta := Vector2.ZERO


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	add_to_group("players")
	collision_layer = 2
	collision_mask = 9          # world + doors


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
	cam.fov = 75.0
	head.add_child(cam)
	light = SpotLight3D.new()
	light.spot_range = 22.0
	light.spot_angle = 45.0
	light.light_energy = 5.0
	head.add_child(light)

	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation", ":noise_level", ":speed_now", ":posture", ":hidden"]:
		cfg.add_property(NodePath(prop))
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = cfg
	add_child(sync)

	if Game.is_mine(self):
		cam.current = true
		Game.local_player = self
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		vm = Viewmodel.new()
		cam.add_child(vm)
		Mic.utterance.connect(_on_utterance)
	else:
		light.visible = false
		rig = HumanRig.new()
		add_child(rig)
		rig.build(SUIT_COLORS[absi(str(name).to_int()) % 4])
		var lbl := Label3D.new()
		lbl.text = display_name
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.pixel_size = 0.005
		lbl.position = Vector3(0, 2.0, 0)
		add_child(lbl)


func _unhandled_input(event: InputEvent) -> void:
	if not Game.is_mine(self) or locked or not alive:
		return
	if event is InputEventMouseMotion:
		if not Game.touch_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_look(event.relative)
	elif event.is_action_pressed("crouch"):
		do_crouch()
	elif event.is_action_pressed("crawl"):
		do_crawl()
	elif event.is_action_pressed("flashlight"):
		do_flashlight()
	elif event.is_action_pressed("camera"):
		toggle_camera()
	elif event.is_action_pressed("recorder"):
		do_recorder()
	elif event.is_action_pressed("interact"):
		do_interact()
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---- actions (called by keyboard AND by the touch buttons) ------------------
func apply_look(rel: Vector2) -> void:
	if not Game.is_mine(self) or locked or not alive:
		return
	rotate_y(-rel.x * MOUSE_SENS)
	pitch = clampf(pitch - rel.y * MOUSE_SENS, -1.4, 1.4)
	head.rotation.x = pitch
	_look_delta += rel


func do_crouch() -> void:
	if locked or not alive or hidden:
		return
	crouch_on = not crouch_on
	crawl_on = false


func do_crawl() -> void:
	if locked or not alive or hidden:
		return
	crawl_on = not crawl_on
	crouch_on = false


func do_flashlight() -> void:
	flash_on = not flash_on


func do_interact() -> void:
	if locked or not alive:
		return
	if Game.camera_on:
		_shutter()
		return
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
	if not Game.is_mine(self):
		return
	if locked or not alive:
		velocity = Vector3.ZERO
		speed_now = 0.0
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Game.typing:
		input = Vector2.ZERO
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
		var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized() * minf(input.length(), 1.0)
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
	if not Game.is_mine(self):
		if rig != null:
			rig.animate(delta, speed_now)
			var sy := 1.0
			match posture:
				Posture.CROUCH: sy = 0.65
				Posture.CRAWL: sy = 0.4
				Posture.HIDING: sy = 0.4
			rig.scale.y = lerpf(rig.scale.y, sy, minf(delta * 6.0, 1.0))
		return
	# camera bob + shake
	var bob := Vector3.ZERO
	if speed_now > 0.2:
		_bob_t += delta * speed_now * 2.0
		bob = Vector3(sin(_bob_t) * 0.015, absf(sin(_bob_t)) * 0.03, 0.0)
	var sh := Vector3.ZERO
	if _shake > 0.0:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.1
		_shake = move_toward(_shake, 0.0, delta * 0.8)
	cam.position = bob + sh
	# fear level from the monster's distance / state
	var m = get_parent().get_node_or_null("Monster")
	var tgt := 0.0
	if m != null:
		tgt = clampf(1.0 - global_position.distance_to(m.global_position) / 18.0, 0.0, 1.0)
		if m.state == 2 or m.state == 3:
			tgt = maxf(tgt, 0.75)
		elif m.state == 5:
			tgt = maxf(tgt, 0.9)
	Game.threat = lerpf(Game.threat, tgt, minf(delta * 2.5, 1.0))
	cam.fov = lerpf(cam.fov, 45.0 if Game.camera_on else 75.0 + Game.threat * 10.0, minf(delta * 3.0, 1.0))
	light.visible = flash_on and Game.battery > 0.0 and Time.get_ticks_msec() >= Game.blackout_until
	if light.visible:
		Game.consume(0.3 * delta)
	if Game.camera_on:
		Game.consume(0.45 * delta)
	_look_delta = _look_delta.lerp(Vector2.ZERO, minf(delta * 10.0, 1.0))
	if vm != null:
		vm.update(delta, speed_now, _look_delta)


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
	Game.fire("register_death", [str(name).to_int()])


func _on_utterance(dur: float, peak: float) -> void:
	if not alive or locked or not Game.use_mic:
		return
	Game.fire("report_speech", [str(name).to_int(), dur, peak, ""])


# ---- investigator tools: camera (R), audio recorder (V); battery is shared with the flashlight ----
func toggle_camera() -> void:
	if locked or not alive:
		return
	if not Game.camera_on and Game.battery <= 0.0:
		Game.subtitle.emit("البطارية فارغة…")
		return
	Game.camera_on = not Game.camera_on
	Util.play(self, "click", -4.0)


func _shutter() -> void:
	if Game.battery < 3.0:
		Game.subtitle.emit("البطارية لا تكفي للتصوير")
		return
	Game.consume(3.0)
	Util.play(self, "click", -2.0)
	Game.photo_taken.emit()
	for m in get_tree().get_nodes_in_group("evidence"):
		if m.try_capture(cam):
			Game.add_evidence(m.id)
			Game.subtitle.emit("التقطتَ شيئاً لا يجب أن يكون هناك…")


func do_recorder() -> void:
	if Game.recording or locked or not alive:
		return
	if Game.battery < 6.0:
		Game.subtitle.emit("البطارية لا تكفي للتسجيل")
		return
	Game.consume(6.0)
	Game.recording = true
	Game.subtitle.emit("● جارٍ التسجيل… ٨ ثوانٍ (اثبت وصمت)")
	Util.play(self, "hiss", -10.0)
	get_tree().create_timer(8.0).timeout.connect(_finish_recording)


func _finish_recording() -> void:
	Game.recording = false
	var z = Game.in_zone
	if z != null and is_instance_valid(z):
		Game.subtitle.emit("[تسجيل] " + z.voice)
		Util.speak(z.voice, 0.35, 0.65)
		Game.add_evp(z.evp_id)
	else:
		Game.subtitle.emit("[تسجيل] تشويش فقط… جرّب مكاناً آخر.")
