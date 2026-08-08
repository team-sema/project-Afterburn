extends SceneTree

## The shipped Awl Encounter descends and aims as one V. Each Awl then detaches,
## freezes for three seconds, captures the player once, and dashes independently.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := PackedStringArray()
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(320.0, 260.0)
	root.add_child(player)
	var registry := EnemyAugmentRegistry.new()
	root.add_child(registry)
	var spawner := EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = root
	root.add_child(spawner)

	var preset := load(
		"res://resources/encounters/presets/awl_charge_formation.tres"
	) as EncounterPreset
	if preset == null or not preset.validate():
		failures.append("shipped Awl EncounterPreset is invalid")
		await _finish(failures, player, spawner, registry)
		return
	var controller := spawner.spawn_encounter(preset) as FormationController
	if controller == null:
		failures.append("Awl Encounter did not create FormationController")
		await _finish(failures, player, spawner, registry)
		return
	var members := controller.get_members()
	members.sort_custom(func(left: Enemy, right: Enemy) -> bool:
		return left.get_formation_slot().slot_index < right.get_formation_slot().slot_index
	)
	_expect(failures, members.size() == 3, "Awl Encounter spawns three members")
	if members.size() != 3:
		await _finish(failures, player, spawner, registry, controller)
		return
	for enemy in members:
		_expect(failures, enemy.is_formation_member(), "Awl starts as FORMATION_MEMBER")
		_expect(
			failures,
			enemy.get_node_or_null("KamikazeAimChargeComponent") == null,
			"legacy per-Awl movement component is absent",
		)
		_expect(failures, enemy.get_node_or_null("EnemyShootComponent") == null, "Awl remains non-shooting")
		_expect(failures, enemy.get_node_or_null("HurtboxComponent") != null, "Awl hurtbox remains")
		_expect(failures, enemy.get_node_or_null("HitboxComponent") != null, "Awl hitbox remains")
		_expect(
			failures,
			enemy.get_node_or_null("VisibleOnScreenNotifier2D") is FreeOffscreenComponent,
			"Awl offscreen cleanup remains",
		)

	# Descend has completed and the shared Wait/aim step is active; V must hold.
	await create_timer(1.6).timeout
	for enemy in members:
		var slot := enemy.get_formation_slot()
		var expected := controller.global_transform * slot.position
		_expect(
			failures,
			enemy.global_position.distance_to(expected) < 0.75,
			"Awl holds its V slot during the aim phase",
		)
		_expect(failures, not enemy.movement_controller.is_running(), "individual charge stays stopped")

	# The 1.4 second descend + 1.4 second wait lets each Awl request its detach.
	await create_timer(1.35).timeout
	await process_frame
	var charging_positions: Array[Vector2] = []
	for enemy in members:
		_expect(failures, is_instance_valid(enemy), "Awl survives formation detach")
		if not is_instance_valid(enemy):
			continue
		_expect(failures, not enemy.is_formation_member(), "Awl switches to INDIVIDUAL")
		_expect(failures, enemy.get_parent() == root, "detached Awl is reparented without deletion")
		_expect(failures, enemy.call("is_charging"), "Awl begins CHARGING after detach")
		_expect(failures, not enemy.movement_controller.is_running(), "Awl movement stays stopped")
		charging_positions.append(enemy.global_position)

	await create_timer(1.4).timeout
	for index in members.size():
		_expect(
			failures,
			members[index].global_position.distance_to(charging_positions[index]) < 0.1,
			"Awl %d stays at its detach world position while charging" % index,
		)
	player.global_position = Vector2(180.0, 300.0)
	await create_timer(1.7).timeout
	for enemy in members:
		_expect(failures, enemy.call("is_dashing"), "Awl enters DASHING after three seconds")
		_expect(failures, enemy.movement_controller.is_running(), "Awl individual dash Sequence starts")
		_expect(
			failures,
			enemy.call("get_captured_target_position") == player.global_position,
			"Awl captures the current player position after charging",
		)
		_expect(
			failures,
			is_equal_approx(enemy.move_component.velocity.length(), 280.0),
			"Awl preserves the dash speed of 280",
		)
	_expect(
		failures,
		not members[1].move_component.velocity.normalized().is_equal_approx(
			members[2].move_component.velocity.normalized()
		),
		"different V slots receive different locked charge directions",
	)
	var locked_velocities: Array[Vector2] = []
	for enemy in members:
		locked_velocities.append(enemy.move_component.velocity.normalized())
	player.global_position = Vector2(20.0, 20.0)
	await create_timer(0.1).timeout
	for index in members.size():
		_expect(
			failures,
			members[index].move_component.velocity.normalized().is_equal_approx(
				locked_velocities[index]
			),
			"Awl %d keeps the release-time target snapshot" % index,
		)
	_expect(
		failures,
		not is_instance_valid(controller),
		"Awl FormationController is cleaned after individual detaches",
	)

	await _finish(failures, player, spawner, registry)


func _finish(
	failures: PackedStringArray,
	player: Node,
	spawner: Node,
	registry: Node,
	controller: FormationController = null,
) -> void:
	if controller != null and is_instance_valid(controller):
		controller.queue_free()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(spawner):
		spawner.queue_free()
	if is_instance_valid(registry):
		registry.queue_free()
	await process_frame
	if failures.is_empty():
		print("kamikaze_aim_charge_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("kamikaze_aim_charge_smoke_test: FAIL")
	quit(1)


func _expect(failures: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
