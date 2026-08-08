extends SceneTree

## Sniper: position once, then AIMING → FIRING → COOLDOWN for at least 3 cycles.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := PackedStringArray()
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(120.0, 280.0)
	root.add_child(player)

	var enemy_scene := load("res://enemies/sniper_enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.set("augment_registry", EnemyAugmentRegistry.new())
	root.add_child(enemy)
	enemy.global_position = Vector2(120.0, -16.0)

	if enemy.get_node_or_null("EnemyShootComponent") != null:
		failures.append("sniper should remove EnemyShootComponent")
	var attack := enemy.get_node_or_null("SniperAttackComponent") as SniperAttackComponent
	if attack == null:
		failures.append("sniper missing SniperAttackComponent")
		await _finish(failures, enemy, player)
		return

	# Fast cycle for headless verification (after deferred ACTION_RATE apply).
	await process_frame
	await process_frame
	attack.set_combat_timings(0.35, 0.12, 0.2)
	attack.telegraph_start_angle = 40.0
	attack.telegraph_end_angle = 2.0

	var movement := enemy.get_node_or_null("MovementController") as MovementController
	for _i in 300:
		await process_frame
		if movement != null and movement.get_current_step_index() == 1:
			break
	if movement == null or movement.get_current_step_index() != 1:
		failures.append("sniper failed to reach HoldPosition step")
	if enemy.global_position.y < 40.0:
		failures.append("sniper failed to reach hover band (y=%.1f)" % enemy.global_position.y)

	# Wait until AIMING starts.
	for _i in 60:
		await process_frame
		if attack.get_combat_state() == SniperAttackComponent.CombatState.AIMING:
			break
	_expect(
		failures,
		attack.get_combat_state() == SniperAttackComponent.CombatState.AIMING,
		"sniper enters AIMING after positioning",
	)
	_expect(failures, attack.is_telegraph_visible(), "AIMING shows telegraph cone")
	var hold_pos := enemy.global_position

	# Track player during AIMING.
	player.global_position = Vector2(40.0, 300.0)
	await create_timer(0.12).timeout
	var aim_left := attack.get_aim_direction()
	player.global_position = Vector2(200.0, 300.0)
	await create_timer(0.12).timeout
	var aim_right := attack.get_aim_direction()
	_expect(
		failures,
		aim_left.x < -0.05 and aim_right.x > 0.05,
		"AIMING continuously tracks player X",
	)

	# Complete first shot cycle and capture laser direction.
	var first_laser_dir := Vector2.ZERO
	var saw_first_laser := false
	for _i in 120:
		await process_frame
		if attack.has_active_laser() and not saw_first_laser:
			saw_first_laser = true
			first_laser_dir = attack.get_aim_direction()
			var laser := _find_laser()
			if laser != null:
				player.global_position = Vector2(20.0, 20.0)
				await create_timer(0.05).timeout
				_expect(
					failures,
					is_equal_approx(laser.rotation, first_laser_dir.angle() - PI * 0.5),
					"fired laser stays fixed while player moves",
				)
		if attack.get_shots_fired() >= 1 and (
			attack.get_combat_state() == SniperAttackComponent.CombatState.COOLDOWN
		):
			break
	_expect(failures, attack.get_shots_fired() >= 1, "first laser fires")
	_expect(
		failures,
		not attack.is_telegraph_visible()
		or attack.get_combat_state() == SniperAttackComponent.CombatState.AIMING,
		"telegraph hidden outside AIMING (or next aim started)",
	)

	# Wait for cooldown telegraph clear explicitly.
	for _i in 60:
		await process_frame
		if attack.get_combat_state() == SniperAttackComponent.CombatState.COOLDOWN:
			_expect(failures, not attack.is_telegraph_visible(), "cooldown has no telegraph")
			_expect(failures, not attack.has_active_laser(), "cooldown has no active laser")
			break

	_expect(
		failures,
		enemy.global_position.distance_to(hold_pos) < 0.5,
		"sniper does not reposition between shots",
	)

	# Run until at least 3 shots without overlap / stuck state.
	for _i in 400:
		await process_frame
		if attack.get_shots_fired() >= 3:
			break
		if (
			attack.has_active_laser()
			and attack.get_combat_state() == SniperAttackComponent.CombatState.AIMING
		):
			failures.append("new AIMING started while previous laser still active")
			break

	_expect(failures, attack.get_shots_fired() >= 3, "sniper fires at least 3 times")
	_expect(
		failures,
		enemy.global_position.distance_to(hold_pos) < 0.5,
		"sniper hold position stable after 3 shots",
	)
	_expect(
		failures,
		attack.get_combat_state() != SniperAttackComponent.CombatState.POSITIONING,
		"sniper never returns to POSITIONING after first hold",
	)

	# Encounter preset validates (sniper rides behind tanker).
	var preset := load("res://resources/encounters/presets/tanker_guard_sniper.tres") as EncounterPreset
	if preset == null or not preset.validate():
		failures.append("tanker_guard_sniper EncounterPreset is invalid")

	await _finish(failures, enemy, player)


func _find_laser() -> SniperLaserBeam:
	for node in root.get_children():
		if node is SniperLaserBeam:
			return node as SniperLaserBeam
	for node in root.get_children():
		for child in node.get_children():
			if child is SniperLaserBeam:
				return child as SniperLaserBeam
	return null


func _expect(failures: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: PackedStringArray, enemy: Node, player: Node) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	await process_frame
	if failures.is_empty():
		print("sniper_enemy_smoke_test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("sniper_enemy_smoke_test: FAIL")
		quit(1)
