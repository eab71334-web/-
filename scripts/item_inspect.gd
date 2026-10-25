extends Control
class_name ItemInspect
## Inventory screen: pick an item, it turns slowly in 3D (drag to rotate) with its description.

signal closed

var holder: Node3D
var desc: Label
var _drag := false


func _ready() -> void:
	theme = UITheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	panel.add_child(h)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(260, 0)
	list.add_theme_constant_override("separation", 10)
	h.add_child(list)
	var title := Label.new()
	title.text = "الأغراض"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.12))
	list.add_child(title)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.custom_minimum_size = Vector2(320, 300)
	svc.gui_input.connect(_on_drag)
	right.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 0.42)
	sv.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 1.6
	sv.add_child(light)
	holder = Node3D.new()
	sv.add_child(holder)
	desc = Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 120)
	desc.add_theme_font_size_override("font_size", 24)
	right.add_child(desc)
	if Game.items.is_empty():
		var l := Label.new()
		l.text = "…لا أغراض بعد"
		list.add_child(l)
		desc.text = "ابحث في المكان: المفاتيح والأشرطة والوثائق مخبأة."
	for id in Game.items:
		var b := Button.new()
		b.text = Game.item_name(id)
		b.pressed.connect(_select.bind(id))
		list.add_child(b)
	if not Game.items.is_empty():
		_select(Game.items[0])
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): closed.emit())
	list.add_child(close)


func _select(id: String) -> void:
	for c in holder.get_children():
		c.queue_free()
	var m := ItemModel.build(id)
	m.scale = Vector3.ONE * 2.6
	holder.add_child(m)
	desc.text = str(Game.ITEMS.get(id, {}).get("desc", ""))


func _on_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		holder.rotate_y(event.relative.x * 0.01)
		holder.rotate_x(event.relative.y * 0.01)


func _process(delta: float) -> void:
	if not _drag:
		holder.rotate_y(delta * 0.7)
