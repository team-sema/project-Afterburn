class_name EnemySpawner
extends Node

const DEFAULT_MOVEMENT_SPACE: MovementSpaceConfig = preload(
	"res://resources/enemy_movement/default_movement_space.tres"
)

signal enemy_spawned(enemy: Enemy)
signal encounter_spawned(controller: FormationController)

const FORMATION_CONTROLLER_SCENE: PackedScene = preload(
	"res://formations/formation_controller.tscn"
)

@export var augment_registry: EnemyAugmentRegistry
@export var spawn_parent: Node
@export var movement_space_config: MovementSpaceConfig = DEFAULT_MOVEMENT_SPACE


func spawn_encounter(
	preset_resource: Resource,
	additional_count: int = -1,
	configure_before_add: Callable = Callable(),
	startup_context: Dictionary = {},
) -> FormationController:
	assert(augment_registry != null, "EnemySpawner requires an EnemyAugmentRegistry.")
	assert(
		movement_space_config != null and movement_space_config.validate(),
		"EnemySpawner requires a valid MovementSpaceConfig.",
	)
	assert(preset_resource is EncounterPreset, "EnemySpawner requires an EncounterPreset.")
	assert(additional_count >= -1, "EnemySpawner additional_count cannot be less than -1.")
	var preset := preset_resource as EncounterPreset
	assert(preset.validate(true), "EnemySpawner received an invalid EncounterPreset.")
	var effective_additional_count := additional_count
	if effective_additional_count < 0:
		effective_additional_count = augment_registry.get_additional_spawn_count(
			preset.encounter_id
		)
	var active_members := preset.get_active_members(effective_additional_count)
	var controller := FORMATION_CONTROLLER_SCENE.instantiate() as FormationController
	assert(controller != null, "FormationController scene root is invalid.")
	controller.configure(preset)
	var target_parent := _resolve_spawn_parent()
	target_parent.add_child(controller)
	controller.set_pending_member_count(active_members.size())
	controller.prepare_slots_for_members(active_members)
	var resolved_context := _resolve_startup_context(preset, startup_context)
	if resolved_context.has("attack_run_direction"):
		var run_direction := (resolved_context["attack_run_direction"] as Vector2).normalized()
		controller.global_rotation = run_direction.angle() - Vector2.DOWN.angle()
		controller.global_position = _resolve_lateral_attack_position(
			preset,
			controller,
			active_members,
			run_direction,
		)
	else:
		controller.global_position = _resolve_encounter_position(
			preset,
			controller,
			active_members,
		)

	for member in active_members:
		_schedule_encounter_member(
			controller,
			member,
			preset.encounter_id,
			configure_before_add,
			resolved_context,
		)
	controller.start_formation_after_delay(preset.start_delay, resolved_context)
	encounter_spawned.emit(controller)
	return controller


func _schedule_encounter_member(
	controller: FormationController,
	member: EncounterMember,
	spawn_id: StringName,
	configure_before_add: Callable,
	startup_context: Dictionary = {},
) -> void:
	var slot := controller.get_layout().get_slot(member.slot_index)
	assert(slot != null, "Encounter member references missing slot %d." % member.slot_index)
	var delay := member.spawn_delay_override
	if delay < 0.0:
		delay = slot.spawn_delay
	if delay <= 0.0:
		_spawn_encounter_member(
			controller,
			member,
			spawn_id,
			configure_before_add,
			startup_context,
		)
		return
	_spawn_encounter_member_after_delay(
		controller,
		member,
		spawn_id,
		configure_before_add,
		delay,
		startup_context,
	)


func _spawn_encounter_member_after_delay(
	controller: FormationController,
	member: EncounterMember,
	spawn_id: StringName,
	configure_before_add: Callable,
	delay: float,
	startup_context: Dictionary = {},
) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(controller) or controller.is_queued_for_deletion():
		return
	_spawn_encounter_member(
		controller,
		member,
		spawn_id,
		configure_before_add,
		startup_context,
	)


func _spawn_encounter_member(
	controller: FormationController,
	member: EncounterMember,
	spawn_id: StringName,
	configure_before_add: Callable,
	startup_context: Dictionary = {},
) -> void:
	if not is_instance_valid(controller):
		return
	var instance := member.enemy_scene.instantiate()
	var enemy := instance as Enemy
	if enemy == null:
		instance.free()
		push_error(
			"Encounter '%s' slot %d scene root is not Enemy."
			% [spawn_id, member.slot_index]
		)
		controller.notify_member_spawn_failed()
		return
	# EnemyModifierFactory reads both fields from _ready(), so these must be
	# populated before FormationController adds the Enemy to the SceneTree.
	enemy.augment_registry = augment_registry
	enemy.spawn_id = spawn_id
	if configure_before_add.is_valid():
		configure_before_add.call(enemy)
	_apply_entry_warning_direction(enemy, startup_context)
	controller.add_member(
		enemy,
		member.slot_index,
		member.individual_movement_override,
		member.initial_direction,
	)
	enemy_spawned.emit(enemy)


