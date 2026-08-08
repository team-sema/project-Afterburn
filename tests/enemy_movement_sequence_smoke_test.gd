extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_sequence_resources_load()
	await _test_bomb_sequence()
	await _test_striker_and_caster_migration()
	await _test_sequence_replacement()
	await _test_shared_resource_state_isolation()
	await _test_step_transitions_and_finish()
	await _test_step_signal_reentrancy()
	await _test_homing_step()
	await _test_stop_and_legacy_fallback()

	if failures.is_empty():
		print("enemy_movement_sequence_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_movement_sequence_smoke_test: %s" % failure)
	quit(1)


func _test_sequence_resources_load() -> void:
	var paths := [
		"res://resources/enemy_movement/sequences/bomb_straight_down.tres",
		"res://resources/enemy_movement/sequences/striker_entry_patrol.tres",
		"res://resources/enemy_movement/sequences/caster_entry_patrol.tres",
		"res://resources/enemy_movement/sequences/straight_down.tres",
		"res://resources/enemy_movement/sequences/x9_caster_entry_patrol.tres",
		"res://resources/enemy_movement/sequences/x9_drone_down.tres",
		"res://resources/enemy_movement/sequences/zigzag.tres",
		"res://resources/enemy_movement/sequences/move_to_center_then_wait.tres",
		"res://resources/enemy_movement/sequences/drone_entry_gather.tres",
		"res://resources/enemy_movement/sequences/drone_midmap_entry.tres",
		"res://resources/enemy_movement/sequences/formation_entry_third.tres",
		"res://resources/enemy_movement/sequences/formation_entry_third_patrol.tres",
		"res://resources/enemy_movement/sequences/individual_scatter_double.tres",
		"res://resources/enemy_movement/sequences/individual_scatter_2_5.tres",
		"res://resources/enemy_movement/sequences/individual_striker_charge_2_5.tres",
		"res://resources/enemy_movement/sequences/entry_then_exit.tres",
	]
	for path in paths:
		var sequence := load(path) as MovementSequence
		_expect(sequence != null, "%s loads as MovementSequence" % path)
		if sequence != null:
			_expect(sequence.validate(), "%s contains valid steps" % path)


func _test_bomb_sequence() -> void:
	var bomb := _make_enemy("res://enemies/bomb_enemy.tscn")
	var controller := _prepare_manual_controller(bomb)
	root.add_child(bomb)
	bomb.global_position = Vector2(100.0, 20.0)
	await process_frame
	var start := bomb.global_position
	controller.update_movement(0.5)
	_expect(controller.is_running(), "Bomb starts its scene MovementSequence")
	_expect(
		bomb.global_position.is_equal_approx(start + Vector2(0.0, 8.0)),
		"Bomb preserves its 16 px/s straight descent",
	)
	await _free_node(bomb)


func _test_striker_and_caster_migration() -> void:
	var striker_sequence := load(
		"res://resources/enemy_movement/sequences/striker_entry_patrol.tres"
	) as MovementSequence
	var striker := _make_enemy("res://enemies/moving_enemy.tscn")
	striker.set_movement_sequence(
		striker_sequence,
		{"initial_direction": Vector2.RIGHT},
	)
	var striker_controller := _prepare_manual_controller(striker)
	root.add_child(striker)
	striker.global_position = Vector2(137.0, -20.0)
	await process_frame
	striker_controller.update_movement(10.0)
	_expect(
		striker.global_position.is_equal_approx(Vector2(137.0, 180.0)),
		"Striker captures its final spawn X and reaches y=180",
	)
	_expect(striker_controller.get_current_step_index() == 1, "Striker enters patrol step")
	striker_controller.update_movement(0.1)
	_expect(striker.global_position.x > 137.0, "Striker preserves injected patrol direction")
	_expect(is_equal_approx(striker.global_position.y, 180.0), "Striker patrol holds Y")
	_expect(
		striker.get_node_or_null("StrikerDivePatrolComponent") == null,
		"Striker no longer carries its fixed movement component",
	)

	var caster_sequence := load(
		"res://resources/enemy_movement/sequences/caster_entry_patrol.tres"
	) as MovementSequence
	var caster := _make_enemy("res://enemies/shooting_enemy.tscn")
	caster.set_movement_sequence(
		caster_sequence,
		{"initial_direction": Vector2.RIGHT},
	)
	var caster_controller := _prepare_manual_controller(caster)
	root.add_child(caster)
	caster.global_position = Vector2(211.0, -16.0)
	await process_frame
	caster_controller.update_movement(10.0)
	_expect(
		caster.global_position.is_equal_approx(Vector2(211.0, 56.0)),
		"Caster captures its final spawn X and reaches y=56",
	)
	_expect(caster_controller.get_current_step_index() == 1, "Caster enters patrol step")
	caster_controller.update_movement(0.1)
	_expect(caster.global_position.x > 211.0, "Caster patrol moves horizontally")
	_expect(is_equal_approx(caster.global_position.y, 56.0), "Caster patrol holds Y")
	_expect(
		caster.get_node_or_null("CasterHoverComponent") == null,
		"Caster no longer carries its fixed movement component",
	)

	await _free_node(striker)
	await _free_node(caster)


