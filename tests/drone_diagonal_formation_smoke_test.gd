extends SceneTree

## The shipped Drone Encounter must use one shared formation clock while
## preserving its legacy diagonal speed, combat nodes, spacing, and lifecycle.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := PackedStringArray()
	root.add_to_group("gameplay_world")
	var registry := EnemyAugmentRegistry.new()
	root.add_child(registry)
	var spawner := EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = root
	root.add_child(spawner)

	var preset := load(
		"res://resources/encounters/presets/drone_straight_formation.tres"
	) as EncounterPreset
	if preset == null or not preset.validate():
		failures.append("shipped Drone EncounterPreset is invalid")
		await _finish(failures, spawner, registry)
		return
	var controller := spawner.spawn_encounter(preset) as FormationController
	if controller == null:
		failures.append("Drone Encounter did not create FormationController")
		await _finish(failures, spawner, registry)
		return
	var members := controller.get_members()
	_expect(failures, members.size() == 5, "Drone Encounter spawns five members")
	if members.size() != 5:
		await _finish(failures, spawner, registry, controller)
		return

	var start_center := controller.global_position
	for enemy in members:
		_expect(failures, enemy.is_formation_member(), "Drone enters formation mode")
		_expect(
			failures,
			not enemy.movement_controller.is_running(),
			"Drone individual MovementController stays stopped",
		)
		_expect(
			failures,
			enemy.get_node_or_null("FormationDiagonalMoveComponent") == null,
			"legacy per-Drone diagonal component is absent",
		)
		_expect(failures, enemy.get_node_or_null("EnemyShootComponent") != null, "Drone attack remains")
		_expect(failures, enemy.get_node_or_null("HurtboxComponent") != null, "Drone hurtbox remains")
		_expect(failures, enemy.get_node_or_null("HitboxComponent") != null, "Drone hitbox remains")
		_expect(
			failures,
			enemy.get_node_or_null("VisibleOnScreenNotifier2D") is FreeOffscreenComponent,
			"Drone offscreen cleanup remains",
		)

	paused = true
	await create_timer(0.2, true).timeout
	_expect(
		failures,
		controller.global_position.distance_to(start_center) < 0.01,
		"formation clock does not advance while paused",
	)
	paused = false
	await create_timer(0.4).timeout

	_expect(
		failures,
		controller.global_position.y > start_center.y + 15.0,
		"shared Drone center descends at the legacy diagonal pace",
	)
	_expect(
		failures,
		absf(controller.global_position.x - start_center.x) > 15.0,
		"shared Drone center has the legacy lateral diagonal component",
	)
	var sorted_members := controller.get_members()
	sorted_members.sort_custom(func(left: Enemy, right: Enemy) -> bool:
		return left.get_formation_slot().slot_index < right.get_formation_slot().slot_index
	)
	for index in sorted_members.size():
		var slot := sorted_members[index].get_formation_slot()
		var expected := controller.global_transform * slot.position
		_expect(
			failures,
			sorted_members[index].global_position.distance_to(expected) < 0.75,
			"Drone %d remains locked to its shared slot" % index,
		)
	if sorted_members.size() == 5:
		for index in range(1, sorted_members.size()):
			_expect(
				failures,
				is_equal_approx(
					sorted_members[index].global_position.x
					- sorted_members[index - 1].global_position.x,
					24.0,
				),
				"Drone horizontal spacing remains 24 pixels",
			)

	# Exercise the real death path, then make sure the rest of the formation lives.
	sorted_members[1].stats_component.health = 0
	await process_frame
	await process_frame
	_expect(failures, controller.get_members().size() == 4, "one Drone death leaves four bound survivors")
	for survivor in controller.get_members():
		_expect(failures, survivor.is_formation_member(), "surviving Drone remains in formation")

	await _finish(failures, spawner, registry, controller)


func _finish(
	failures: PackedStringArray,
	spawner: Node,
	registry: Node,
	controller: FormationController = null,
) -> void:
	if controller != null and is_instance_valid(controller):
		controller.queue_free()
	if is_instance_valid(spawner):
		spawner.queue_free()
	if is_instance_valid(registry):
		registry.queue_free()
	root.remove_from_group("gameplay_world")
	await process_frame
	if failures.is_empty():
		print("drone_diagonal_formation_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("drone_diagonal_formation_smoke_test: FAIL")
	quit(1)


func _expect(failures: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
