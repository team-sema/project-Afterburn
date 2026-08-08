@tool
class_name FormationLayout
extends Node2D

## Editor-authored geometry for a formation.
##
## Child FormationSlot transforms are the only layout data. Runtime systems can
## query the sorted slots without depending on SceneTree child order.

@export_group("Editor Preview")
@export var show_center_marker := true:
	set(value):
		show_center_marker = value
		queue_redraw()

@export var show_center_label := true:
	set(value):
		show_center_label = value
		queue_redraw()

@export var show_slot_labels := true:
	set(value):
		show_slot_labels = value
		queue_redraw()
		_redraw_slots()

@export var show_connection_lines := true:
	set(value):
		show_connection_lines = value
		queue_redraw()

@export var preview_color := Color(0.20, 0.88, 1.0, 0.70):
	set(value):
		preview_color = value
		queue_redraw()

@export var invalid_preview_color := Color(1.0, 0.24, 0.22, 0.95):
	set(value):
		invalid_preview_color = value
		queue_redraw()

var _last_preview_signature := ""


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	_last_preview_signature = _build_preview_signature()
	queue_redraw()
	update_configuration_warnings()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var signature := _build_preview_signature()
	if signature == _last_preview_signature:
		return
	_last_preview_signature = signature
	queue_redraw()
	update_configuration_warnings()
	_redraw_slots()


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED and Engine.is_editor_hint():
		queue_redraw()
		update_configuration_warnings()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	if show_center_marker:
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 20, preview_color, 2.0, true)
		draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), preview_color, 1.0, true)
		draw_line(Vector2(0.0, -10.0), Vector2(0.0, 10.0), preview_color, 1.0, true)
	if show_center_label:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(8.0, 18.0),
			"Formation center",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			ThemeDB.fallback_font_size,
			preview_color,
		)

	var counts := _get_index_counts()
	var id_counts := _get_id_counts()
	for slot in get_slots_sorted():
		var slot_position := to_local(slot.global_position)
		var invalid := (
			slot.slot_index < 0
			or int(counts.get(slot.slot_index, 0)) > 1
			or slot.slot_id.is_empty()
			or int(id_counts.get(slot.slot_id, 0)) > 1
		)
		var color := invalid_preview_color if invalid else preview_color
		if show_connection_lines:
			draw_dashed_line(Vector2.ZERO, slot_position, color, 1.0, 5.0, true)
		if show_slot_labels:
			draw_string(
				ThemeDB.fallback_font,
				slot_position + Vector2(slot.preview_radius + 6.0, -slot.preview_radius - 1.0),
				slot.get_editor_label(),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				ThemeDB.fallback_font_size,
				color,
			)


func _get_configuration_warnings() -> PackedStringArray:
	return get_slot_validation_errors()


## Public counterpart to the editor virtual, useful to runtime scene validation.
func get_configuration_warnings() -> PackedStringArray:
	return _get_configuration_warnings()


func get_slots_sorted() -> Array[FormationSlot]:
	var slots: Array[FormationSlot] = []
	_collect_slots(self, slots)
	slots.sort_custom(func(left: FormationSlot, right: FormationSlot) -> bool:
		if left.slot_index != right.slot_index:
			return left.slot_index < right.slot_index
		var left_id := String(left.slot_id)
		var right_id := String(right.slot_id)
		if left_id != right_id:
			return left_id < right_id
		return String(left.get_path()) < String(right.get_path())
	)
	return slots


func get_slot_by_index(index: int) -> FormationSlot:
	for slot in get_slots_sorted():
		if slot.slot_index == index:
			return slot
	return null


## Stable shorthand used by formation runtime integration.
func get_slot(index: int) -> FormationSlot:
	return get_slot_by_index(index)


func get_slot_by_id(id: StringName) -> FormationSlot:
	for slot in get_slots_sorted():
		if slot.slot_id == id:
			return slot
	return null


func get_slot_count() -> int:
	return get_slots_sorted().size()


func get_slot_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var slots := get_slots_sorted()
	if slots.is_empty():
		errors.append("FormationLayout requires at least one FormationSlot child.")
		return errors

	var first_slot_for_index: Dictionary = {}
	var first_slot_for_id: Dictionary = {}
	for slot in slots:
		if slot.slot_index < 0:
			errors.append(
				"Slot '%s' has invalid negative slot_index %d."
				% [slot.name, slot.slot_index]
			)
		if first_slot_for_index.has(slot.slot_index):
			var first_slot := first_slot_for_index[slot.slot_index] as FormationSlot
			errors.append(
				"Slots '%s' and '%s' duplicate slot_index %d."
				% [first_slot.name, slot.name, slot.slot_index]
			)
		else:
			first_slot_for_index[slot.slot_index] = slot
		if slot.slot_id.is_empty():
			errors.append("Slot '%s' has an empty slot_id." % slot.name)
		elif first_slot_for_id.has(slot.slot_id):
			var first_id_slot := first_slot_for_id[slot.slot_id] as FormationSlot
			errors.append(
				"Slots '%s' and '%s' duplicate slot_id '%s'."
				% [first_id_slot.name, slot.name, slot.slot_id]
			)
		else:
			first_slot_for_id[slot.slot_id] = slot
		if slot.spawn_delay < 0.0:
			errors.append("Slot '%s' has a negative spawn_delay." % slot.name)
	return errors


func validate_slots(report_errors := false) -> bool:
	var errors := get_slot_validation_errors()
	if report_errors:
		for error in errors:
			push_error("FormationLayout '%s': %s" % [name, error])
	return errors.is_empty()


func draws_slot_labels() -> bool:
	return show_slot_labels


func is_slot_index_duplicate(index: int) -> bool:
	return int(_get_index_counts().get(index, 0)) > 1


func is_slot_id_duplicate(id: StringName) -> bool:
	return not id.is_empty() and int(_get_id_counts().get(id, 0)) > 1


func _collect_slots(parent_node: Node, slots: Array[FormationSlot]) -> void:
	for child in parent_node.get_children():
		if child is FormationSlot:
			slots.append(child as FormationSlot)
		else:
			_collect_slots(child, slots)


func _get_index_counts() -> Dictionary:
	var counts: Dictionary = {}
	for slot in get_slots_sorted():
		counts[slot.slot_index] = int(counts.get(slot.slot_index, 0)) + 1
	return counts


func _get_id_counts() -> Dictionary:
	var counts: Dictionary = {}
	for slot in get_slots_sorted():
		if not slot.slot_id.is_empty():
			counts[slot.slot_id] = int(counts.get(slot.slot_id, 0)) + 1
	return counts


func _redraw_slots() -> void:
	for slot in get_slots_sorted():
		slot.queue_redraw()
		slot.update_configuration_warnings()


func _build_preview_signature() -> String:
	var parts := PackedStringArray()
	for slot in get_slots_sorted():
		parts.append(
			"%d|%s|%.4f|%.4f|%.3f"
			% [
				slot.slot_index,
				String(slot.slot_id),
				slot.position.x,
				slot.position.y,
				slot.rotation_offset,
			]
		)
	return ";".join(parts)