func _test_sequence_replacement() -> void:
	var straight := load(
		"res://resources/enemy_movement/sequences/straight_down.tres"
	) as MovementSequence
	var zigzag := load(
		"res://resources/enemy_movement/sequences/zigzag.tres"
	) as MovementSequence
	var enemy := _make_enemy("res://enemies/enemy.tscn")
	enemy.set_movement_sequence(straight)
	var controller := _prepare_manual_controller(enemy)
	root.add_child(enemy)
	enemy.global_position = Vector2(100.0, 0.0)
	await process_frame
	controller.update_movement(0.5)
	_expect(
		enemy.global_position.is_equal_approx(Vector2(100.0, 30.0)),
		"an Enemy accepts a straight sequence",
	)
	enemy.set_movement_sequence(zigzag)
	controller.set_process(false)
	var before_zigzag := enemy.global_position
	controller.update_movement(0.25)
	_expect(enemy.global_position.y > before_zigzag.y, "the same Enemy accepts a new sequence")
	_expect(
		not is_equal_approx(enemy.global_position.x, before_zigzag.x),
		"the replacement zigzag sequence changes lateral position",
	)
	await _free_node(enemy)


func _test_shared_resource_state_isolation() -> void:
	var shared := load(
		"res://resources/enemy_movement/sequences/entry_then_exit.tres"
	) as MovementSequence
	var first := _make_enemy("res://enemies/enemy.tscn")
	var second := _make_enemy("res://enemies/enemy.tscn")
	first.set_movement_sequence(shared)
	second.set_movement_sequence(shared)
	var first_controller := _prepare_manual_controller(first)
	var second_controller := _prepare_manual_controller(second)
	root.add_child(first)
	root.add_child(second)
	first.global_position = Vector2(40.0, 0.0)
	second.global_position = Vector2(80.0, 0.0)
	await process_frame
	first_controller.update_movement(2.0)
	second_controller.update_movement(0.25)
	_expect(first_controller.get_current_step_index() == 1, "first shared sequence advances")
	_expect(second_controller.get_current_step_index() == 0, "second shared sequence keeps its state")
	_expect(is_equal_approx(first.global_position.y, 80.0), "first shared sequence reaches entry")
	_expect(is_equal_approx(second.global_position.y, 15.0), "second shared sequence advances independently")
	await _free_node(first)
	await _free_node(second)


func _test_step_transitions_and_finish() -> void:
	var move_to := MoveToPositionStep.new()
	move_to.target_position = Vector2(10.0, 0.0)
	move_to.speed = 10.0
	var wait := WaitMovementStep.new()
	wait.duration = 0.25
	var linear := LinearMovementStep.new()
	linear.direction = Vector2.DOWN
	linear.speed = 20.0
	linear.duration = 0.5
	var sequence := MovementSequence.new()
	sequence.steps.append(move_to)
	sequence.steps.append(wait)
	sequence.steps.append(linear)

	var started: Array[int] = []
	var completed: Array[int] = []
	var finish_count := [0]
	var enemy := _make_enemy("res://enemies/enemy.tscn")
	enemy.set_movement_sequence(sequence)
	var controller := _prepare_manual_controller(enemy)
	controller.step_started.connect(func(index: int, _step: MovementStep) -> void:
		started.append(index)
	)
	controller.step_finished.connect(func(index: int, _step: MovementStep) -> void:
		completed.append(index)
	)
	controller.sequence_finished.connect(func() -> void:
		finish_count[0] += 1
	)
	root.add_child(enemy)
	enemy.global_position = Vector2.ZERO
	await process_frame

	controller.update_movement(1.0)
	_expect(controller.get_current_step_index() == 1, "MoveTo transitions to Wait")
	controller.update_movement(0.25)
	_expect(controller.get_current_step_index() == 2, "Wait transitions to Linear")
	controller.update_movement(0.5)
	_expect(not controller.is_running() and controller.is_finished(), "finite sequence finishes")
	_expect(enemy.global_position.is_equal_approx(Vector2(10.0, 10.0)), "steps apply in order")
	_expect(started == [0, 1, 2], "step_started emits for every step")
	_expect(completed == [0, 1, 2], "step_finished emits for every step")
	_expect(finish_count[0] == 1, "sequence_finished emits once")
	await _free_node(enemy)