func _resolve_encounter_position(
	preset: EncounterPreset,
	controller: FormationController,
	members: Array[EncounterMember],
) -> Vector2:
	var indices: Array[int] = []
	for member in members:
		indices.append(member.slot_index)
	var bounds := controller.get_used_local_bounds(indices)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var horizontal_spawn_rect := viewport_rect
	if preset.spawn_in_movement_area:
		horizontal_spawn_rect = movement_space_config.get_movement_area(viewport_rect)
	var minimum_x := (
		horizontal_spawn_rect.position.x
		+ preset.spawn_edge_margin
		- bounds.position.x
	)
	var maximum_x := (
		horizontal_spawn_rect.end.x
		- preset.spawn_edge_margin
		- bounds.end.x
	)
	if maximum_x < minimum_x:
		var center_x := viewport_rect.get_center().x
		minimum_x = center_x
		maximum_x = center_x

	var effective_anchor := preset.spawn_anchor
	if preset.mirrored:
		if effective_anchor == EncounterPreset.SpawnAnchor.TOP_LEFT:
			effective_anchor = EncounterPreset.SpawnAnchor.TOP_RIGHT
		elif effective_anchor == EncounterPreset.SpawnAnchor.TOP_RIGHT:
			effective_anchor = EncounterPreset.SpawnAnchor.TOP_LEFT
	var anchor := Vector2(viewport_rect.get_center().x, viewport_rect.position.y)
	match effective_anchor:
		EncounterPreset.SpawnAnchor.TOP_RANDOM:
			anchor.x = randf_range(minimum_x, maximum_x)
		EncounterPreset.SpawnAnchor.TOP_LEFT:
			anchor.x = minimum_x
		EncounterPreset.SpawnAnchor.TOP_RIGHT:
			anchor.x = maximum_x
		EncounterPreset.SpawnAnchor.CENTER:
			anchor = viewport_rect.get_center()
		_:
			anchor.x = viewport_rect.get_center().x
	if effective_anchor != EncounterPreset.SpawnAnchor.CENTER:
		var active_half_depth := maxf(absf(bounds.position.y), absf(bounds.end.y))
		anchor.y -= active_half_depth
	var offset := preset.spawn_offset
	if preset.mirrored:
		offset.x = -offset.x
	return anchor + offset


func _resolve_startup_context(
	preset: EncounterPreset,
	startup_context: Dictionary,
) -> Dictionary:
	var resolved := startup_context.duplicate(true)
	if not _uses_lateral_attack_run(preset):
		return resolved
	if not resolved.has("attack_run_direction"):
		resolved["attack_run_direction"] = (
			Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT
		)
	var run_direction := resolved["attack_run_direction"] as Vector2
	if run_direction.is_zero_approx():
		run_direction = Vector2.RIGHT
	resolved["attack_run_direction"] = run_direction.normalized()
	return resolved


func _uses_lateral_attack_run(preset: EncounterPreset) -> bool:
	var sequence := preset.formation_movement_sequence
	return (
		sequence != null
		and sequence.steps.size() == 1
		and sequence.steps[0] is ForwardAttackRunMovementStep
	)


func _resolve_lateral_attack_position(
	preset: EncounterPreset,
	controller: FormationController,
	members: Array[EncounterMember],
	direction: Vector2,
) -> Vector2:
	var indices: Array[int] = []
	for member in members:
		indices.append(member.slot_index)
	var bounds := controller.get_used_local_bounds(indices)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	# Local +Y becomes world travel after the controller faces the run direction.
	var half_along := maxf(absf(bounds.position.y), absf(bounds.end.y))
	var go_right := direction.x >= 0.0
	var spawn_x := (
		viewport_rect.position.x - preset.spawn_edge_margin - half_along
		if go_right
		else viewport_rect.end.x + preset.spawn_edge_margin + half_along
	)
	# Keep crosses in the upper play band so they do not only dive from deep rear.
	var band_min_y := viewport_rect.position.y + viewport_rect.size.y * 0.16
	var band_max_y := viewport_rect.position.y + viewport_rect.size.y * 0.38
	var spawn_y := randf_range(band_min_y, band_max_y) + preset.spawn_offset.y
	return Vector2(spawn_x, spawn_y)


func _apply_entry_warning_direction(enemy: Enemy, startup_context: Dictionary) -> void:
	if not startup_context.has("attack_run_direction"):
		return
	var warning := enemy.get_node_or_null("EntryWarningComponent") as EntryWarningComponent
	if warning == null:
		return
	var run_direction := startup_context["attack_run_direction"] as Vector2
	if run_direction.is_zero_approx():
		return
	warning.entry_direction = run_direction.normalized()


func _resolve_spawn_parent() -> Node:
	if spawn_parent != null and is_instance_valid(spawn_parent):
		return spawn_parent
	for candidate in get_tree().get_nodes_in_group("gameplay_world"):
		if candidate is Node and candidate.get_viewport() == get_viewport():
			return candidate as Node
	var current_scene := get_tree().current_scene
	assert(current_scene != null, "EnemySpawner requires a spawn parent.")
	return current_scene
