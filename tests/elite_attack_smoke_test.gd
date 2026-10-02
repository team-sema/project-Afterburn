extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(160, 260)
	world.add_child(player)
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	var elite := (load("res://enemies/elite_fighter.tscn") as PackedScene).instantiate() as Enemy
	elite.augment_registry = registry
	elite.position = Vector2(160, -30)
	world.add_child(elite)
	await process_frame
	var attack = elite.get_node("EnemyShootComponent")
	attack.set_process(false)
	attack._process(0.1)
	_expect(attack.get_volleys_fired() == 0, "entry does not shoot")
	elite.position.y = 72
	elite.movement_controller.update_movement(0.1)
	attack._process(0.01)
	_expect(attack.phase == attack.Phase.SALVO, "patrol begins the homing salvo")

	# A-1. Homing salvo
	for i in 4:
		attack._process(0.5)
	await process_frame
	var salvo := get_nodes_in_group("enemy_projectiles")
	_expect(attack.get_volleys_fired() == 4, "salvo fires four pod volleys")
	_expect(salvo.size() == 24, "each pod throws three needles per volley")
	_expect(attack.phase == attack.Phase.AIM, "salvo transitions into aiming")
	if salvo.size() == 24:
		var left: FoundationBullet = salvo[1]
		var right: FoundationBullet = salvo[4]
		_expect(left._origin.distance_to(right._origin) > 26.0, "salvo leaves from both pods")
		_expect(left.appearance.core_size == Vector2(9, 12) and left.appearance.collision_size == Vector2(6, 12), "elite needles are 1.5x with a matching hitbox")
		var left_start: Vector2 = left.behavior_state.velocity_at(0.0)
		_expect(left_start.normalized().is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(115.0))), "left pod throws up and outward")
		_expect(right.behavior_state.velocity_at(0.0).normalized().is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(-115.0))), "right pod throws up and outward")
		_expect(absf(left.behavior_state.velocity_at(0.45).length() - 40.0) < 0.5, "salvo needles brake")
		var start_tint: Color = left.render_tint
		_advance(left, 0.5)
		_expect(start_tint.g > 0.5 and left.render_tint.g < 0.5, "salvo needles turn red before homing")
		_advance(left, 1.5)
		_advance(right, 1.5)
		for needle in [left, right]:
			var to_player: Vector2 = (player.global_position - needle.global_position).normalized()
			_expect(needle.get_travel_velocity().normalized().dot(to_player) > 0.9, "salvo needles curve toward the player")
		_expect(absf(left.get_travel_velocity().length() - 175.0) < 1.0, "salvo needles accelerate after the turn")

	# A-2. Rail burst
	_expect(elite.get_node("EliteAimCone").visible, "aim telegraph is visible")
	_expect(not elite.movement_controller.is_processing(), "aim stops patrol")
	var locked: Vector2 = attack._locked_direction
	player.position.x += 120
	attack._process(0.9)
	_expect(attack.get_volleys_fired() == 4, "telegraph does not fire early")
	attack._process(0.11)
	_expect(attack._locked_direction == locked, "aim stays locked after target moves")
	_expect(not elite.get_node("EliteAimCone").visible, "firing hides telegraph")
	for i in 9:
		attack._process(0.14)
	await process_frame
	var bullets := get_nodes_in_group("enemy_projectiles")
	_expect(bullets.size() == 54, "rail burst fires ten three-needle volleys")
	if bullets.size() == 54:
		var centre: FoundationBullet = bullets[51]
		var side: FoundationBullet = bullets[52]
		_expect(centre.get_travel_velocity().normalized().is_equal_approx(locked), "centre rail follows the warning")
		_expect(side.behavior_state.velocity_at(0.3).normalized().is_equal_approx(locked), "side rails fold back parallel")
		_advance(centre, 0.6)
		_advance(side, 0.6)
		var gap := absf((side.global_position - centre.global_position).dot(locked.orthogonal()))
		_expect(absf(gap - 12.5) < 1.5, "rails run about 12px apart")
	_expect(attack.phase == attack.Phase.RECOVERY and attack.next_is_scissor, "rails enter recovery before pattern B")
	var volleys: int = attack.get_volleys_fired()
	attack._process(0.8)
	_expect(attack.get_volleys_fired() == volleys, "recovery does not fire")

	# B. Scissor crossfire
	attack._process(0.81)
	_expect(attack.phase == attack.Phase.SCISSOR, "recovery after the rails starts the scissor crossfire")
	await process_frame
	var pods := get_nodes_in_group("enemy_projectiles").slice(54)
	_expect(pods.size() == 6, "each pod fires a three-way fan")
	if pods.size() == 6:
		var left: FoundationBullet = pods[1]
		var right: FoundationBullet = pods[4]
		# The hull keeps patrolling after firing, so compare the pods with each other.
		_expect((right._origin - left._origin).is_equal_approx(Vector2(28, 0)), "pods sit 14px either side of the hull")
		_expect(is_equal_approx(left._origin.y, elite.global_position.y + 6.0), "pods sit 6px below the hull")
		var reference: Vector2 = attack._locked_direction
		_expect(left.get_travel_velocity().normalized().is_equal_approx(reference.rotated(deg_to_rad(40.0))), "left pod fires outward")
		_expect(right.get_travel_velocity().normalized().is_equal_approx(reference.rotated(deg_to_rad(-40.0))), "right pod fires outward")
		var left_turn := rad_to_deg(left.behavior_state.velocity_at(0.0).angle_to(left.behavior_state.velocity_at(1.3)))
		var right_turn := rad_to_deg(right.behavior_state.velocity_at(0.0).angle_to(right.behavior_state.velocity_at(1.3)))
		_expect(absf(left_turn + 80.0) < 1.0 and absf(right_turn - 80.0) < 1.0, "both streams bend inward and cross")
	for i in 9:
		attack._process(0.17)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 114, "scissor fires ten pod pairs")
	_expect(attack.phase == attack.Phase.RECOVERY and not attack.next_is_scissor, "scissor returns to pattern A")
	attack._process(1.61)
	_expect(attack.phase == attack.Phase.SALVO, "pattern A resumes after recovery")

	# Action rate, pause and volume augment
	elite.stats_component.health = 100
	attack.apply_action_rate_multiplier(10.0)
	attack._process(0.45)
	for i in 3:
		attack._process(0.18)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 138, "low-health salvo is unchanged")
	_expect(attack.phase == attack.Phase.AIM, "action rate keeps the minimum salvo gap")
	_expect(is_equal_approx(attack._remaining, 1.0), "action rate preserves full warning")
	attack.set_process(true)
	paused = true
	var remaining: float = attack._remaining
	await process_frame
	await process_frame
	_expect(is_equal_approx(attack._remaining, remaining), "pause freezes pattern")
	paused = false
	attack.set_process(false)
	attack._process(1.01)
	for i in 9:
		attack._process(0.08)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 168, "low-health rails are unchanged")
	_expect(attack.phase == attack.Phase.RECOVERY, "action rate keeps the minimum rail gap")
	_expect(is_equal_approx(attack._remaining, 1.0), "action rate preserves minimum recovery")
	attack.shot_count += 2
	attack.phase = attack.Phase.SALVO
	attack._play_phase("salvo")
	attack.barrage_player.stop()
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 178, "volume augment adds needles to each salvo pod")
	attack._begin_rail()
	attack.barrage_player.stop()
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 181, "volume augment leaves the three rails unchanged")
	attack._begin_scissor()
	attack.barrage_player.stop()
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == 191, "volume augment adds pellets to each scissor pod")
	attack.apply_action_rate_multiplier(10.0)
	_expect(is_equal_approx(attack.barrage_player.time_scale, 1.6), "action rate keeps the minimum scissor gap")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("elite attack smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _advance(bullet: Node, age: float) -> void:
	while bullet._active and bullet.age < age - 0.0001:
		bullet._physics_process(minf(1.0 / 60.0, age - bullet.age))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
