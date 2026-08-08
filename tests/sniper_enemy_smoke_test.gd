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
	attack.set_combat_timings(0.35, 0.12, 0.2, 0.08)
	attack.telegraph_start_angle = 12.0
	attack.telegraph_end_angle = 0.05

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
	_expect(failures, attack.is_telegraph_visible(), "AIMING shows dual-line telegraph")
	var initial_telegraph_angle := attack.aim_cone.half_angle_degrees
	var initial_telegraph_alpha := attack.aim_cone.get_line_alpha()
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
	_expect(
		failures,
		attack.aim_cone.half_angle_degrees < initial_telegraph_angle,
		"telegraph guide lines close together during AIMING",
	)
	_expect(
		failures,
		attack.aim_cone.get_line_alpha() > initial_telegraph_alpha,
		"telegraph guide lines darken as focus closes",
	)

	# Fully focused lines linger briefly before the shot.
	for _i in 30:
		await process_frame
		if is_equal_approx(
			attack.aim_cone.half_angle_degrees,
			attack.telegraph_end_angle,
		):
			break
	_expect(
		failures,
		attack.get_combat_state() == SniperAttackComponent.CombatState.AIMING,
		"sniper holds full focus before firing",
	)
	_expect(failures, attack.get_shots_fired() == 0, "full focus does not fire immediately")

	# Complete first shot cycle and capture bullet direction.
	var first_bullet_dir := Vector2.ZERO
	var saw_first_bullet := false
	var visual_anchor := enemy.get_node("Anchor") as Node2D
	var anchor_rest_position := visual_anchor.position
	for _i in 120:
		await process_frame
		if attack.has_active_bullet() and not saw_first_bullet:
			saw_first_bullet = true
			first_bullet_dir = attack.get_aim_direction()
			var bullet := _find_bullet()
			if bullet != null:
				await process_frame
				var recoil_offset := visual_anchor.position - anchor_rest_position
				var local_shot_direction := first_bullet_dir.rotated(-enemy.global_rotation)
				_expect(
					failures,
					recoil_offset.dot(local_shot_direction) < -0.5,
					"sniper visual kicks backward on fire",
				)
				var bullet_start := bullet.global_position
				player.global_position = Vector2(20.0, 20.0)
				await create_timer(0.05).timeout
				_expect(
					failures,
					is_equal_approx(bullet.rotation, first_bullet_dir.angle() - PI * 0.5),
					"fired bullet stays on the telegraphed path while player moves",
				)
				_expect(
					failures,
					bullet.global_position.distance_to(bullet_start) > 20.0,
					"sniper bullet travels at high speed",
				)
				await create_timer(0.2).timeout
				_expect(
					failures,
					visual_anchor.position.distance_to(anchor_rest_position) < 0.1,
					"sniper visual returns after recoil",
				)
		if attack.get_shots_fired() >= 1 and (
			attack.get_combat_state() == SniperAttackComponent.CombatState.COOLDOWN
		):
			break
	_expect(failures, attack.get_shots_fired() >= 1, "first bullet fires")
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
			break

	_expect(
		failures,
		enemy.global_position.distance_to(hold_pos) < 0.5,
		"sniper does not reposition between shots",
	)

	# Run until at least 3 shots without overlapping rounds or a stuck state.
	for _i in 400:
		await process_frame
		if attack.get_shots_fired() >= 3:
			break
		if _count_bullets() > 1:
			failures.append("sniper spawned overlapping bullets")
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


func _find_bullet() -> SniperBullet:
	for node in root.get_children():
		if node is SniperBullet:
			return node as SniperBullet
	for node in root.get_children():
		for child in node.get_children():
			if child is SniperBullet:
				return child as SniperBullet
	return null


func _count_bullets() -> int:
	var count := 0
	for node in root.get_children():
		if node is SniperBullet:
			count += 1
		for child in node.get_children():
			if child is SniperBullet:
				count += 1
	return count


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
