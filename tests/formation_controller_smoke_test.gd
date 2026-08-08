extends SceneTree

const CONTROLLER_SCENE := preload("res://formations/formation_controller.tscn")
const HORIZONTAL_LAYOUT := preload("res://formations/layouts/horizontal_formation.tscn")

var failures := PackedStringArray()
var registry: EnemyAugmentRegistry


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	registry = EnemyAugmentRegistry.new()
	registry.name = "FormationControllerTestRegistry"
	root.add_child(registry)
	await _test_center_motion_spacing_and_no_double_motion()
	await _test_center_zigzag_keeps_members_locked()
	await _test_partial_layout_and_mirror()
	await _test_maintain_and_orbit_behaviors()
	await _test_individual_member_detach_preserves_other_slots()
	await _test_nested_slot_parent_transform()
	await _test_member_death_and_empty_cleanup()
	await _test_move_modifier_is_additive()
	await _test_break_preserves_position_context_and_cleanup()
	await _test_deferred_individual_start_is_cancellable()
	registry.queue_free()
	await process_frame

	if failures.is_empty():
		print("formation_controller_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("formation_controller_smoke_test: %s" % failure)
	quit(1)


func _test_center_motion_spacing_and_no_double_motion() -> void:
	var center_sequence := _make_linear_sequence(Vector2.DOWN, 20.0)
	var controller := _make_controller(center_sequence, false, null, 3)
	controller.global_position = Vector2(200.0, 30.0)
	var members: Array[Enemy] = []
	for slot_index in [0, 2, 4]:
		var enemy := _make_enemy()
		# A pre-existing individual velocity must be suppressed in formation mode.
		(enemy.get_node("MoveComponent") as MoveComponent).velocity = Vector2(300.0, 0.0)
		controller.add_member(enemy, slot_index)
		members.append(enemy)

	controller.start_formation()
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var center_before := controller.global_position
	controller.center_movement_controller.update_movement(0.5)
	controller.call("_update_member_positions", 0.5)

	_expect(
		controller.global_position.is_equal_approx(center_before + Vector2(0.0, 10.0)),
		"formation center executes its MovementSequence exactly once",
	)
	for index in members.size():
		var member := members[index]
		var slot_index: int = [0, 2, 4][index]
		var slot := controller.get_layout().get_slot(slot_index)
		var expected := controller.global_transform * slot.position
		_expect(member.is_formation_member(), "member %d enters FORMATION_MEMBER mode" % index)
		_expect(
			member.global_position.is_equal_approx(expected),
			"member %d follows the center target without individual double movement" % index,
		)
		_expect(
			not member.movement_controller.is_running(),
			"member %d individual MovementController remains stopped" % index,
		)
	_expect(
		is_equal_approx(members[1].global_position.x - members[0].global_position.x, 48.0),
		"horizontal spacing from slot 0 to slot 2 is preserved",
	)
	_expect(
		is_equal_approx(members[2].global_position.x - members[1].global_position.x, 48.0),
		"horizontal spacing from slot 2 to slot 4 is preserved",
	)
	await _free_controller(controller)


func _test_center_zigzag_keeps_members_locked() -> void:
	var zigzag := load(
		"res://resources/enemy_movement/sequences/zigzag.tres"
	) as MovementSequence
	var controller := _make_controller(zigzag, false, null, 2)
	controller.global_position = Vector2(320.0, 40.0)
	var left := _make_enemy()
	var right := _make_enemy()
	controller.add_member(left, 0)
	controller.add_member(right, 4)
	controller.start_formation()
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var center_before := controller.global_position
	controller.center_movement_controller.update_movement(0.25)
	controller.call("_update_member_positions", 0.25)

	_expect(
		not is_equal_approx(controller.global_position.x, center_before.x)
		and controller.global_position.y > center_before.y,
		"zigzag MovementSequence moves the formation center laterally and forward",
	)
	_expect(
		is_equal_approx(right.global_position.x - left.global_position.x, 96.0)
		and is_equal_approx(right.global_position.y, left.global_position.y),
		"zigzag movement keeps member spacing rigid",
	)
	_expect(
		not left.movement_controller.is_running()
		and not right.movement_controller.is_running(),
		"zigzag formation does not start per-member controllers",
	)
	await _free_controller(controller)


func _test_partial_layout_and_mirror() -> void:
	var controller := _make_controller(_make_stationary_sequence(), true, null, 2)
	controller.global_position = Vector2(180.0, 50.0)
	var left_authored := _make_enemy()
	var center := _make_enemy()
	controller.add_member(left_authored, 0)
	controller.add_member(center, 2)
	controller.set_process(false)
	controller.call("_update_member_positions", 0.0)

	_expect(controller.get_members().size() == 2, "a partial layout uses only bound slots")
	_expect(
		left_authored.global_position.is_equal_approx(Vector2(228.0, 50.0)),
		"mirroring flips the authored -48 X offset to +48",
	)
	_expect(
		center.global_position.is_equal_approx(Vector2(180.0, 50.0)),
		"mirroring leaves the center slot unchanged",
	)
	var bounds := controller.get_used_local_bounds([0, 2])
	_expect(bounds.position.x == 0.0 and bounds.size.x == 48.0, "mirrored partial bounds are exact")
	await _free_controller(controller)


func _test_maintain_and_orbit_behaviors() -> void:
	var maintain_controller := _make_controller(_make_stationary_sequence(), false, null, 2)
	maintain_controller.global_position = Vector2(120.0, 90.0)
	var maintain_left := _make_enemy()
	var maintain_center := _make_enemy()
	maintain_controller.add_member(maintain_left, 0)
	maintain_controller.add_member(maintain_center, 2)
	maintain_controller.set_process(false)
	maintain_controller.call("_update_member_positions", 0.0)
	_expect(
		maintain_left.global_position.is_equal_approx(Vector2(72.0, 90.0)),
		"MaintainFormationBehavior preserves the authored slot offset",
	)
	await _free_controller(maintain_controller)

	var shared_orbit := OrbitFormationBehavior.new()
	shared_orbit.angular_speed = 90.0
	shared_orbit.clockwise = true
	shared_orbit.excluded_slot_indices = [2]
	var orbit_controller := _make_controller(_make_stationary_sequence(), false, null, 2)
	orbit_controller.formation_behavior = shared_orbit
	orbit_controller.global_position = Vector2(120.0, 90.0)
	var orbit_left := _make_enemy()
	var orbit_center := _make_enemy()
	orbit_controller.add_member(orbit_left, 0)
	orbit_controller.add_member(orbit_center, 2)
	orbit_controller.set_process(false)
	orbit_controller.set("_formation_elapsed", 1.0)
	orbit_controller.call("_update_member_positions", 0.0)
	_expect(
		orbit_left.global_position.is_equal_approx(Vector2(120.0, 42.0)),
		"OrbitFormationBehavior rotates a non-excluded authored slot",
	)
	_expect(
		orbit_center.global_position.is_equal_approx(Vector2(120.0, 90.0)),
		"OrbitFormationBehavior exclusion is based on slot_index",
	)
	_expect(
		is_equal_approx(shared_orbit.angular_speed, 90.0),
		"OrbitFormationBehavior Resource remains configuration-only",
	)
	await _free_controller(orbit_controller)


func _test_individual_member_detach_preserves_other_slots() -> void:
	var controller := _make_controller(_make_stationary_sequence(), false, null, 3)
	controller.global_position = Vector2(200.0, 80.0)
	var left := _make_enemy()
	var center := _make_enemy()
	var right := _make_enemy()
	controller.add_member(left, 0)
	controller.add_member(center, 2)
	controller.add_member(right, 4)
	controller.set_process(false)
	controller.call("_update_member_positions", 0.0)
	var detached_position := center.global_position
	var left_slot_position := left.global_position
	var right_slot_position := right.global_position

	_expect(center.detach_from_formation(), "member-owned behavior can request a detach")
	_expect(not center.is_formation_member(), "detached member becomes individually controlled")
	_expect(center.get_parent() == root, "detached member leaves FormationController ownership")
	_expect(
		center.global_position.is_equal_approx(detached_position),
		"individual detach preserves the member world position",
	)
	_expect(controller.get_members().size() == 2, "individual detach removes only one binding")
	_expect(controller.get_layout().get_slot(2) != null, "detached member leaves its slot empty")

	controller.global_position += Vector2(0.0, 20.0)
	controller.call("_update_member_positions", 0.0)
	_expect(
		left.global_position.is_equal_approx(left_slot_position + Vector2(0.0, 20.0)),
		"left survivor continues following the formation",
	)
	_expect(
		right.global_position.is_equal_approx(right_slot_position + Vector2(0.0, 20.0)),
		"right survivor continues following the formation",
	)
	_expect(
		center.global_position.is_equal_approx(detached_position),
		"FormationController no longer writes the detached member position",
	)
	_expect(
		left.get_formation_slot().slot_index == 0 and right.get_formation_slot().slot_index == 4,
		"survivors are not repacked into the empty slot",
	)
	center.queue_free()
	await _free_controller(controller)


func _test_nested_slot_parent_transform() -> void:
	var layout := FormationLayout.new()
	layout.name = "NestedLayout"
	var authored_container := Node2D.new()
	authored_container.name = "AuthoredContainer"
	authored_container.position = Vector2(17.0, -9.0)
	layout.add_child(authored_container)
	authored_container.owner = layout
	var slot := FormationSlot.new()
	slot.name = "NestedSlot"
	slot.slot_index = 0
	slot.slot_id = &"nested"
	slot.position = Vector2(4.0, 6.0)
	authored_container.add_child(slot)
	slot.owner = layout
	var packed := PackedScene.new()
	_expect(packed.pack(layout) == OK, "nested FormationLayout packs successfully")
	layout.free()

	var controller := CONTROLLER_SCENE.instantiate() as FormationController
	controller.formation_layout_scene = packed
	controller.formation_movement_sequence = _make_stationary_sequence()
	controller.set_pending_member_count(1)
	root.add_child(controller)
	controller.global_position = Vector2(100.0, 80.0)
	var enemy := _make_enemy()
	controller.add_member(enemy, 0)
	controller.set_process(false)
	controller.call("_update_member_positions", 0.0)
	var expected_offset := Vector2(21.0, -3.0)
	_expect(
		enemy.global_position.is_equal_approx(controller.global_position + expected_offset),
		"runtime target includes nested slot-parent transform",
	)
	var bounds := controller.get_used_local_bounds([0])
	_expect(bounds.position.is_equal_approx(expected_offset), "nested slot bounds match editor space")
	await _free_controller(controller)


func _test_member_death_and_empty_cleanup() -> void:
	var controller := _make_controller(_make_stationary_sequence(), false, null, 2)
	var first := _make_enemy()
	var second := _make_enemy()
	controller.add_member(first, 0)
	controller.add_member(second, 1)
	var empty_count := [0]
	controller.formation_empty.connect(func() -> void: empty_count[0] += 1)

	first.queue_free()
	await process_frame
	_expect(is_instance_valid(controller), "formation survives one member death")
	_expect(controller.get_members().size() == 1, "dead member binding is removed")
	_expect(controller.get_members()[0] == second, "surviving member remains bound")

	second.queue_free()
	await process_frame
	await process_frame
	_expect(empty_count[0] == 1, "formation_empty emits exactly once after the final death")
	_expect(not is_instance_valid(controller), "empty FormationController cleans itself up")


func _test_move_modifier_is_additive() -> void:
	var controller := _make_controller(_make_stationary_sequence(), false, null, 1)
	controller.global_position = Vector2(160.0, 80.0)
	var enemy := _make_enemy()
	controller.add_member(enemy, 2)
	controller.set_process(false)
	var modifier := enemy.get_node("MoveModifierComponent") as MoveModifierComponent
	modifier.apply_impulse(Vector2(140.0, 0.0))
	controller.call("_update_member_positions", 0.1)
	var slot_target: Vector2 = controller.global_transform * controller.get_layout().get_slot(2).position
	_expect(
		enemy.global_position.x > slot_target.x + 5.0,
		"MoveModifier impulse remains additive while following a formation target",
	)
	for _index in 50:
		controller.call("_update_member_positions", 0.1)
	_expect(
		enemy.global_position.distance_to(slot_target) < 0.1,
		"member returns to its exact slot as MoveModifier offset decays",
	)
	await _free_controller(controller)


func _test_break_preserves_position_context_and_cleanup() -> void:
	var individual := _make_context_direction_sequence(80.0)
	var controller := _make_controller(_make_stationary_sequence(), false, individual, 2)
	controller.global_position = Vector2(220.0, 70.0)
	var left := _make_enemy()
	var right := _make_enemy()
	controller.add_member(left, 0)
	controller.add_member(right, 4)
	controller.set_process(false)
	controller.call("_update_member_positions", 0.0)
	var left_before := left.global_position
	var right_before := right.global_position
	var released_capture: Array[Enemy] = []
	controller.formation_broken.connect(func(released: Array[Enemy]) -> void:
		released_capture.append_array(released)
	)

	controller.break_formation()
	_expect(released_capture.size() == 2, "formation break releases every living member")
	_expect(left.global_position.is_equal_approx(left_before), "left member preserves global position")
	_expect(right.global_position.is_equal_approx(right_before), "right member preserves global position")
	_expect(left.get_parent() == root and right.get_parent() == root, "released members leave controller ownership")
	_expect(not left.is_formation_member() and not right.is_formation_member(), "released members enter INDIVIDUAL mode")

	var left_context := left.movement_controller.get_context()
	var right_context := right.movement_controller.get_context()
	_expect(left_context.get("slot_index", -1) == 0, "left release context keeps slot index")
	_expect(right_context.get("slot_index", -1) == 4, "right release context keeps slot index")
	_expect(left_context.has("formation_slot_offset"), "release context keeps authored slot offset")
	_expect(left_context.has("locked_player_position"), "release context snapshots target position")
	var left_direction := left_context.get("initial_direction", Vector2.ZERO) as Vector2
	var right_direction := right_context.get("initial_direction", Vector2.ZERO) as Vector2
	_expect(left_direction.y >= -0.001, "left scatter stays in the lower hemisphere")
	_expect(right_direction.y >= -0.001, "right scatter stays in the lower hemisphere")
	_expect(left_direction.x < -0.01, "left wing scatters leftward")
	_expect(right_direction.x > 0.01, "right wing scatters rightward")
	_expect(
		absf(left_direction.angle_to(Vector2.DOWN)) <= PI * 0.5 + 0.001,
		"left scatter is within ±90° of down",
	)
	_expect(
		absf(right_direction.angle_to(Vector2.DOWN)) <= PI * 0.5 + 0.001,
		"right scatter is within ±90° of down",
	)
	_expect(left_direction.length() > 0.5, "left scatter has a usable direction")
	_expect(right_direction.length() > 0.5, "right scatter has a usable direction")

	await process_frame
	left.movement_controller.set_process(false)
	right.movement_controller.set_process(false)
	var left_motion_start := left.global_position
	var right_motion_start := right.global_position
	left.movement_controller.update_movement(0.1)
	right.movement_controller.update_movement(0.1)
	_expect(
		left.global_position.distance_to(left_motion_start) > 1.0,
		"left individual sequence uses release context",
	)
	_expect(
		right.global_position.distance_to(right_motion_start) > 1.0,
		"right individual sequence uses release context",
	)
	await process_frame
	_expect(not is_instance_valid(controller), "broken FormationController cleans itself up")
	left.queue_free()
	right.queue_free()
	await process_frame


func _test_deferred_individual_start_is_cancellable() -> void:
	var individual := _make_context_direction_sequence(80.0)
	var controller := _make_controller(_make_stationary_sequence(), false, individual, 1)
	var enemy := _make_enemy()
	controller.add_member(enemy, 2)
	controller.break_formation()
	# Simulates death/stun replacing movement during the release frame.
	enemy.movement_controller.stop()
	await process_frame
	_expect(
		not enemy.movement_controller.is_running(),
		"same-frame stop cancels the deferred individual movement start",
	)
	if is_instance_valid(enemy):
		enemy.queue_free()
	await process_frame


func _make_controller(
	center_sequence: MovementSequence,
	mirrored: bool,
	individual_sequence: MovementSequence,
	pending_count: int,
) -> FormationController:
	var controller := CONTROLLER_SCENE.instantiate() as FormationController
	controller.formation_layout_scene = HORIZONTAL_LAYOUT
	controller.formation_movement_sequence = center_sequence
	controller.individual_movement_sequence = individual_sequence
	controller.mirrored = mirrored
	controller.set_pending_member_count(pending_count)
	root.add_child(controller)
	return controller


func _make_enemy() -> Enemy:
	var enemy := (load("res://enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.augment_registry = registry
	return enemy


func _make_linear_sequence(direction: Vector2, speed: float) -> MovementSequence:
	var step := LinearMovementStep.new()
	step.direction = direction
	step.speed = speed
	var sequence := MovementSequence.new()
	sequence.steps.append(step)
	return sequence


func _make_stationary_sequence() -> MovementSequence:
	return _make_linear_sequence(Vector2.DOWN, 0.0)


func _make_context_direction_sequence(speed: float) -> MovementSequence:
	var step := LinearMovementStep.new()
	step.direction_context_key = &"initial_direction"
	step.speed = speed
	var sequence := MovementSequence.new()
	sequence.steps.append(step)
	return sequence


func _free_controller(controller: FormationController) -> void:
	if is_instance_valid(controller):
		controller.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
