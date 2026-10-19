extends CanvasLayer
class_name Hud

var prompt: Label
var objective: Label
var subtitle: Label
var noise_bar: ProgressBar
var confront: PanelContainer
var confront_name: Label
var fade: ColorRect
var end_panel: PanelContainer
var end_label: Label
var restart_btn: Button
var _sub_t := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_mk(root, 0.5, -24, 28).text = "·"
	prompt = _mk(root, 0.8, 0, 22)
	objective = _mk(root, 0.0, 12, 20)
	subtitle = _mk(root, 0.68, 0, 34)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.05, 0.05))

	noise_bar = ProgressBar.new()
	noise_bar.anchor_top = 1.0
	noise_bar.anchor_bottom = 1.0
	noise_bar.offset_left = 20
	noise_bar.offset_right = 220
	noise_bar.offset_top = -40
	noise_bar.offset_bottom = -22
	noise_bar.show_percentage = false
	noise_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(noise_bar)

	# name + health bar shown when the monster stands over your hiding spot
	confront = PanelContainer.new()
	confront.anchor_left = 0.35
	confront.anchor_right = 0.65
	confront.anchor_top = 0.55
	confront.anchor_bottom = 0.55
	confront.offset_bottom = 70
	confront.visible = false
	var vb := VBoxContainer.new()
	confront.add_child(vb)
	confront_name = Label.new()
	confront_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(confront_name)
	var hp := ProgressBar.new()
	hp.value = 100
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 14)
	vb.add_child(hp)
	root.add_child(confront)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.visible = false
	var eb := VBoxContainer.new()
	end_panel.add_child(eb)
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 30)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eb.add_child(end_label)
	restart_btn = Button.new()
	restart_btn.text = "حاول مجدداً"
	restart_btn.pressed.connect(func(): Game.restart())
	eb.add_child(restart_btn)
	root.add_child(end_panel)

	Game.objective_changed.connect(func(t): objective.text = t)
	Game.subtitle.connect(func(t):
		subtitle.text = t
		_sub_t = 2.5)
	Game.confrontation.connect(_on_confront)
	Game.fade_requested.connect(_on_dead)
	Game.game_over.connect(func(): _show_end("انتهت اللعبة… قتلك الظل", true))
	Game.game_won.connect(func(): _show_end("أغلقت الباب خلفك… نجوت!", true))


func _mk(root: Control, ay: float, off: float, size: int) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = ay
	l.anchor_bottom = ay
	l.offset_top = off
	l.offset_bottom = off + 44
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _on_confront(vid: int, on: bool) -> void:
	confront.visible = on and vid == multiplayer.get_unique_id()
	confront_name.text = Game.player_name


func _on_dead() -> void:
	create_tween().tween_property(fade, "color:a", 1.0, 1.0)
	_show_end("قتلك الظل…", false)


func _show_end(text: String, with_button: bool) -> void:
	end_label.text = text
	end_panel.visible = true
	restart_btn.visible = with_button and (Game.solo or multiplayer.is_server())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if with_button:
		fade.color.a = maxf(fade.color.a, 0.6)


func _process(delta: float) -> void:
	_sub_t -= delta
	if _sub_t <= 0.0:
		subtitle.text = ""
	var lp = Game.local_player
	if lp == null or not is_instance_valid(lp) or not lp.alive:
		prompt.text = ""
		return
	var it = lp.current_interactable
	if lp.hidden:
		prompt.text = "[E] اخرج من المخبأ"
	elif it != null and it.is_available():
		prompt.text = it.get_prompt()
	elif lp.in_hide_zone != null:
		if lp.posture == Player.Posture.CROUCH or lp.posture == Player.Posture.CRAWL:
			prompt.text = "[E] اختبئ"
		else:
			prompt.text = "انحنِ (C) أو ازحف (Z) ثم [E] للاختباء"
	else:
		prompt.text = ""
	noise_bar.value = clampf(lp.noise_level, 0.0, 1.0) * 100.0
