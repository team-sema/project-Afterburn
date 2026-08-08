extends SceneTree

const X9_DRONE := "res://resources/encounters/presets/x9_drone_down.tres"
const X9_ORBIT := "res://resources/encounters/presets/x9_caster_drone_orbit.tres"
const V7_STRIKER := "res://resources/encounters/presets/v7_striker_drone.tres"
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
	await _test_x9_caster_drone_orbit()
	await _test_v7_striker_drone()
	await _test_mixed_special_detach_keeps_regular_members()
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


func _test_x9_caster_drone_orbit() -> void:
	var preset := load(X9_ORBIT) as EncounterPreset
	_expect(preset != null and preset.validate(), "X9_Caster_Drone_Orbit preset validates")
	var controller := spawner.spawn_encounter(preset) as FormationController
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var members := _members_by_slot(controller)
	_expect(members.size() == 9, "X9_Caster_Drone_Orbit spawns nine members")
	var caster := members.get(0) as Enemy
	_expect(
		caster != null
		and _is_scene(caster, "res://enemies/shooting_enemy/shooting_enemy.tscn"),
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


func _test_v7_striker_drone() -> void:
	var preset := load(V7_STRIKER) as EncounterPreset
	_expect(preset != null and preset.validate(), "V7_Striker_Drone preset validates")
	var controller := spawner.spawn_encounter(preset) as FormationController
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var members := _members_by_slot(controller)
	_expect(members.size() == 7, "V7_Striker_Drone spawns seven members")
	var striker := members.get(0) as Enemy
	_expect(
		striker != null and _is_scene(striker, "res://enemies/moving_enemy.tscn"),
		"V7 center contains the Striker",
	)
	for slot_index in members:
		var enemy := members[slot_index] as Enemy
		_expect(enemy.is_formation_member(), "V7 member is formation-controlled")
		_expect(not enemy.movement_controller.is_running(), "V7 suppresses per-enemy movement")
		_expect(enemy.get_node_or_null("HurtboxComponent") != null, "V7 member keeps combat collision")
		if slot_index != 0:
			_expect(
				_is_scene(enemy, "res://enemies/normal_enemy.tscn"),
				"V7 non-center slot is a Drone",
			)
	await _free_controller(controller)


func _test_mixed_special_detach_keeps_regular_members() -> void:
	var preset := load(
		"res://resources/encounters/presets/mixed_partial_diamond.tres"
	) as EncounterPreset
	var controller := spawner.spawn_encounter(preset) as FormationController
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var awl: Enemy
	var drones: Array[Enemy] = []
	for enemy in controller.get_members():
		if _is_scene(enemy, "res://enemies/kamikaze_enemy.tscn"):
			awl = enemy
		else:
			drones.append(enemy)
	_expect(awl != null and drones.size() == 2, "mixed Encounter spawns one Awl and two Drones")
	var awl_slot := awl.get_formation_slot().slot_index
	var awl_position := awl.global_position
	controller.center_movement_controller.sequence_finished.emit()
	_expect(awl.call("is_charging"), "mixed Encounter Awl independently begins charging")
	_expect(not awl.is_formation_member(), "mixed Encounter detaches only the Awl")
	_expect(controller.get_members().size() == 2, "regular mixed members remain bound")
	_expect(controller.get_layout().get_slot(awl_slot) != null, "detached mixed slot remains empty")
	var drone_positions: Array[Vector2] = []
	for drone in drones:
		drone_positions.append(drone.global_position)
	controller.global_position += Vector2(0.0, 24.0)
	controller.call("_update_member_positions", 0.0)
	_expect(awl.global_position.is_equal_approx(awl_position), "charging Awl ignores formation motion")
	for index in drones.size():
		_expect(drones[index].is_formation_member(), "regular mixed member remains formation-controlled")
		_expect(
			drones[index].global_position.is_equal_approx(
				drone_positions[index] + Vector2(0.0, 24.0)
			),
			"regular mixed member continues following the formation",
		)
	awl.queue_free()
	await _free_controller(controller)


func _test_weighted_main_pool_and_flat_spawn() -> void:
	var pool := load(POOL_PATH) as EncounterPool
	_expect(pool != null and pool.validate(), "MainEncounterPool validates")
	_expect(pool.entries.size() == 8, "MainEncounterPool exposes the complete live roster")
	var random_number_generator := RandomNumberGenerator.new()
	random_number_generator.seed = 20260807
	var counts: Dictionary = {}
	for _index in 6000:
		var selected := pool.choose(3, random_number_generator)
		counts[selected.encounter_id] = int(counts.get(selected.encounter_id, 0)) + 1
	_expect(
		int(counts.get(&"x9_drone_down", 0)) > int(counts.get(&"v7_striker_drone", 0))
		and int(counts.get(&"v7_striker_drone", 0)) > int(
			counts.get(&"x9_caster_drone_orbit", 0)
		),
		"MainEncounterPool weighted sampling follows flattened 3:2:1 complex ordering",
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
