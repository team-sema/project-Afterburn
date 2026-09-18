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
	_expect(bullets.size() == 2, "dash emits one pair")
	if bullets.size() == 2:
		var a: Vector2 = bullets[0].get_threat_velocity()
		var b: Vector2 = bullets[1].get_threat_velocity()
		_expect(absf(a.normalized().dot(direction)) < 0.25 and absf(b.normalized().dot(direction)) < 0.25, "flames stay close to perpendicular")
		_expect(a.dot(direction.orthogonal()) * b.dot(direction.orthogonal()) < 0.0, "flames spread to opposite sides")
		_expect(a.length() >= 90.0 and a.length() <= 110.0, "flame speed stays bounded")
		bullets[0]._physics_process(0.91)
		_expect(bullets[0].is_queued_for_deletion(), "flame hazard expires instead of crossing the whole screen")
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
	elite.stats_component.health = 100
	attack._process(1.21)
	attack._process(0.81)
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
	attack.shot_count = 3
	attack.spread_degrees = 18.0
	attack.apply_action_rate_multiplier(10.0)
	attack._process(0.11)
	await process_frame
	_expect(get_nodes_in_group("enemy_projectiles").size() == before_count + 6, "action-rate and volume augments apply to both sides")
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
