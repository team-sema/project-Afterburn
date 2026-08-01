class_name ShipFacilityModule
extends Panel

signal facility_clicked(facility_id: StringName)
signal facility_hovered(facility_id: StringName)
signal facility_focused(facility_id: StringName)

const BORDER_IDLE := Color(0.16, 0.45, 0.68, 0.85)
const BORDER_SELECTED := Color(0.62, 0.97, 1.0, 1.0)
const FILL_IDLE := Color(0.02, 0.07, 0.14, 0.92)
const FILL_SELECTED := Color(0.05, 0.16, 0.28, 0.95)
const TEXT_ACTIVE := Color(0.82, 0.94, 1.0, 1.0)
const ICON_IDLE := Color(0.45, 0.82, 1.0, 0.95)
const ICON_SELECTED := Color(0.85, 0.99, 1.0, 1.0)
const SLOT_SIZE := Vector2(18.0, 18.0)
const SLOT_GAP := 2.0
const SLOT_BOTTOM_MARGIN := 1.0
const SLOT_BORDER_EMPTY := Color(0.25, 0.62, 0.82, 0.95)
const SLOT_BORDER_FILLED := Color(0.72, 0.96, 1.0, 1.0)
const SLOT_FILL_EMPTY := Color(0.01, 0.035, 0.07, 0.98)
const SLOT_FILL_FILLED := Color(0.08, 0.32, 0.45, 0.98)
const SLOT_PREVIEW := Color(0.38, 0.94, 1.0, 1.0)

@export var facility_id: StringName
@export var hardpoint := Vector2(0.5, 0.5)

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $NameLabel

var is_selected := false:
	set(value):
		is_selected = value
		_apply_style()

var _is_hovered := false
var _style: StyleBoxFlat
var _slots: Array = []
var _capacity := 0
var _expansion_preview := false
var _preview_alpha := 0.35
var _preview_tween: Tween


func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.corner_radius_top_left = 3
	_style.corner_radius_top_right = 3
	_style.corner_radius_bottom_right = 3
	_style.corner_radius_bottom_left = 3
	_style.border_width_left = 1
	_style.border_width_top = 1
	_style.border_width_right = 1
	_style.border_width_bottom = 1
	add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_apply_style)
	resized.connect(queue_redraw)
	_apply_style()


func update_state(
	display_name: String,
	slots: Array,
	icon: Texture2D = null,
) -> void:
	if not is_node_ready():
		return
	icon_rect.texture = icon
	name_label.text = display_name
	_slots = slots.duplicate()
	_capacity = _slots.size()
	_apply_style()
	queue_redraw()


func set_selection_enabled(enabled: bool) -> void:
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	if not enabled:
		set_expansion_preview(false)
	_apply_style()


func set_expansion_preview(enabled: bool) -> void:
	if _expansion_preview == enabled:
		return
	_expansion_preview = enabled
	if _preview_tween != null:
		_preview_tween.kill()
		_preview_tween = null
	_preview_alpha = 0.35
	if enabled:
		_preview_tween = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_preview_tween.tween_method(_set_preview_alpha, 0.35, 1.0, 0.45)
		_preview_tween.tween_method(_set_preview_alpha, 1.0, 0.35, 0.45)
	queue_redraw()


func has_expansion_preview() -> bool:
	return _expansion_preview


func get_preview_alpha() -> float:
	return _preview_alpha


func get_visual_slot_count() -> int:
	return _capacity + (1 if _expansion_preview else 0)


func get_slot_rect(index: int) -> Rect2:
	var count := get_visual_slot_count()
	if index < 0 or index >= count:
		return Rect2()
	var total_width := SLOT_SIZE.x * count + SLOT_GAP * maxi(0, count - 1)
	var start_x := (size.x - total_width) * 0.5
	return Rect2(
		Vector2(start_x + index * (SLOT_SIZE.x + SLOT_GAP), size.y - SLOT_SIZE.y - SLOT_BOTTOM_MARGIN),
		SLOT_SIZE,
	)


func get_slot_icon(index: int) -> Texture2D:
	if index < 0 or index >= _slots.size():
		return null
	var state := _slots[index] as PlayerAugmentModuleState
	if state == null:
		return null
	return state.augment.icon


func show_unknown_facility() -> void:
	if not is_node_ready():
		return
	icon_rect.texture = null
	name_label.text = String(facility_id)
	_slots.clear()
	_capacity = 0
	_apply_style()
	queue_redraw()


func get_connector_point(toward_left: bool) -> Vector2:
	var edge_x := position.x if toward_left else position.x + size.x
	return Vector2(edge_x, position.y + size.y * 0.5)


func _apply_style() -> void:
	if not is_node_ready() or _style == null:
		return
	var border := BORDER_SELECTED if is_selected or has_focus() else BORDER_IDLE
	if _is_hovered:
		border = border.lerp(Color.WHITE, 0.25)
	_style.border_color = border
	_style.bg_color = FILL_SELECTED if is_selected or has_focus() else FILL_IDLE
	_style.shadow_size = 4 if is_selected or has_focus() else 0
	_style.shadow_color = Color(0.2, 0.8, 1.0, 0.32)
	icon_rect.self_modulate = ICON_SELECTED if is_selected else ICON_IDLE
	name_label.modulate = TEXT_ACTIVE
	queue_redraw()


func _draw() -> void:
	for index in get_visual_slot_count():
		var is_preview := index >= _capacity
		var state: PlayerAugmentModuleState = null
		if not is_preview and index < _slots.size():
			state = _slots[index] as PlayerAugmentModuleState
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_right = 5
		style.corner_radius_bottom_left = 5
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		if is_preview:
			style.border_color = Color(SLOT_PREVIEW, _preview_alpha)
			style.bg_color = Color(SLOT_PREVIEW, _preview_alpha * 0.22)
		elif state != null:
			style.border_color = SLOT_BORDER_FILLED
			style.bg_color = SLOT_FILL_FILLED
		else:
			style.border_color = SLOT_BORDER_EMPTY
			style.bg_color = SLOT_FILL_EMPTY
		var slot_rect := get_slot_rect(index)
		draw_style_box(style, slot_rect)
		if state == null:
			continue
		var augment_icon := state.augment.icon
		if augment_icon != null:
			draw_texture_rect(augment_icon, slot_rect.grow(-3.0), false, ICON_SELECTED)
		else:
			draw_circle(slot_rect.get_center(), 3.0, SLOT_BORDER_FILLED)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and focus_mode == Control.FOCUS_ALL:
		facility_clicked.emit(facility_id)
		accept_event()
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	facility_clicked.emit(facility_id)
	accept_event()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_style()
	facility_hovered.emit(facility_id)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_style()


func _on_focus_entered() -> void:
	_apply_style()
	facility_focused.emit(facility_id)


func _set_preview_alpha(alpha: float) -> void:
	_preview_alpha = alpha
	queue_redraw()
