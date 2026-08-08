class_name EnemySpawner
extends Node

signal enemy_spawned(enemy: Enemy)
signal encounter_spawned(controller: FormationController)

const FORMATION_CONTROLLER_SCENE: PackedScene = preload(
	"res://formations/formation_controller.tscn"
)

@export var augment_registry: EnemyAugmentRegistry
@export var spawn_parent: Node


func spawn_encounter(
	preset_resource: Resource,
	additional_count: int = -1,
	configure_before_add: Callable = Callable(),
) -> FormationController:
	assert(augment_registry != null, "EnemySpawner requires an EnemyAugmentRegistry.")
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
	controller.global_position = _resolve_encounter_position(preset, controller, active_members)

	for member in active_members:
		_schedule_encounter_member(
			controller,
			member,
			preset.encounter_id,
			configure_before_add,
		)
	controller.start_formation_after_delay(preset.start_delay)
	encounter_spawned.emit(controller)
	return controller


func _schedule_encounter_member(
	controller: FormationController,
	member: EncounterMember,
	spawn_id: StringName,
	configure_before_add: Callable,
) -> void:
	var slot := controller.get_layout().get_slot(member.slot_index)
	assert(slot != null, "Encounter member references missing slot %d." % member.slot_index)
	var delay := member.spawn_delay_override
	if delay < 0.0:
		delay = slot.spawn_delay
	if delay <= 0.0:
		_spawn_encounter_member(controller, member, spawn_id, configure_before_add)
		return
	_spawn_encounter_member_after_delay(
		controller,
		member,
		spawn_id,
		configure_before_add,
		delay,
	)


func _spawn_encounter_member_after_delay(
	controller: FormationController,
	member: EncounterMember,
	spawn_id: StringName,
	configure_before_add: Callable,
	delay: float,
) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(controller) or controller.is_queued_for_deletion():
		return
	_spawn_encounter_member(controller, member, spawn_id, configure_before_add)


func _spawn_encounter_member(
	controller: FormationController,
	member: EncounterMember,
	spawn_id: StringName,
	configure_before_add: Callable,
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
	var minimum_x := viewport_rect.position.x + preset.spawn_edge_margin - bounds.position.x
	var maximum_x := viewport_rect.end.x - preset.spawn_edge_margin - bounds.end.x
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


func _resolve_spawn_parent() -> Node:
	if spawn_parent != null and is_instance_valid(spawn_parent):
		return spawn_parent
	for candidate in get_tree().get_nodes_in_group("gameplay_world"):
		if candidate is Node and candidate.get_viewport() == get_viewport():
			return candidate as Node
	var current_scene := get_tree().current_scene
	assert(current_scene != null, "EnemySpawner requires a spawn parent.")
	return current_scene
