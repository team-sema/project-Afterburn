class_name WeaponCoreCluster
extends Control

## Weapon hex core + optional trait satellites.
## Edit size/layout in weapon_core_cluster.tscn (Core + Templates/*).

signal core_selected(weapon_id: StringName, is_record: bool)
signal core_hovered(weapon_id: StringName, is_record: bool)
signal trait_selected(weapon_id: StringName, trait_id: StringName, is_record: bool)

var slot_size := Vector2(42, 42)
var core_size := Vector2(38, 38)
var trait_size := Vector2(14, 14)
var orbit_radius := 24.0
var show_outer_frame := false

var weapon_id: StringName = &""
var is_record := false
var is_focused := false

@onready var _core: HexModuleFrame = %Core
@onready var _trait_hex_template: HexModuleFrame = %TraitHexTemplate
@onready var _trait_caption_template: Label = %TraitCaptionTemplate

var _traits: Array[HexModuleFrame] = []
var _trait_labels: Array[Label] = []
var _bound_traits: Dictionary = {}
var _bound_labels: Dictionary = {}
var _bound_icons: Dictionary = {}
var _show_traits := false
var _signals_bound := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = false
	if custom_minimum_size != Vector2.ZERO:
		slot_size = custom_minimum_size
	if _trait_hex_template != null:
		_trait_hex_template.visible = false
		trait_size = _trait_hex_template.custom_minimum_size
	if _trait_caption_template != null:
		_trait_caption_template.visible = false
	_bind_core_signals()
	apply_slot_size(slot_size.x, show_outer_frame)
	_sync_core_rect()


func _get_minimum_size() -> Vector2:
	return slot_size


func apply_slot_size(side: float, p_show_outer_frame: bool = false) -> void:
	show_outer_frame = p_show_outer_frame
	side = clampf(side, 20.0, 96.0)
	slot_size = Vector2(side, side)
	if show_outer_frame:
		core_size = Vector2(side * 0.48, side * 0.48)
		trait_size = Vector2(maxi(12.0, side * 0.22), maxi(12.0, side * 0.22))
		orbit_radius = side * 0.36
	else:
		core_size = Vector2(side * 0.9, side * 0.9)
		if _trait_hex_template != null and _trait_hex_template.custom_minimum_size.x > 0.0:
			var template_side := _trait_hex_template.custom_minimum_size.x
			trait_size = Vector2(template_side, template_side)
		else:
			trait_size = Vector2(maxi(8.0, side * 0.28), maxi(8.0, side * 0.28))
		orbit_radius = side * 0.2
	custom_minimum_size = slot_size
	size = slot_size
	_sync_core_rect()
	if _show_traits and not _bound_traits.is_empty():
		_rebuild_traits()
	else:
		_layout_traits()
	queue_redraw()


func set_focused(focused: bool) -> void:
	is_focused = focused
	_style_core()
	queue_redraw()


func bind_weapon(
	p_weapon_id: StringName,
	icon: Texture2D,
	trait_ranks: Dictionary,
	trait_labels: Dictionary,
	trait_icons: Dictionary,
	p_is_record: bool,
	active: bool,
	show_traits: bool = false,
) -> void:
	weapon_id = p_weapon_id
	is_record = p_is_record
	_bound_traits = trait_ranks.duplicate()
	_bound_labels = trait_labels.duplicate()
	_bound_icons = trait_icons.duplicate()
	_show_traits = show_traits and p_weapon_id != &""
	_bind_core_signals()
	if _core == null:
		return
	custom_minimum_size = slot_size
	size = slot_size
	_core.visible = true
	_core.interactive = true

	if p_weapon_id == &"":
		_core.set_module_text("", "")
		_core.set_module_icon(null)
		_clear_traits()
		_style_core()
		_sync_core_rect()
		queue_redraw()
		return

	_core.set_module_text("", "")
	_core.set_module_icon(icon)
	_core.dimmed = (p_is_record or not active) and not is_focused
	_style_core()
	if _show_traits:
		_rebuild_traits()
	else:
		_clear_traits()
	_sync_core_rect()
	queue_redraw()


func _bind_core_signals() -> void:
	if _core == null:
		_core = get_node_or_null("%Core") as HexModuleFrame
	if _core == null:
		return
	if not _core.module_hovered.is_connected(_on_core_hover):
		_core.module_hovered.connect(_on_core_hover)
	if not _core.module_clicked.is_connected(_on_core_click):
		_core.module_clicked.connect(_on_core_click)
	_signals_bound = true


