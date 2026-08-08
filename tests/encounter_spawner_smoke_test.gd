extends SceneTree

const PRESET_PATHS := [
	"res://resources/encounters/presets/drone_straight_formation.tres",
	"res://resources/encounters/presets/drone_zigzag_formation.tres",
	"res://resources/encounters/presets/awl_charge_formation.tres",
	"res://resources/encounters/presets/drone_entry_scatter.tres",
	"res://resources/encounters/presets/drone_zigzag_mirrored.tres",
	"res://resources/encounters/presets/x9_drone_down.tres",
	"res://resources/encounters/presets/x9_caster_drone_orbit.tres",
	"res://resources/encounters/presets/v7_drone_down.tres",
	"res://resources/encounters/presets/striker_single.tres",
	"res://resources/encounters/presets/bomb_single.tres",
	"res://resources/encounters/presets/caster_single.tres",
	"res://resources/encounters/presets/tanker_guard_sniper.tres",
	"res://resources/encounters/presets/interceptor_pair.tres",
	"res://resources/encounters/presets/interceptor_trio.tres",
]

var failures := PackedStringArray()
var world: Node2D
var spawner: EnemySpawner
var registry: EnemyAugmentRegistry


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.name = "EncounterTestWorld"
	world.add_to_group("gameplay_world")
	root.add_child(world)
	registry = EnemyAugmentRegistry.new()
	registry.name = "EncounterTestRegistry"
	root.add_child(registry)
	spawner = EnemySpawner.new()
	spawner.name = "EnemySpawner"
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	root.add_child(spawner)

	await _test_all_presets_validate_and_spawn()
	_test_invalid_preset_errors_are_explicit()
	await _test_drone_base_and_reinforced_offsets()
	await _test_delays_respect_pause()
	await _test_break_waits_for_delayed_members()
	await _test_mirrored_anchor_swaps_sides()
	await _test_member_direction_overrides_propagate()
	await _test_awl_breaks_into_individual_charge()
	await _test_consecutive_encounters_coexist()
	await _test_single_encounter_compatibility()

	spawner.queue_free()
	registry.queue_free()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("encounter_spawner_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("encounter_spawner_smoke_test: %s" % failure)
	quit(1)


func _test_all_presets_validate_and_spawn() -> void:
	var ids: Dictionary = {}
	var spawn_signal_count := [0]
	var signal_connection := func(_controller: FormationController) -> void:
		spawn_signal_count[0] += 1
	spawner.encounter_spawned.connect(signal_connection)
	for path in PRESET_PATHS:
		var preset := load(path) as EncounterPreset
		_expect(preset != null, "%s loads as EncounterPreset" % path)
		if preset == null:
			continue
		var validation_errors := preset.get_validation_errors()
		_expect(
			validation_errors.is_empty(),
			"%s validates: %s" % [path, "; ".join(validation_errors)],
		)
		if not validation_errors.is_empty():
			continue
		_expect(not ids.has(preset.encounter_id), "%s has a unique encounter_id" % path)
		ids[preset.encounter_id] = true

		var controller := spawner.spawn_encounter(preset) as FormationController
		_expect(controller != null, "%s spawns a FormationController" % path)
		if controller == null:
			continue
		var complete := await _wait_for_members(controller, preset.members.size(), 0.8)
		_expect(complete, "%s spawns every authored member" % path)
		if is_instance_valid(controller):
			_expect(controller.get_parent() == world, "%s spawns under the configured world" % path)
			_expect(controller.get_layout().validate_slots(), "%s uses a valid layout instance" % path)
			for enemy in controller.get_members():
				_expect(enemy.is_formation_member(), "%s member enters formation mode" % path)
				_expect(enemy.spawn_id == preset.encounter_id, "%s member receives encounter spawn_id" % path)
			controller.queue_free()
			await process_frame

	spawner.encounter_spawned.disconnect(signal_connection)
	_expect(
		spawn_signal_count[0] == PRESET_PATHS.size(),
		"all encounter presets emit encounter_spawned",
	)


func _test_invalid_preset_errors_are_explicit() -> void:
	var empty := EncounterPreset.new()
	var empty_errors := empty.get_validation_errors()
	_expect(_contains_text(empty_errors, "encounter_id"), "missing encounter_id is reported")
	_expect(_contains_text(empty_errors, "FormationLayout"), "missing layout is reported")
	_expect(_contains_text(empty_errors, "formation MovementSequence"), "missing movement is reported")
	_expect(_contains_text(empty_errors, "at least one member"), "empty member list is reported")

	var invalid := EncounterPreset.new()
	invalid.encounter_id = &"invalid_contract_test"
	invalid.formation_layout_scene = load(
		"res://formations/layouts/horizontal_formation.tscn"
	) as PackedScene
	invalid.formation_movement_sequence = load(
		"res://resources/enemy_movement/sequences/straight_down.tres"
	) as MovementSequence
	invalid.formation_break_condition = EncounterPreset.FormationBreakCondition.SEQUENCE_FINISHED
	for _index in 2:
		var member := EncounterMember.new()
		member.enemy_scene = load("res://enemies/normal_enemy.tscn") as PackedScene
		member.slot_index = 99
		invalid.members.append(member)
	var errors := invalid.get_validation_errors()
	_expect(_contains_text(errors, "duplicate slot_index"), "duplicate member slot is reported")
	_expect(_contains_text(errors, "missing slot_index"), "missing layout slot is reported")
	_expect(_contains_text(errors, "no individual MovementSequence"), "missing break Sequence is reported")


func _test_delays_respect_pause() -> void:
	var preset := load(PRESET_PATHS[3]).duplicate(true) as EncounterPreset
	preset.encounter_id = &"paused_delay_test"
	preset.start_delay = 0.3
	var controller := spawner.spawn_encounter(preset) as FormationController
	_expect(controller.get_members().size() == 1, "only the zero-delay member spawns immediately")
	paused = true
	await create_timer(0.6, true).timeout
	_expect(controller.get_members().size() == 1, "member spawn delays stop while paused")
	_expect(
		not controller.center_movement_controller.is_running(),
		"formation start delay stops while paused",
	)
	paused = false
	await create_timer(0.55).timeout
	_expect(controller.get_members().size() == 5, "stagger resumes after unpausing")
	_expect(controller.center_movement_controller.is_running(), "formation starts after unpausing")
	controller.queue_free()
	await process_frame


func _test_break_waits_for_delayed_members() -> void:
	var preset := load(PRESET_PATHS[3]).duplicate(true) as EncounterPreset
	preset.encounter_id = &"pending_break_test"
	var wait_step := WaitMovementStep.new()
	wait_step.duration = 0.05
	var short_sequence := MovementSequence.new()
	short_sequence.steps.append(wait_step)
	preset.formation_movement_sequence = short_sequence
	var controller := spawner.spawn_encounter(preset) as FormationController
	var released: Array[Enemy] = []
	controller.formation_broken.connect(func(members: Array[Enemy]) -> void:
		released.append_array(members)
	)
	await create_timer(0.16).timeout
	_expect(is_instance_valid(controller), "break request keeps controller alive for pending members")
	_expect(released.is_empty(), "formation does not release before delayed members spawn")
	await create_timer(0.5).timeout
	await process_frame
	_expect(released.size() == 5, "all declared delayed members spawn before release")
	_expect(not is_instance_valid(controller), "controller cleans up after deferred break")
	for enemy in released:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame


func _test_mirrored_anchor_swaps_sides() -> void:
	var preset := load(PRESET_PATHS[0]).duplicate(true) as EncounterPreset
	preset.encounter_id = &"mirrored_anchor_test"
	preset.spawn_anchor = EncounterPreset.SpawnAnchor.TOP_LEFT
	preset.spawn_offset.x = 0.0
	preset.mirrored = true
	var controller := spawner.spawn_encounter(preset) as FormationController
	var viewport_rect := spawner.get_viewport().get_visible_rect()
	_expect(
		controller.global_position.x > viewport_rect.get_center().x,
		"mirroring swaps a TOP_LEFT anchor to the right side",
	)
	controller.queue_free()
	await process_frame


func _test_drone_base_and_reinforced_offsets() -> void:
	var preset := load(PRESET_PATHS[0]) as EncounterPreset
	var base_controller := spawner.spawn_encounter(preset, 0) as FormationController
	_expect(base_controller.get_members().size() == 5, "base Drone encounter spawns five members")
	_expect(
		_get_member_local_x_positions(base_controller) == [-48.0, -24.0, 0.0, 24.0, 48.0],
		"base Drone encounter preserves authored five-slot offsets",
	)
	base_controller.queue_free()
	await process_frame

	var reinforced := spawner.spawn_encounter(preset, 1) as FormationController
	_expect(reinforced.get_members().size() == 6, "reinforced Drone encounter spawns six members")
	_expect(reinforced.get_layout().get_slot_count() == 6, "reinforcement creates one runtime slot")
	_expect(
		_get_member_local_x_positions(reinforced) == [-60.0, -36.0, -12.0, 12.0, 36.0, 60.0],
		"six Drone slots remain evenly spaced and centered",
	)
	var indices: Array[int] = []
	for enemy in _get_members_sorted(reinforced):
		indices.append(enemy.get_formation_slot().slot_index)
	_expect(indices == [0, 1, 2, 3, 4, 5], "reinforcement slot indices remain explicit and contiguous")
	reinforced.queue_free()
	await process_frame

	# The six-member expansion must be local to its instantiated layout.
	var base_again := spawner.spawn_encounter(preset) as FormationController
	_expect(base_again.get_layout().get_slot_count() == 5, "runtime expansion does not mutate the PackedScene")
	_expect(
		_get_member_local_x_positions(base_again) == [-48.0, -24.0, 0.0, 24.0, 48.0],
		"a later base encounter still has its original offsets",
	)
	base_again.queue_free()
	await process_frame


func _test_member_direction_overrides_propagate() -> void:
	var preset := load(PRESET_PATHS[3]) as EncounterPreset
	var controller := spawner.spawn_encounter(preset) as FormationController
	var complete := await _wait_for_members(controller, preset.members.size(), 0.8)
	_expect(complete, "staggered scatter encounter spawns all members before break")
	if not complete or not is_instance_valid(controller):
		return
	controller.set_process(false)
	var members := controller.get_members()
	controller.break_formation()
	for enemy in members:
		var context := enemy.movement_controller.get_context()
		var actual := context.get("initial_direction", Vector2.ZERO) as Vector2
		var slot_offset := context.get("formation_slot_offset", Vector2.ZERO) as Vector2
		_expect(actual.y >= -0.001, "scatter direction stays in the lower hemisphere")
		_expect(
			absf(actual.angle_to(Vector2.DOWN)) <= PI * 0.5 + 0.001,
			"scatter direction is within ±90° of down",
		)
		_expect(actual.length() > 0.5, "scatter direction is usable")
		if slot_offset.x < -0.5:
			_expect(actual.x < -0.01, "left scatter member fans left")
		elif slot_offset.x > 0.5:
			_expect(actual.x > 0.01, "right scatter member fans right")
	await process_frame
	for enemy in members:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame


func _test_awl_breaks_into_individual_charge() -> void:
	var player := Node2D.new()
	player.name = "AwlTestPlayer"
	player.global_position = Vector2(320.0, 320.0)
	player.add_to_group("player")
	world.add_child(player)
	var preset := load(PRESET_PATHS[2]) as EncounterPreset
	var controller := spawner.spawn_encounter(preset) as FormationController
	var awls := controller.get_members()
	_expect(awls.size() == 3, "Awl encounter spawns its three actual enemies")
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var initial_center_y := controller.global_position.y

	# The shipped formation sequence is a 1.4 s descent, then each Awl charges 3 s.
	controller.center_movement_controller.update_movement(1.5)
	controller.call("_update_member_positions", 1.5)
	_expect(
		controller.global_position.y > initial_center_y + 58.0,
		"Awl formation performs its shared descent before charging",
	)
	await process_frame

	var charging_positions: Array[Vector2] = []
	for awl in awls:
		_expect(is_instance_valid(awl), "Awl survives its individual detach")
		if not is_instance_valid(awl):
			continue
		_expect(not awl.is_formation_member(), "Awl switches to individual ownership")
		_expect(awl.get_parent() == world, "detached Awl is reparented to the encounter world")
		_expect(awl.call("is_charging"), "detached Awl enters its 3 second charge state")
		_expect(not awl.movement_controller.is_running(), "Awl stays stopped while charging")
		charging_positions.append(awl.global_position)

	player.global_position = Vector2(180.0, 300.0)
	var charge_directions: Array[Vector2] = []
	for index in awls.size():
		var awl := awls[index]
		if not is_instance_valid(awl):
			continue
		awl.set_process(false)
		awl.call("_process", 1.5)
		_expect(
			awl.global_position.is_equal_approx(charging_positions[index]),
			"Awl remains at its detach position during charging",
		)
		awl.call("_process", 1.5)
		var movement: MovementController = awl.movement_controller
		movement.set_process(false)
		_expect(awl.call("is_dashing"), "Awl enters DASHING after the charge completes")
		_expect(movement.is_running(), "Awl starts its individual dash MovementSequence")
		_expect(
			awl.call("get_captured_target_position") == player.global_position,
			"Awl captures the player's position at the end of charging",
		)
		var context_direction := (
			movement.get_context().get("player_direction", Vector2.DOWN) as Vector2
		).normalized()
		charge_directions.append(context_direction)
		var before := awl.global_position
		movement.update_movement(0.1)
		var charge_delta := awl.global_position - before
		_expect(
			absf(charge_delta.length() - 28.0) < 0.1,
			"Awl preserves its 280 px/s individual dash speed",
		)
		_expect(
			charge_delta.normalized().dot(context_direction) > 0.999,
			"Awl dash follows the locked individual context",
		)
	_expect(
		charge_directions.size() == 3
		and not charge_directions[0].is_equal_approx(charge_directions[2]),
		"separated Awls resolve distinct charge directions",
	)
	await process_frame
	_expect(not is_instance_valid(controller), "Awl controller cleans up after all individual detaches")
	for awl in awls:
		if is_instance_valid(awl):
			awl.queue_free()
	player.queue_free()
	await process_frame


func _test_consecutive_encounters_coexist() -> void:
	var straight := load(PRESET_PATHS[0]) as EncounterPreset
	var zigzag := load(PRESET_PATHS[1]) as EncounterPreset
	var first := spawner.spawn_encounter(straight) as FormationController
	var second := spawner.spawn_encounter(zigzag) as FormationController
	_expect(first != second, "consecutive calls create distinct FormationControllers")
	_expect(
		first.get_parent() == world and second.get_parent() == world,
		"consecutive encounters coexist under one world",
	)
	_expect(first.get_members().size() == 5, "first consecutive encounter remains complete")
	_expect(second.get_members().size() == 5, "second consecutive encounter is complete")
	for enemy in first.get_members():
		_expect(enemy.spawn_id == straight.encounter_id, "first encounter keeps its preset scope")
	for enemy in second.get_members():
		_expect(enemy.spawn_id == zigzag.encounter_id, "second encounter keeps its preset scope")
	first.queue_free()
	second.queue_free()
	await process_frame


func _test_single_encounter_compatibility() -> void:
	var preset := load(
		"res://resources/encounters/presets/striker_single.tres"
	) as EncounterPreset
	var enemy_signal_count := [0]
	var signal_connection := func(_enemy: Enemy) -> void: enemy_signal_count[0] += 1
	spawner.enemy_spawned.connect(signal_connection)
	var controller := spawner.spawn_encounter(preset) as FormationController
	_expect(controller != null, "single EncounterPreset creates a FormationController")
	var spawned := controller.get_members()[0] as Enemy
	_expect(spawned.is_formation_member(), "single enemy enters the common formation lifecycle")
	await process_frame
	await process_frame
	_expect(is_instance_valid(spawned), "single Encounter keeps its Enemy after formation release")
	if is_instance_valid(spawned):
		_expect(spawned.get_parent() == world, "released single enemy uses configured spawn parent")
		_expect(spawned.spawn_id == &"striker_single", "single enemy uses EncounterPreset id")
		_expect(not spawned.is_formation_member(), "single enemy releases to INDIVIDUAL mode")
		_expect(spawned.movement_controller.is_running(), "single Striker starts its authored movement")
		spawned.queue_free()
		await process_frame
	spawner.enemy_spawned.disconnect(signal_connection)
	_expect(enemy_signal_count[0] == 1, "single Encounter emits one enemy_spawned signal")


func _wait_for_members(
	controller: FormationController,
	expected_count: int,
	timeout_seconds: float,
) -> bool:
	var elapsed := 0.0
	while is_instance_valid(controller) and controller.get_members().size() < expected_count:
		if elapsed >= timeout_seconds:
			break
		await create_timer(0.05).timeout
		elapsed += 0.05
	return is_instance_valid(controller) and controller.get_members().size() == expected_count


func _get_members_sorted(controller: FormationController) -> Array[Enemy]:
	var members := controller.get_members()
	members.sort_custom(func(left: Enemy, right: Enemy) -> bool:
		return left.get_formation_slot().slot_index < right.get_formation_slot().slot_index
	)
	return members


func _get_member_local_x_positions(controller: FormationController) -> Array[float]:
	var positions: Array[float] = []
	for enemy in _get_members_sorted(controller):
		positions.append(snappedf(controller.to_local(enemy.global_position).x, 0.01))
	return positions


func _contains_text(lines: PackedStringArray, needle: String) -> bool:
	for line in lines:
		if line.to_lower().contains(needle.to_lower()):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
