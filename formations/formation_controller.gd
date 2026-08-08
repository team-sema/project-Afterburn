class_name FormationController
extends Node2D

signal member_added(enemy: Enemy, slot_index: int)
signal member_removed(slot_index: int)
signal formation_broken(released_members: Array[Enemy])
signal formation_empty

@export var formation_layout_scene: PackedScene
@export var formation_movement_sequence: MovementSequence
@export var formation_behavior: FormationBehavior = MaintainFormationBehavior.new()
@export var mirrored := false
@export var formation_break_condition := EncounterPreset.FormationBreakCondition.NEVER
@export_range(0.0, 60.0, 0.05) var formation_break_delay := 0.0
@export var individual_movement_sequence: MovementSequence

@onready var center_move_component: MoveComponent = $MoveComponent
@onready var center_movement_controller: MovementController = $MovementController
@onready var layout_container: Node2D = $LayoutContainer
@onready var enemy_container: Node2D = $EnemyContainer

var _layout: FormationLayout
var _bindings: Dictionary = {}
var _pending_member_spawns := 0
var _formation_started := false
var _formation_elapsed := 0.0
var _break_requested := false
var _breaking := false
var _cleanup_requested := false
var _formation_speed_multiplier := 1.0


func configure(preset: EncounterPreset) -> void:
	assert(preset != null, "FormationController requires an EncounterPreset.")
	formation_layout_scene = preset.formation_layout_scene
	formation_movement_sequence = preset.formation_movement_sequence
	formation_behavior = preset.formation_behavior
	mirrored = preset.mirrored
	formation_break_condition = preset.formation_break_condition
	formation_break_delay = preset.formation_break_delay
	individual_movement_sequence = preset.individual_movement_sequence


func _ready() -> void:
	process_priority = 10
	assert(formation_layout_scene != null, "FormationController requires a layout scene.")
	assert(
		formation_movement_sequence != null,
		"FormationController requires a formation MovementSequence.",
	)
	assert(formation_behavior != null, "FormationController requires a FormationBehavior.")
	assert(formation_behavior.validate(true), "FormationController FormationBehavior is invalid.")
	_instantiate_layout()
	center_movement_controller.sequence_finished.connect(_on_center_sequence_finished)


func _process(delta: float) -> void:
	_prune_invalid_members()
	if _formation_started:
		_formation_elapsed += delta
	_update_member_positions(delta)
	if _formation_started:
		if (
			formation_break_condition == EncounterPreset.FormationBreakCondition.ELAPSED_TIME
			and _formation_elapsed >= formation_break_delay
		):
			break_formation()
	if _bindings.is_empty() and _pending_member_spawns == 0 and not _breaking:
		_request_empty_cleanup()


func set_pending_member_count(count: int) -> void:
	_pending_member_spawns = maxi(0, count)
	if _pending_member_spawns == 0 and _break_requested:
		break_formation.call_deferred()


func prepare_slots_for_members(members: Array[EncounterMember]) -> void:
	assert(_layout != null, "FormationController layout is not ready.")
	var missing_indices: Array[int] = []
	for member in members:
		if member != null and _layout.get_slot(member.slot_index) == null:
			missing_indices.append(member.slot_index)
	if missing_indices.is_empty():
		return
	_expand_horizontal_row(members, missing_indices)


func add_member(
	enemy: Enemy,
	slot_index: int,
	individual_override: MovementSequence = null,
	initial_direction: Vector2 = Vector2.ZERO,
) -> void:
	assert(enemy != null, "FormationController cannot add a null Enemy.")
	assert(_layout != null, "FormationController layout is not ready.")
	var slot := _layout.get_slot(slot_index)
	assert(slot != null, "FormationController has no slot_index %d." % slot_index)
	assert(not _bindings.has(slot_index), "Formation slot %d is already occupied." % slot_index)

	# Suppress the scene's individual auto-start before _ready() runs. This also
	# makes the mode transition atomic from the enemy's point of view.
	enemy.enter_formation_mode(self, slot)
	enemy_container.add_child(enemy)
	_bindings[slot_index] = {
		"enemy": enemy,
		"slot": slot,
		"individual_sequence": individual_override,
		"initial_direction": initial_direction,
	}
	_pending_member_spawns = maxi(0, _pending_member_spawns - 1)
	if _bindings.size() == 1:
		_formation_speed_multiplier = enemy.move_component.velocity_multiplier
		center_move_component.velocity_multiplier = _formation_speed_multiplier
	enemy.tree_exiting.connect(
		_on_member_tree_exiting.bind(enemy.get_instance_id(), slot_index),
		CONNECT_ONE_SHOT,
	)
	_apply_member_position(enemy, slot, 0.0)
	member_added.emit(enemy, slot_index)
	if _pending_member_spawns == 0 and _break_requested:
		break_formation.call_deferred()