func _test_homing_step() -> void:
	var homing := HomingMovementStep.new()
	homing.speed = 100.0
	homing.target_context_key = &"test_target"
	var sequence := MovementSequence.new()
	sequence.steps.append(homing)
	var enemy := _make_enemy("res://enemies/enemy.tscn")
	enemy.set_movement_sequence(sequence, {"test_target": Vector2(100.0, 0.0)})
	var controller := _prepare_manual_controller(enemy)
	root.add_child(enemy)
	enemy.global_position = Vector2.ZERO
	await process_frame
	controller.update_movement(0.5)
	_expect(
		enemy.global_position.is_equal_approx(Vector2(50.0, 0.0)),
		"HomingMovementStep follows its context target",
	)
	await _free_node(enemy)


func _test_step_signal_reentrancy() -> void:
	var first := WaitMovementStep.new()
	first.duration = 0.1
	var second := LinearMovementStep.new()
	second.speed = 100.0
	var sequence := MovementSequence.new()
	sequence.steps.append(first)
	sequence.steps.append(second)
	var enemy := _make_enemy("res://enemies/enemy.tscn")
	enemy.set_movement_sequence(sequence)
	var controller := _prepare_manual_controller(enemy)
	controller.step_finished.connect(func(index: int, _step: MovementStep) -> void:
		if index == 0:
			controller.stop()
	)
	root.add_child(enemy)
	enemy.global_position = Vector2(25.0, 25.0)
	await process_frame
	controller.update_movement(0.1)
	var stopped_position := enemy.global_position
	controller.update_movement(1.0)
	_expect(not controller.is_running(), "a step_finished listener can stop the controller")
	_expect(controller.get_current_step_index() == -1, "reentrant stop clears the step index")
	_expect(enemy.global_position == stopped_position, "reentrant stop does not start the next step")
	await _free_node(enemy)


func _test_stop_and_legacy_fallback() -> void:
	var sequence := load(
		"res://resources/enemy_movement/sequences/straight_down.tres"
	) as MovementSequence
	var enemy := _make_enemy("res://enemies/enemy.tscn")
	enemy.set_movement_sequence(sequence, {}, false)
	var controller := _prepare_manual_controller(enemy)
	root.add_child(enemy)
	enemy.global_position = Vector2(30.0, 40.0)
	await process_frame
	_expect(not controller.is_running(), "start_immediately=false survives tree entry")
	_expect(enemy.global_position == Vector2(30.0, 40.0), "a pre-tree stopped sequence stays still")

	controller.start()
	controller.set_process(false)
	controller.update_movement(0.25)
	_expect(enemy.global_position == Vector2(30.0, 55.0), "an explicitly started sequence moves")
	controller.stop()
	var stopped_position := enemy.global_position
	controller.update_movement(1.0)
	_expect(enemy.global_position == stopped_position, "stop prevents further sequence movement")

	var move := enemy.get_node("MoveComponent") as MoveComponent
	controller.clear_sequence()
	move.process_mode = Node.PROCESS_MODE_DISABLED
	move.velocity = Vector2(12.0, 0.0)
	move._process(0.5)
	_expect(
		enemy.global_position == stopped_position + Vector2(6.0, 0.0),
		"an Enemy without a sequence retains legacy velocity movement",
	)
	await _free_node(enemy)


func _make_enemy(path: String) -> Enemy:
	var scene := load(path) as PackedScene
	var enemy := scene.instantiate() as Enemy
	enemy.augment_registry = EnemyAugmentRegistry.new()
	return enemy


func _prepare_manual_controller(enemy: Enemy) -> MovementController:
	var controller := enemy.get_node("MovementController") as MovementController
	var move := enemy.get_node("MoveComponent") as MoveComponent
	controller.process_mode = Node.PROCESS_MODE_DISABLED
	move.process_mode = Node.PROCESS_MODE_DISABLED
	return controller


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
