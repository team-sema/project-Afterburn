@tool
class_name FormationSlot
extends Marker2D

## An editor-authored member position inside a FormationLayout.
##
## The Marker2D transform is the slot offset. Preview drawing is editor-only;
## the node contains no enemy, movement, or encounter state.

@export var slot_index: int = 0:
	set(value):
		slot_index = value
		_refresh_editor_preview()

@export var slot_id: StringName = &"":
	set(value):
		slot_id = value
		_refresh_editor_preview()

@export var spawn_delay: float = 0.0:
	set(value):
		spawn_delay = value
		_refresh_editor_preview()

## Degrees clockwise from the slot's default facing direction (up).
@export var rotation_offset: float = 0.0:
	set(value):
		rotation_offset = value
		_refresh_editor_preview()

@export_group("Editor Preview")
@export var show_editor_label := true:
	set(value):
		show_editor_label = value
		queue_redraw()

@export var preview_color := Color(0.20, 0.88, 1.0, 0.95):
	set(value):
		preview_color = value
		queue_redraw()

@export_range(2.0, 24.0, 1.0) var preview_radius := 7.0:
	set(value):
		preview_radius = value
		queue_redraw()


func _enter_tree() -> void:
	set_notify_transform(true)


func _ready() -> void:
	queue_redraw()
	update_configuration_warnings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_notify_layout_changed()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var color := preview_color
	if (
		slot_index < 0
		or slot_id.is_empty()
		or _has_duplicate_index_in_parent()
		or _has_duplicate_id_in_parent()
	):
		color = Color(1.0, 0.24, 0.22, 1.0)

	draw_arc(Vector2.ZERO, preview_radius, 0.0, TAU, 24, color, 2.0, true)
	draw_line(
		Vector2(-preview_radius - 3.0, 0.0),
		Vector2(preview_radius + 3.0, 0.0),
		color,
		1.0,
		true,
	)
	draw_line(
		Vector2(0.0, -preview_radius - 3.0),
		Vector2(0.0, preview_radius + 3.0),
		color,
		1.0,
		true,
	)

	var facing := Vector2.UP.rotated(deg_to_rad(rotation_offset))
	draw_line(Vector2.ZERO, facing * (preview_radius + 7.0), color, 2.0, true)

	if show_editor_label and not _parent_draws_slot_labels():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(preview_radius + 6.0, -preview_radius - 1.0),
			get_editor_label(),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			ThemeDB.fallback_font_size,
			color,
		)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if slot_index < 0:
		warnings.append("FormationSlot slot_index must be zero or greater.")
	if slot_id.is_empty():
		warnings.append("FormationSlot slot_id should be explicit and non-empty.")
	if spawn_delay < 0.0:
		warnings.append("FormationSlot spawn_delay cannot be negative.")
	if _has_duplicate_index_in_parent():
		warnings.append("FormationSlot slot_index %d is duplicated in its layout." % slot_index)
	if _has_duplicate_id_in_parent():
		warnings.append("FormationSlot slot_id '%s' is duplicated in its layout." % slot_id)
	return warnings


## Public counterpart to the editor virtual, useful to validators and tests at runtime.
func get_configuration_warnings() -> PackedStringArray:
	return _get_configuration_warnings()


func get_editor_label() -> String:
	var id_text := String(slot_id)
	if id_text.is_empty():
		id_text = String(name)
	return "#%d  %s" % [slot_index, id_text]


func _parent_draws_slot_labels() -> bool:
	var parent_node := _get_layout_ancestor()
	return (
		parent_node != null
		and parent_node.has_method("draws_slot_labels")
		and bool(parent_node.call("draws_slot_labels"))
	)


func _has_duplicate_index_in_parent() -> bool:
	var parent_node := _get_layout_ancestor()
	return (
		parent_node != null
		and parent_node.has_method("is_slot_index_duplicate")
		and bool(parent_node.call("is_slot_index_duplicate", slot_index))
	)


func _has_duplicate_id_in_parent() -> bool:
	var parent_node := _get_layout_ancestor()
	return (
		parent_node != null
		and parent_node.has_method("is_slot_id_duplicate")
		and bool(parent_node.call("is_slot_id_duplicate", slot_id))
	)


func _refresh_editor_preview() -> void:
	queue_redraw()
	update_configuration_warnings()
	_notify_layout_changed()


func _notify_layout_changed() -> void:
	if not is_inside_tree():
		return
	var parent_node := _get_layout_ancestor()
	if parent_node == null:
		return
	parent_node.queue_redraw()
	parent_node.update_configuration_warnings()


func _get_layout_ancestor() -> FormationLayout:
	var current := get_parent()
	while current != null:
		if current is FormationLayout:
			return current as FormationLayout
		current = current.get_parent()
	return null