func notify_member_spawn_failed() -> void:
	_pending_member_spawns = maxi(0, _pending_member_spawns - 1)
	if _pending_member_spawns == 0 and _break_requested:
		break_formation.call_deferred()
		return
	if _bindings.is_empty() and _pending_member_spawns == 0:
		_request_empty_cleanup()


func start_formation(context: Dictionary = {}) -> void:
	if _break_requested or _breaking or _cleanup_requested:
		return
	var movement_context := context.duplicate(true)
	movement_context["formation_half_span"] = get_active_half_span()
	movement_context["lateral_sign"] = -1.0 if mirrored else 1.0
	if not movement_context.has("formation_direction"):
		var viewport_center_x := get_viewport_rect().get_center().x
		var inward_sign := 1.0 if global_position.x <= viewport_center_x else -1.0
		movement_context["formation_direction"] = Vector2(inward_sign, 0.0)
	center_move_component.velocity_multiplier = _formation_speed_multiplier
	center_movement_controller.set_sequence(
		formation_movement_sequence,
		movement_context,
	)
	_formation_elapsed = 0.0
	_formation_started = true
	center_movement_controller.start()


func start_formation_after_delay(delay: float, context: Dictionary = {}) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if is_instance_valid(self):
		start_formation(context)


func break_formation() -> void:
	if _breaking or _cleanup_requested:
		return
	if _pending_member_spawns > 0:
		_break_requested = true
		_formation_started = false
		center_movement_controller.stop()
		return
	_break_requested = false
	_breaking = true
	_formation_started = false
	center_movement_controller.stop()
	set_process(false)

	var release_parent := get_parent()
	assert(release_parent != null, "FormationController requires a parent for member release.")
	var locked_player_position := _get_locked_player_position()

	var released: Array[Enemy] = []
	var slot_indices: Array[int] = []
	for key in _bindings.keys():
		slot_indices.append(int(key))
	slot_indices.sort()
	for slot_index in slot_indices:
		var binding := _bindings[slot_index] as Dictionary
		var enemy := _release_member(
			slot_index,
			binding,
			release_parent,
			locked_player_position,
		)
		if enemy != null:
			released.append(enemy)

	formation_broken.emit(released)
	queue_free.call_deferred()


## Releases only the requested member. Remaining members keep their authored
## slots and continue following the formation movement and behavior.
func detach_member(enemy: Enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy) or _breaking or _cleanup_requested:
		return false
	var slot_index := _find_member_slot_index(enemy)
	if slot_index < 0:
		return false
	var release_parent := get_parent()
	assert(release_parent != null, "FormationController requires a parent for member detach.")
	var binding := _bindings.get(slot_index, {}) as Dictionary
	var released := _release_member(
		slot_index,
		binding,
		release_parent,
		_get_locked_player_position(),
	)
	if released == null:
		return false
	if _bindings.is_empty() and _pending_member_spawns == 0:
		_request_empty_cleanup.call_deferred()
	return true


func get_members() -> Array[Enemy]:
	var members: Array[Enemy] = []
	for binding_value in _bindings.values():
		var binding := binding_value as Dictionary
		var enemy := binding.get("enemy") as Enemy
		if enemy != null and is_instance_valid(enemy):
			members.append(enemy)
	return members


func get_layout() -> FormationLayout:
	return _layout


func get_active_half_span() -> float:
	var half_span := 0.0
	for binding_value in _bindings.values():
		var binding := binding_value as Dictionary
		var slot := binding.get("slot") as FormationSlot
		if slot != null:
			half_span = maxf(
				half_span,
				absf(_transform_slot_offset(_get_slot_layout_offset(slot), slot).x),
			)
	if _bindings.is_empty() and _layout != null:
		for slot in _layout.get_slots_sorted():
			half_span = maxf(
				half_span,
				absf(_transform_slot_offset(_get_slot_layout_offset(slot), slot).x),
			)
	return half_span


func get_used_local_bounds(slot_indices: Array[int]) -> Rect2:
	assert(_layout != null, "FormationController layout is not ready.")
	var has_point := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for slot_index in slot_indices:
		var slot := _layout.get_slot(slot_index)
		if slot == null:
			continue
		var point := _transform_slot_offset(_get_slot_layout_offset(slot), slot)
		if not has_point:
			minimum = point
			maximum = point
			has_point = true
		else:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum) if has_point else Rect2()


