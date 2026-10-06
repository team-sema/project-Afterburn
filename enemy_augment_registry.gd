class_name EnemyAugmentRegistry
extends Node

signal augment_added(augment: EnemyAugment)
signal augments_cleared

@export var active_augments: Array[EnemyAugment] = []
## Shared lower-screen safety line for every opted-in EnemyShootComponent.
@export_range(0.0, 1.0, 0.01) var shot_threshold_y_ratio := 0.7

var _seen_enemy_scene_paths := {}


func add_augment(augment: EnemyAugment) -> void:
	assert(augment != null, "Cannot add a null EnemyAugment.")
	if not can_add_augment(augment):
		return
	active_augments.append(augment)
	augment_added.emit(augment)


func get_active_augments() -> Array[EnemyAugment]:
	return active_augments.duplicate()


func get_stack_count(augment_id: StringName) -> int:
	var stack_count := 0

	for augment in active_augments:
		if augment.augment_id == augment_id:
			stack_count += 1

	return stack_count


func can_add_augment(augment: EnemyAugment) -> bool:
	if augment == null:
		return false
	return augment.max_stacks <= 0 or get_stack_count(augment.augment_id) < augment.max_stacks


func get_additional_spawn_count(spawn_id: StringName) -> int:
	var additional_count := 0
	for augment in active_augments:
		if augment.target_spawn_id == spawn_id:
			additional_count += augment.additional_spawn_count
	return additional_count


func get_elite_escort_presets() -> Array[EncounterPreset]:
	var presets: Array[EncounterPreset] = []
	for augment in active_augments:
		if augment.elite_escort_preset != null:
			presets.append(augment.elite_escort_preset)
	return presets


## Records an original Encounter scene the moment it spawns; evolution cards
## for that enemy become eligible from then on.
func note_enemy_scene_spawned(scene: PackedScene) -> void:
	if scene != null:
		_seen_enemy_scene_paths[scene.resource_path] = true


func has_seen_enemy_scene(scene: PackedScene) -> bool:
	return scene != null and _seen_enemy_scene_paths.has(scene.resource_path)


## Returns the evolved scene for an original Encounter scene, or the scene itself.
func resolve_enemy_scene(scene: PackedScene) -> PackedScene:
	if scene == null:
		return scene
	for augment in active_augments:
		if augment.is_evolution() and augment.evolution_from.resource_path == scene.resource_path:
			return augment.evolution_to
	return scene


func clear_augments() -> void:
	_seen_enemy_scene_paths.clear()
	if active_augments.is_empty():
		return

	active_augments.clear()
	augments_cleared.emit()
