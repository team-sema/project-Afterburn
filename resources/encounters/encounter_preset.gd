class_name EncounterPreset
extends Resource

enum SpawnAnchor {
	TOP_RANDOM = 0,
	TOP_CENTER = 1,
	TOP_LEFT = 2,
	TOP_RIGHT = 3,
	CENTER = 4,
}

enum FormationBreakCondition {
	NEVER = 0,
	SEQUENCE_FINISHED = 1,
	ELAPSED_TIME = 2,
}

@export var encounter_id: StringName
@export var formation_layout_scene: PackedScene
@export var formation_movement_sequence: MovementSequence
@export var formation_behavior: FormationBehavior = MaintainFormationBehavior.new()
@export var members: Array[EncounterMember] = []
## Optional members activated by spawn-count augments, in array order.
@export var additional_members: Array[EncounterMember] = []
@export var spawn_anchor := SpawnAnchor.TOP_CENTER
@export var spawn_offset := Vector2(0.0, -16.0)
@export_range(0.0, 256.0, 1.0) var spawn_edge_margin := 8.0
## Allow the authored anchor to use MovementArea horizontally. Vertical TOP
## anchors are already placed above VisibleRect by the active formation depth.
@export var spawn_in_movement_area := false
@export_range(0.0, 60.0, 0.05) var start_delay := 0.0
@export var mirrored := false
@export var formation_break_condition := FormationBreakCondition.NEVER
@export_range(0.0, 60.0, 0.05) var formation_break_delay := 0.0
@export var individual_movement_sequence: MovementSequence


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if encounter_id.is_empty():
		errors.append("EncounterPreset requires a non-empty encounter_id.")
	if formation_layout_scene == null:
		errors.append("EncounterPreset requires a FormationLayout scene.")
	if formation_movement_sequence == null:
		errors.append("EncounterPreset requires a formation MovementSequence.")
	else:
		_append_sequence_errors(errors, formation_movement_sequence, "Formation")
	if formation_behavior == null:
		errors.append("EncounterPreset requires a FormationBehavior.")
	else:
		for behavior_error in formation_behavior.get_validation_errors():
			errors.append("FormationBehavior: %s" % behavior_error)
	if members.is_empty():
		errors.append("EncounterPreset requires at least one member.")
	if formation_break_condition == FormationBreakCondition.ELAPSED_TIME:
		if formation_break_delay <= 0.0:
			errors.append("ELAPSED_TIME break requires formation_break_delay > 0.")

	var layout: FormationLayout
	var layout_instance: Node
	if formation_layout_scene != null:
		layout_instance = formation_layout_scene.instantiate()
		layout = layout_instance as FormationLayout
		if layout == null:
			errors.append("formation_layout_scene root must be FormationLayout.")
		else:
			errors.append_array(layout.get_slot_validation_errors())

	var used_indices: Dictionary = {}
	var all_members: Array[EncounterMember] = []
	all_members.append_array(members)
	all_members.append_array(additional_members)
	for member_index in all_members.size():
		var member := all_members[member_index]
		if member == null:
			errors.append("EncounterPreset member %d is null." % member_index)
			continue
		for member_error in member.get_validation_errors():
			errors.append("Member %d: %s" % [member_index, member_error])
		if used_indices.has(member.slot_index):
			errors.append("Members duplicate slot_index %d." % member.slot_index)
		else:
			used_indices[member.slot_index] = true
		var is_additional := member_index >= members.size()
		if layout != null and layout.get_slot(member.slot_index) == null and not is_additional:
			errors.append("Member %d references missing slot_index %d." % [
				member_index,
				member.slot_index,
			])
		if (
			formation_break_condition != FormationBreakCondition.NEVER
			and member.individual_movement_override == null
			and individual_movement_sequence == null
		):
			errors.append(
				"Member %d has no individual MovementSequence for formation break."
				% member_index
			)
		if member.individual_movement_override != null:
			_append_sequence_errors(
				errors,
				member.individual_movement_override,
				"Member %d individual" % member_index,
			)

	if layout != null:
		for additional_index in additional_members.size():
			var member := additional_members[additional_index]
			if member != null and member.slot_index < layout.get_slot_count():
				errors.append(
					"Additional member %d must use a supplemental slot index."
					% additional_index
				)
		if not additional_members.is_empty():
			_validate_expandable_horizontal_row(errors, layout, all_members)
	if layout_instance != null:
		layout_instance.free()
	if individual_movement_sequence != null:
		_append_sequence_errors(errors, individual_movement_sequence, "Default individual")
	return errors


func validate(report_errors := false) -> bool:
	var errors := get_validation_errors()
	if report_errors:
		for error in errors:
			push_error("EncounterPreset '%s': %s" % [encounter_id, error])
	return errors.is_empty()


func get_used_slot_indices() -> Array[int]:
	var indices: Array[int] = []
	for member in members:
		if member != null:
			indices.append(member.slot_index)
	indices.sort()
	return indices


func get_active_members(additional_count: int = 0) -> Array[EncounterMember]:
	assert(
		additional_count >= 0 and additional_count <= additional_members.size(),
		"EncounterPreset '%s' supports %d additional members, requested %d."
		% [encounter_id, additional_members.size(), additional_count],
	)
	var active: Array[EncounterMember] = []
	active.append_array(members)
	for index in mini(additional_count, additional_members.size()):
		active.append(additional_members[index])
	return active


func _append_sequence_errors(
	errors: PackedStringArray,
	sequence: MovementSequence,
	label: String,
) -> void:
	if sequence.steps.is_empty():
		errors.append("%s MovementSequence has no steps." % label)
		return
	for step_index in sequence.steps.size():
		var step := sequence.steps[step_index]
		if step == null:
			errors.append("%s MovementSequence step %d is null." % [label, step_index])
		elif step.get_script() == MovementStep:
			errors.append(
				"%s MovementSequence step %d uses the abstract MovementStep."
				% [label, step_index]
			)


func _validate_expandable_horizontal_row(
	errors: PackedStringArray,
	layout: FormationLayout,
	all_members: Array[EncounterMember],
) -> void:
	var authored := layout.get_slots_sorted()
	if authored.size() < 2:
		errors.append("Additional members require at least two authored slots.")
		return
	var row_y := authored[0].position.y
	var x_positions: Array[float] = []
	for slot in authored:
		if not is_equal_approx(slot.position.y, row_y):
			errors.append("Additional members require an equal-height horizontal layout.")
			return
		x_positions.append(slot.position.x)
	x_positions.sort()
	var spacing := x_positions[1] - x_positions[0]
	if is_zero_approx(spacing):
		errors.append("Additional members require non-zero horizontal spacing.")
		return
	for index in range(2, x_positions.size()):
		if not is_equal_approx(x_positions[index] - x_positions[index - 1], spacing):
			errors.append("Additional members require evenly spaced horizontal slots.")
			return
	var indices: Array[int] = []
	for member in all_members:
		if member != null:
			indices.append(member.slot_index)
	indices.sort()
	for index in indices.size():
		if indices[index] != index:
			errors.append("Expanded horizontal member slots must be contiguous from index 0.")
			return