func _instantiate_layout() -> void:
	var instance := formation_layout_scene.instantiate() as FormationLayout
	assert(instance != null, "Formation layout root must use FormationLayout.")
	_layout = instance
	layout_container.add_child(_layout)
	assert(_layout.validate_slots(true), "FormationController received an invalid layout.")


func _update_member_positions(delta: float) -> void:
	for binding_value in _bindings.values():
		var binding := binding_value as Dictionary
		var enemy := binding.get("enemy") as Enemy
		var slot := binding.get("slot") as FormationSlot
		if enemy != null and is_instance_valid(enemy) and slot != null:
			_apply_member_position(enemy, slot, delta)


func _apply_member_position(enemy: Enemy, slot: FormationSlot, delta: float) -> void:
	var local_offset := _transform_slot_offset(_get_slot_layout_offset(slot), slot, delta)
	var target_position := global_transform * local_offset
	var rotation_sign := -1.0 if mirrored else 1.0
	var target_rotation := global_rotation + deg_to_rad(slot.rotation_offset * rotation_sign)
	enemy.apply_formation_target(
		target_position,
		delta,
		target_rotation,
		center_move_component.velocity,
	)


func _transform_slot_offset(
	offset: Vector2,
	slot: FormationSlot = null,
	delta := 0.0,
) -> Vector2:
	if formation_behavior != null:
		offset = formation_behavior.transform_slot(
			offset,
			slot,
			{
				"elapsed_time": _formation_elapsed,
				"delta": delta,
				"controller": self,
			},
		)
	if mirrored:
		offset.x = -offset.x
	return offset


func _get_slot_layout_offset(slot: FormationSlot) -> Vector2:
	assert(slot != null, "FormationController requires a FormationSlot.")
	if _layout == null or not slot.is_inside_tree():
		return slot.position
	return _layout.to_local(slot.global_position)


func _set_slot_layout_offset(slot: FormationSlot, offset: Vector2) -> void:
	assert(slot != null, "FormationController requires a FormationSlot.")
	if _layout == null or not slot.is_inside_tree():
		slot.position = offset
		return
	slot.global_position = _layout.to_global(offset)


func _build_individual_context(
	enemy: Enemy,
	slot: FormationSlot,
	locked_player_position: Vector2,
	configured_initial_direction: Vector2,
) -> Dictionary:
	var offset := _transform_slot_offset(_get_slot_layout_offset(slot), slot)
	var scatter_direction := configured_initial_direction
	if not scatter_direction.is_zero_approx():
		if mirrored:
			scatter_direction.x *= -1.0
		scatter_direction = scatter_direction.normalized()
	else:
		# Outward burst from the authored slot so left/right wings do not cross.
		scatter_direction = _outward_scatter_direction(offset)
	var player_direction := enemy.global_position.direction_to(locked_player_position)
	if player_direction.is_zero_approx():
		player_direction = Vector2.DOWN
	return {
		"formation_slot_offset": offset,
		"slot_index": slot.slot_index,
		"slot_id": slot.slot_id,
		"mirrored": mirrored,
		"initial_direction": scatter_direction,
		"player_direction": player_direction,
		"locked_player_position": locked_player_position,
	}


## Left wings fan left-down, right wings fan right-down, center/front stay near down.
func _outward_scatter_direction(slot_offset: Vector2) -> Vector2:
	const SIDE_EPSILON := 0.5
	const MIN_SIDE_ANGLE := PI * 0.18
	const MAX_SIDE_ANGLE := PI * 0.5
	const CENTER_SPREAD := PI * 0.12
	var angle := 0.0
	if slot_offset.x < -SIDE_EPSILON:
		angle = randf_range(MIN_SIDE_ANGLE, MAX_SIDE_ANGLE)
	elif slot_offset.x > SIDE_EPSILON:
		angle = randf_range(-MAX_SIDE_ANGLE, -MIN_SIDE_ANGLE)
	else:
		angle = randf_range(-CENTER_SPREAD, CENTER_SPREAD)
	return Vector2.DOWN.rotated(angle)


func _find_member_slot_index(enemy: Enemy) -> int:
	for key in _bindings.keys():
		var binding := _bindings[key] as Dictionary
		if binding.get("enemy") as Enemy == enemy:
			return int(key)
	return -1