func _sync_core_rect() -> void:
	if _core == null:
		return
	_core.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	_core.apply_fixed_size(core_size.x)
	_core.position = (slot_size - core_size) * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_core_rect()
		_layout_traits()
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_ENTER:
		_emit_core_hover()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			core_selected.emit(weapon_id, is_record)
			accept_event()


func _rebuild_traits() -> void:
	_clear_traits()
	if _trait_hex_template == null:
		return
	var ids: Array[StringName] = []
	for key in _bound_traits.keys():
		if int(_bound_traits[key]) > 0:
			ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for index in ids.size():
		var trait_id := ids[index]
		var satellite := _trait_hex_template.duplicate() as HexModuleFrame
		satellite.visible = true
		satellite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
		satellite.apply_fixed_size(trait_size.x)
		satellite.interactive = true
		satellite.set_module_text("", "")
		var icon: Texture2D = _bound_icons.get(trait_id) as Texture2D
		satellite.set_module_icon(icon)
		satellite.dimmed = false
		satellite.border_color = Color(0.75, 0.92, 1.0, 0.95)
		satellite.fill_color = Color(0.08, 0.16, 0.28, 0.95)
		satellite.border_width = 1.25
		add_child(satellite)
		var captured := trait_id
		satellite.module_hovered.connect(func() -> void: trait_selected.emit(weapon_id, captured, is_record))
		satellite.module_clicked.connect(func() -> void: trait_selected.emit(weapon_id, captured, is_record))
		_traits.append(satellite)

		var caption: Label
		if _trait_caption_template != null:
			caption = _trait_caption_template.duplicate() as Label
		else:
			caption = Label.new()
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.visible = true
		caption.text = str(_bound_labels.get(trait_id, ""))
		caption.modulate = Color(0.82, 0.95, 1.0, 0.95)
		add_child(caption)
		_trait_labels.append(caption)
	_layout_traits()


func _layout_traits() -> void:
	var center := slot_size * 0.5
	var count := _traits.size()
	for index in count:
		var angle := -PI * 0.5 + TAU * float(index) / float(maxi(3, count))
		var dir := Vector2(cos(angle), sin(angle))
		var offset := dir * orbit_radius
		_traits[index].apply_fixed_size(trait_size.x)
		_traits[index].position = center + offset - trait_size * 0.5
		if index < _trait_labels.size():
			var label := _trait_labels[index]
			label.reset_size()
			var label_size := label.get_minimum_size()
			label.position = center + dir * (orbit_radius + trait_size.x * 0.55 + 2.0) - label_size * 0.5
			label.size = label_size


func _clear_traits() -> void:
	for satellite in _traits:
		if is_instance_valid(satellite):
			satellite.queue_free()
	_traits.clear()
	for label in _trait_labels:
		if is_instance_valid(label):
			label.queue_free()
	_trait_labels.clear()


func _style_core() -> void:
	if _core == null:
		return
	if weapon_id == &"":
		_core.dimmed = false
		_core.border_color = Color(0.3, 0.55, 0.75, 0.45)
		_core.fill_color = Color(0.02, 0.06, 0.12, 0.15)
		_core.border_width = 1.25
	elif is_focused:
		_core.dimmed = false
		_core.border_color = Color(0.45, 0.98, 1.0, 1.0)
		_core.fill_color = Color(0.05, 0.2, 0.36, 0.98)
		_core.border_width = 2.0
	else:
		_core.dimmed = true
		_core.border_color = Color(0.28, 0.55, 0.72, 0.55)
		_core.fill_color = Color(0.03, 0.08, 0.14, 0.55)
		_core.border_width = 1.25
	_core.queue_redraw()


func _draw() -> void:
	if not show_outer_frame:
		return
	var center := slot_size * 0.5
	var radius := slot_size.x * 0.46
	var points := PackedVector2Array()
	for index in 6:
		var angle := TAU * float(index) / 6.0 - PI / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.25, 0.85, 1.0, 0.5), 1.25, true)


func _on_core_hover() -> void:
	_emit_core_hover()


func _on_core_click() -> void:
	core_selected.emit(weapon_id, is_record)


func _emit_core_hover() -> void:
	if weapon_id == &"":
		return
	core_hovered.emit(weapon_id, is_record)
