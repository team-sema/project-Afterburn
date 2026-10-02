extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(5, 100)
	world.add_child(player)
	var elite := (load("res://enemies/elite_awl.tscn") as PackedScene).instantiate() as Enemy
	elite.augment_registry = registry
	elite.position = Vector2(160, -40)
	world.add_child(elite)
	await process_frame
	var attack = elite.get_node("EnemyShootComponent")
	attack.set_process(false)
	attack._process(0.1)
	_expect(attack.get_volleys_fired() == 0, "no entry shots")
	elite.position.y = 72
	elite.movement_controller.update_movement(0.1)
	attack._process(0.01)
	_expect(attack.phase == attack.Phase.RECOVERY, "entry reaches recovery")
	_expect(not elite.movement_controller.is_running(), "charge owns movement after entry")
	attack._process(1.21)
	_expect(attack.phase == attack.Phase.AIM, "recovery enters aiming")
	var direction: Vector2 = attack.dash_direction
	_expect(direction.x < -0.9 and direction.y > 0.0, "wall target produces a diagonal dash")
	_expect(elite.get_node("ChargeVisual").aiming, "parallel lane warns dash direction")
	_expect(not elite.get_node("EliteAimCone").visible, "old cone stays hidden")
	player.position = Vector2(5, 140)
	attack._process(0.3)
	_expect(not attack.dash_direction.is_equal_approx(direction), "aim follows a moving player")
	attack._process(0.33)
	direction = attack.dash_direction
	_expect(attack._aim_locked, "final aim portion locks the warning")
	player.position = Vector2(300, 300)
	attack._process(0.16)
	_expect(attack.phase == attack.Phase.AIM, "full aim duration is preserved")
	attack._process(0.02)
	_expect(attack.dash_direction == direction, "moving target cannot redirect a warned dash")
	var origin := elite.global_position
	attack._process(0.2)
	_expect(elite.global_position.is_equal_approx(origin + direction * 64.0), "dash follows locked direction at authored speed")
	await process_frame
	var bullets := get_nodes_in_group("enemy_projectiles")
	_expect(attack.use_spine and bullets.size() == 6, "first dash drops spine pairs along the path")
	if bullets.size() == 6:
		var a: Vector2 = bullets[0].behavior_state.velocity_at(0.0)
		var b: Vector2 = bullets[1].behavior_state.velocity_at(0.0)
		_expect(absf(a.normalized().dot(direction)) < 0.01 and absf(b.normalized().dot(direction)) < 0.01, "spines leave perpendicular to the dash")
		_expect(a.dot(direction.orthogonal()) * b.dot(direction.orthogonal()) < 0.0, "spines go to opposite sides")
	_expect(not elite.get_node("ChargeVisual")._embers.is_empty(), "dash leaves world-space embers")
	for i in 100:
		if attack.phase != attack.Phase.DASH:
			break
		attack._process(0.025)
	_expect(attack.phase == attack.Phase.REENTRY_WARNING, "left edge escape starts reentry warning")
	_expect(is_instance_valid(elite) and not elite.is_queued_for_deletion(), "screen exit is not death")
	var bounds := elite.get_viewport_rect()
	_expect(is_equal_approx(elite.global_position.x, bounds.position.x + bounds.size.x * 0.75), "left escape selects opposite top lane")
	_expect(elite.global_position.y == bounds.position.y - 64.0, "reentry starts fully above screen")
	var volleys: int = attack.get_volleys_fired()
	attack.set_process(true)
	paused = true
	var elapsed: float = attack._elapsed
	await process_frame
	await process_frame
	_expect(is_equal_approx(attack._elapsed, elapsed), "pause freezes reentry")
	paused = false
	attack.set_process(false)
	attack._process(0.71)
	attack._process(2.0)
	_expect(attack.phase == attack.Phase.RECOVERY, "reentry settles into a punish window")
	_expect(attack.get_volleys_fired() == volleys, "reentry does not fire")
	_expect(attack.dash_count == 1, "first dash completed")
	elite.stats_component.health = 100
	var hold := elite.global_position
	attack._process(1.21)
	_expect(attack.phase == attack.Phase.PULLBACK and not attack.use_spine, "second dash is the fountain dive")
	_expect(attack.dash_direction == Vector2.DOWN, "fountain dive ignores the player")
	_expect(elite.get_node("ChargeVisual").aiming and elite.get_node("ChargeVisual").locked, "fountain dive shows a fixed downward lane")
	attack._process(0.5)
	_expect(elite.global_position.is_equal_approx(hold + Vector2(0, -28)), "hull backs up 28px")
	attack._process(0.29)
	_expect(attack.phase == attack.Phase.PULLBACK, "wind-up lasts the full warning")
	attack._process(0.02)
	_expect(attack.phase == attack.Phase.DASH and attack.dash_direction == Vector2.DOWN, "fountain dive goes straight down")
	elite.move_component.velocity_multiplier = 1.2
	origin = elite.global_position
	direction = attack.dash_direction
	attack._process(0.1)
	_expect(elite.global_position.is_equal_approx(origin + direction * 38.4), "movement augment scales dash speed")
	# Exercise the other escape edges without depending on a particular viewport size.
	for escape_direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.UP]:
		elite.global_position = bounds.get_center()
		attack.phase = attack.Phase.DASH
		attack.dash_direction = escape_direction
		attack._process(5.0)
		_expect(attack.phase == attack.Phase.REENTRY_WARNING, "every escape edge returns to top")
	await process_frame
	var before_count := get_nodes_in_group("enemy_projectiles").size()
	elite.global_position = bounds.get_center()
	attack.phase = attack.Phase.DASH
	attack.dash_direction = Vector2.DOWN
	attack._shot_elapsed = 0.0
	attack.use_spine = false
	attack.shot_count = 3
	player.position = bounds.get_center() + Vector2(0, 120)
	attack.spread_degrees = 18.0
	attack.apply_action_rate_multiplier(10.0)
	attack._process(0.11)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == before_count + 6, "action-rate and volume augments apply to both fountain sides")
	before_count = get_nodes_in_group("enemy_projectiles").size()
	elite.global_position = bounds.get_center()
	attack.dash_direction = Vector2.DOWN
	attack._shot_elapsed = 0.0
	attack.use_spine = true
	attack.shot_count = 1
	attack.apply_action_rate_multiplier(1.0)
	attack._process(0.06)
	await process_frame
	var spines := get_nodes_in_group("enemy_projectiles").slice(before_count)
	_expect(spines.size() == 2, "spine dash drops one needle per side")
	if spines.size() == 2:
		var spine: FoundationBullet = spines[0]
		var state: BulletBehaviorState = spine.behavior_state
		_expect(absf(state.velocity_at(0.0).normalized().dot(Vector2.DOWN)) < 0.01, "spines point away from the path")
		_expect(is_equal_approx(state.velocity_at(0.0).length(), 30.0), "spines leave slowly")
		_expect(state.velocity_at(0.3).length() < 0.01 and state.velocity_at(1.1).length() < 0.01, "spines hold beside the path")
		_expect(absf(state.velocity_at(1.8).length() - 150.0) < 0.5, "spines burst outward")
		_expect(state.velocity_at(1.8).normalized().is_equal_approx(state.velocity_at(0.0).normalized()), "spines keep their side")
		_expect(is_equal_approx(spine.lifetime, 4.0), "spine lifetime")
		_expect(spine.appearance.collision_size == Vector2(6, 12), "spines use the 1.5x elite needle")
	attack.apply_action_rate_multiplier(10.0)
	attack._shot_elapsed = 0.0
	attack._process(0.05)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == before_count + 4, "action rate keeps the minimum spine interval")
	before_count = get_nodes_in_group("enemy_projectiles").size()
	elite.global_position = bounds.get_center()
	attack.dash_direction = Vector2.DOWN
	attack._shot_elapsed = 0.0
	attack.use_spine = false
	attack.shot_count = 1
	attack.apply_action_rate_multiplier(1.0)
	attack._process(0.15)
	await process_frame
	var lasers := get_nodes_in_group("enemy_projectiles").slice(before_count)
	_expect(lasers.size() == 2, "fountain emits one laser per side")
	if lasers.size() == 2:
		var tail_y: float = lasers[0]._origin.y
		_expect(tail_y < elite.global_position.y - 14.0 + 0.5, "lasers leave from the tail")
		var sides := 0.0
		for laser in lasers:
			var start: Vector2 = laser.behavior_state.velocity_at(0.0)
			var tilt := rad_to_deg(absf(Vector2.UP.angle_to(start)))
			_expect(tilt >= 15.0 and tilt <= 45.0, "lasers spray up within 15-45 degrees")
			sides += signf(start.x)
			_expect(laser.behavior_state.velocity_at(0.25).normalized().is_equal_approx(start.normalized()), "lasers rise before homing")
			_advance(laser, 1.6)
			var to_player: Vector2 = (player.global_position - laser.global_position).normalized()
			_expect(laser.get_travel_velocity().normalized().dot(to_player) > 0.8, "lasers curve toward the player")
			_expect(absf(laser.get_travel_velocity().length() - 190.0) < 1.0, "lasers speed up while homing")
		_expect(sides == 0.0, "fountain sprays to both sides")
	player.remove_from_group("player")
	attack.targeting_component.change_target(null)
	attack._begin_aim()
	_expect(attack.dash_direction == Vector2.DOWN, "missing target uses safe downward fallback")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("elite charge smoke test: PASS")
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