func _release_member(
	slot_index: int,
	binding: Dictionary,
	release_parent: Node,
	locked_player_position: Vector2,
) -> Enemy:
	var enemy := binding.get("enemy") as Enemy
	var slot := binding.get("slot") as FormationSlot
	_bindings.erase(slot_index)
	member_removed.emit(slot_index)
	if enemy == null or not is_instance_valid(enemy) or slot == null:
		return null
	var preserved_position := enemy.global_position
	var context := _build_individual_context(
		enemy,
		slot,
		locked_player_position,
		binding.get("initial_direction", Vector2.ZERO) as Vector2,
	)
	var sequence := binding.get("individual_sequence") as MovementSequence
	if sequence == null:
		sequence = individual_movement_sequence
	enemy.reparent(release_parent, true)
	enemy.global_position = preserved_position
	enemy.exit_formation_mode(sequence, context)
	return enemy


func _get_locked_player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		return player.global_position
	return global_position + Vector2.DOWN * 200.0


func _expand_horizontal_row(
	members: Array[EncounterMember],
	missing_indices: Array[int],
) -> void:
	var authored := _layout.get_slots_sorted()
	assert(authored.size() >= 2, "Supplemental slots require at least two authored slots.")
	var first_offset := _get_slot_layout_offset(authored[0])
	var row_y := first_offset.y
	for slot in authored:
		var slot_offset := _get_slot_layout_offset(slot)
		assert(
			is_equal_approx(slot_offset.y, row_y),
			"Supplemental slots are supported only for an equal-height horizontal row.",
		)
	var x_positions: Array[float] = []
	for slot in authored:
		x_positions.append(_get_slot_layout_offset(slot).x)
	x_positions.sort()
	var spacing := x_positions[1] - x_positions[0]
	assert(not is_zero_approx(spacing), "Horizontal formation slots require non-zero spacing.")
	for index in range(2, x_positions.size()):
		assert(
			is_equal_approx(x_positions[index] - x_positions[index - 1], spacing),
			"Supplemental slots require evenly spaced authored slots.",
		)
	var active_indices: Array[int] = []
	for member in members:
		if member != null:
			active_indices.append(member.slot_index)
	active_indices.sort()
	for index in active_indices.size():
		assert(active_indices[index] == index, "Expanded row member slots must be contiguous.")
	var center_x := (x_positions[0] + x_positions[-1]) * 0.5
	var count := active_indices.size()
	for index in count:
		var slot := _layout.get_slot(index)
		if slot == null:
			slot = FormationSlot.new()
			slot.name = "RuntimeSlot%d" % index
			slot.slot_index = index
			slot.slot_id = StringName("runtime_%d" % index)
			slot.show_editor_label = false
			_layout.add_child(slot)
		var centered_index := float(index) - float(count - 1) * 0.5
		_set_slot_layout_offset(
			slot,
			Vector2(center_x + centered_index * spacing, row_y),
		)
	for missing_index in missing_indices:
		assert(_layout.get_slot(missing_index) != null, "Failed to create supplemental slot.")


func _on_center_sequence_finished() -> void:
	if formation_break_condition == EncounterPreset.FormationBreakCondition.SEQUENCE_FINISHED:
		# MovementController emits from its own process callback. Let this
		# controller apply the center's final position to members before release.
		break_formation.call_deferred()


func _on_member_tree_exiting(instance_id: int, slot_index: int) -> void:
	if _breaking:
		return
	if not _bindings.has(slot_index):
		return
	var binding := _bindings.get(slot_index, {}) as Dictionary
	var enemy := binding.get("enemy") as Enemy
	if enemy != null and enemy.get_instance_id() != instance_id:
		return
	_bindings.erase(slot_index)
	member_removed.emit(slot_index)
	if _bindings.is_empty() and _pending_member_spawns == 0:
		_request_empty_cleanup.call_deferred()


func _prune_invalid_members() -> void:
	var missing: Array[int] = []
	for key in _bindings.keys():
		var binding := _bindings[key] as Dictionary
		var enemy := binding.get("enemy") as Enemy
		if enemy == null or not is_instance_valid(enemy):
			missing.append(int(key))
	for slot_index in missing:
		_bindings.erase(slot_index)
		member_removed.emit(slot_index)


func _request_empty_cleanup() -> void:
	if _cleanup_requested or _breaking:
		return
	if _break_requested:
		if _pending_member_spawns == 0:
			break_formation.call_deferred()
		return
	if not _bindings.is_empty() or _pending_member_spawns > 0:
		return
	_cleanup_requested = true
	if is_inside_tree() and center_movement_controller != null:
		center_movement_controller.stop()
	formation_empty.emit()
	queue_free()
