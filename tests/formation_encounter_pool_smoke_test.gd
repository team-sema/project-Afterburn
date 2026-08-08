extends SceneTree

const X9_DRONE := "res://resources/encounters/presets/x9_drone_down.tres"
const X9_ORBIT := "res://resources/encounters/presets/x9_caster_drone_orbit.tres"
const V7_DRONE := "res://resources/encounters/presets/v7_drone_down.tres"
const POOL_PATH := "res://resources/encounters/pools/main_encounter_pool.tres"

var failures := PackedStringArray()
var world: Node2D
var registry: EnemyAugmentRegistry
var spawner: EnemySpawner


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	registry = EnemyAugmentRegistry.new()
	root.add_child(registry)
	spawner = EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	root.add_child(spawner)

	await _test_x9_drone_down()
	await _test_x9_drone_midmap_scatter()
	await _test_x9_caster_drone_orbit()
	await _test_v7_drone_down()
	await _test_v9_drone_down()
	await _test_v3_and_x5_midmap_scatter_presets()
	await _test_weighted_main_pool_and_flat_spawn()

	spawner.queue_free()
	registry.queue_free()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("formation_encounter_pool_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("formation_encounter_pool_smoke_test: %s" % failure)
	quit(1)


func _test_x9_drone_down() -> void:
	var preset := load(X9_DRONE) as EncounterPreset
	_expect(preset != null and preset.validate(), "X9_Drone_Down preset validates")
	var controller := spawner.spawn_encounter(preset) as FormationController
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var members := _members_by_slot(controller)
	_expect(members.size() == 9, "X9_Drone_Down spawns nine members")
	_expect(controller.formation_behavior is MaintainFormationBehavior, "X9_Drone_Down uses Maintain")
	var before_center := controller.global_position
	controller.center_movement_controller.update_movement(0.25)
	controller.call("_update_member_positions", 0.25)
	_expect(controller.global_position.y > before_center.y, "X9_Drone_Down center descends")
	for slot_index in members:
		var enemy := members[slot_index] as Enemy
		_expect(
			_is_scene(enemy, "res://enemies/normal_enemy.tscn"),
			"X9_Drone_Down slot %d is a Drone" % slot_index,
		)
		_expect(enemy.is_formation_member(), "X9 Drone remains formation-controlled")
		_expect(not enemy.movement_controller.is_running(), "X9 Drone has no individual movement")
		_expect(
			enemy.global_position.is_equal_approx(
				controller.global_transform * controller.get_layout().get_slot(slot_index).position
			),
			"X9 Drone slot %d keeps its X layout offset" % slot_index,
		)
	await _free_controller(controller)


func _test_x9_drone_midmap_scatter() -> void:
	var preset := load(X9_DRONE) as EncounterPreset
	_expect(
		preset.formation_break_condition
		== EncounterPreset.FormationBreakCondition.SEQUENCE_FINISHED,
		"X9_Drone_Down breaks when midmap entry finishes",
	)
	_expect(
		preset.individual_movement_sequence != null
		and preset.individual_movement_sequence.resource_path.ends_with(
			"individual_scatter_double.tres"
		),
		"X9_Drone_Down uses double-speed scatter after break",
	)
	var midmap := preset.formation_movement_sequence
	_expect(midmap != null and midmap.steps.size() >= 1, "X9 midmap entry has steps")
	_expect(midmap.steps[0] is MoveToPositionStep, "X9 midmap entry starts with MoveTo")
	var move_to := midmap.steps[0] as MoveToPositionStep
	_expect(move_to.target_position_is_viewport_ratio, "X9 midmap uses viewport ratio")
	_expect(is_equal_approx(move_to.target_position.y, 0.5), "X9 midmap targets half-map Y")
	_expect(not move_to.affect_x, "X9 midmap keeps spawn column")
	_expect(is_equal_approx(move_to.speed, 60.0), "X9 midmap entry speed is 60")

	var scatter := preset.individual_movement_sequence
	var scatter_step := scatter.steps[0] as LinearMovementStep
	_expect(is_equal_approx(scatter_step.speed, 150.0), "scatter is 2.5x midmap entry speed")

	var controller := spawner.spawn_encounter(preset) as FormationController
	var broken := [false]
	controller.formation_broken.connect(func(_released: Array[Enemy]) -> void: broken[0] = true)
	var visible := controller.get_viewport_rect()
	var target_y := visible.position.y + visible.size.y * 0.5
	# Drive past midmap arrival instead of waiting real-time.
	for _index in 80:
		if broken[0] or not is_instance_valid(controller):
			break
		controller.center_movement_controller.update_movement(0.05)
		controller.call("_update_member_positions", 0.05)
		await process_frame
	_expect(broken[0], "X9 formation breaks after reaching midmap")
	await process_frame
	await process_frame
	_expect(not is_instance_valid(controller), "X9 controller frees after scatter release")
	var released_count := 0
	for child in world.get_children():
		if child is Enemy:
			released_count += 1
			var enemy := child as Enemy
			_expect(not enemy.is_formation_member(), "released X9 drone is individual")
			_expect(enemy.movement_controller.is_running(), "released X9 drone runs scatter")
			enemy.movement_controller.set_process(false)
			enemy.movement_controller.update_movement(0.05)
			var context := enemy.movement_controller.get_context()
			var direction := context.get("initial_direction", Vector2.ZERO) as Vector2
			_expect(direction.y >= -0.001, "X9 scatter stays in the lower hemisphere")
			var slot_offset := context.get("formation_slot_offset", Vector2.ZERO) as Vector2
			if slot_offset.x < -0.5:
				_expect(direction.x < -0.01, "left X9 wing scatters leftward")
			elif slot_offset.x > 0.5:
				_expect(direction.x > 0.01, "right X9 wing scatters rightward")
			else:
				_expect(absf(direction.x) <= 0.35, "center X9 column scatters near down")
			var move := enemy.get_node("MoveComponent") as MoveComponent
			_expect(
				is_equal_approx(move.velocity.length(), 150.0),
				"X9 scatter uses 2.5x speed",
			)
			_expect(
				enemy.global_position.y > target_y - 40.0,
				"X9 scatter starts near half-map depth",
			)
	_expect(released_count == 9, "all nine X9 drones scatter individually")
	for child in world.get_children():
		if child is Enemy:
			child.queue_free()
	await process_frame


func _test_x9_caster_drone_orbit() -> void:
	var preset := load(X9_ORBIT) as EncounterPreset
	_expect(preset != null and preset.validate(), "X9_Caster_Drone_Orbit preset validates")
	var sequence := preset.formation_movement_sequence
	_expect(
		sequence != null and sequence.steps.size() == 2,
		"X9_Caster_Drone_Orbit enters then patrols at the top",
	)
	_expect(
		sequence.steps[1] is HorizontalPatrolMovementStep,
		"X9_Caster_Drone_Orbit ends on HorizontalPatrolMovementStep",
	)
	var controller := spawner.spawn_encounter(preset) as FormationController
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var members := _members_by_slot(controller)
	_expect(members.size() == 9, "X9_Caster_Drone_Orbit spawns nine members")
	var caster := members.get(0) as Enemy
	_expect(
		caster != null
		and _is_scene(caster, "res://enemies/shooting_enemy.tscn"),
		"center slot contains the Caster",
	)
	var behavior := controller.formation_behavior as OrbitFormationBehavior
	_expect(behavior != null, "X9_Caster_Drone_Orbit uses OrbitFormationBehavior")
	_expect(behavior.excluded_slot_indices == [0], "Orbit excludes the center by slot index")
	var caster_before := caster.global_position
	var drone_before := (members.get(3) as Enemy).global_position
	var radius_before := drone_before.distance_to(controller.global_position)
	controller.set("_formation_elapsed", 1.0)
	controller.call("_update_member_positions", 0.0)
	var drone_after := (members.get(3) as Enemy).global_position
	_expect(caster.global_position.is_equal_approx(caster_before), "excluded center Caster remains fixed")
	_expect(not drone_after.is_equal_approx(drone_before), "Drone offset rotates around the center")
	_expect(
		is_equal_approx(drone_after.distance_to(controller.global_position), radius_before),
		"Orbit preserves each Drone radius",
	)
	for slot_index in members:
		if slot_index == 0:
			continue
		_expect(
			_is_scene(members[slot_index] as Enemy, "res://enemies/normal_enemy.tscn"),
			"non-center X9 slot is a Drone",
		)
	await _free_controller(controller)


func _test_v7_drone_down() -> void:
	var preset := load(V7_DRONE) as EncounterPreset
	_expect(preset != null and preset.validate(), "V7_Drone_Down preset validates")
	var controller := spawner.spawn_encounter(preset) as FormationController
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var members := _members_by_slot(controller)
	_expect(members.size() == 7, "V7_Drone_Down spawns seven members")
	for slot_index in members:
		var enemy := members[slot_index] as Enemy
		_expect(enemy.is_formation_member(), "V7 member is formation-controlled")
		_expect(not enemy.movement_controller.is_running(), "V7 suppresses per-enemy movement")
		_expect(enemy.get_node_or_null("HurtboxComponent") != null, "V7 member keeps combat collision")
		_expect(
			_is_scene(enemy, "res://enemies/normal_enemy.tscn"),
			"V7 slot is a Drone",
		)
	await _free_controller(controller)


func _test_v9_drone_down() -> void:
	var preset := load("res://resources/encounters/presets/v9_drone_down.tres") as EncounterPreset
	_expect(preset != null and preset.validate(), "V9_Drone_Down preset validates")
	_expect(
		preset.formation_break_condition
		== EncounterPreset.FormationBreakCondition.SEQUENCE_FINISHED,
		"V9_Drone_Down breaks at midmap",
	)
	var controller := spawner.spawn_encounter(preset) as FormationController
	var members := _members_by_slot(controller)
	_expect(members.size() == 9, "V9_Drone_Down spawns nine members")
	_expect(
		controller.get_layout().get_slot(7) != null and controller.get_layout().get_slot(8) != null,
		"V9 layout exposes far wing slots",
	)
	await _free_controller(controller)


func _test_v3_and_x5_midmap_scatter_presets() -> void:
	for path in [
		"res://resources/encounters/presets/v3_drone_down.tres",
		"res://resources/encounters/presets/v5_drone_down.tres",
		"res://resources/encounters/presets/v7_drone_down.tres",
		"res://resources/encounters/presets/v9_drone_down.tres",
		"res://resources/encounters/presets/x5_drone_down.tres",
		"res://resources/encounters/presets/x9_drone_down.tres",
		"res://resources/encounters/presets/inverted_v3_drone_down.tres",
		"res://resources/encounters/presets/inverted_v5_drone_down.tres",
		"res://resources/encounters/presets/inverted_v7_drone_down.tres",
	]:
		var preset := load(path) as EncounterPreset
		_expect(preset != null and preset.validate(), "%s validates" % path)
		_expect(
			preset.spawn_anchor == EncounterPreset.SpawnAnchor.TOP_RANDOM,
			"%s spawns at a random top X" % path,
		)
		_expect(
			preset.formation_break_condition
			== EncounterPreset.FormationBreakCondition.SEQUENCE_FINISHED,
			"%s breaks at midmap" % path,
		)
		_expect(
			preset.individual_movement_sequence != null
			and preset.individual_movement_sequence.resource_path.ends_with(
				"individual_scatter_double.tres"
			),
			"%s uses 2.5x-speed scatter" % path,
		)


func _test_weighted_main_pool_and_flat_spawn() -> void:
	var pool := load(POOL_PATH) as EncounterPool
	_expect(pool != null and pool.validate(), "MainEncounterPool validates")
	_expect(pool.entries.size() == 13, "MainEncounterPool exposes the complete live roster")
	var random_number_generator := RandomNumberGenerator.new()
	random_number_generator.seed = 20260807
	var counts: Dictionary = {}
	for _index in 6000:
		var selected := pool.choose(3, random_number_generator)
		counts[selected.encounter_id] = int(counts.get(selected.encounter_id, 0)) + 1
	# Inverse difficulty: v7(7) > x9(9) > orbit(15).
	_expect(
		int(counts.get(&"v7_drone_down", 0)) > int(counts.get(&"x9_drone_down", 0))
		and int(counts.get(&"x9_drone_down", 0)) > int(
			counts.get(&"x9_caster_drone_orbit", 0)
		),
		"MainEncounterPool weighted sampling follows inverse-difficulty ordering",
	)

	var selected := pool.choose(3, random_number_generator)
	var controller := spawner.spawn_encounter(selected) as FormationController
	_expect(controller != null, "EnemySpawner spawns the MainEncounterPool selection")
	var spawned_members := controller.get_members()
	_expect(not spawned_members.is_empty(), "pool-selected Encounter spawns actual members")
	if not spawned_members.is_empty():
		_expect(
			spawned_members[0].spawn_id == selected.encounter_id,
			"pool selection keeps the selected preset id through EnemySpawner",
		)
	await _free_controller(controller)


func _members_by_slot(controller: FormationController) -> Dictionary:
	var result: Dictionary = {}
	for enemy in controller.get_members():
		result[enemy.get_formation_slot().slot_index] = enemy
	return result


func _is_scene(enemy: Enemy, path: String) -> bool:
	return enemy != null and enemy.scene_file_path == path


func _free_controller(controller: FormationController) -> void:
	if controller != null and is_instance_valid(controller):
		controller.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
