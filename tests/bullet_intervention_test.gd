extends SceneTree

## External trajectory effects (combat.md 외부 궤도 개입): stacking, expiry,
## replacement, removal, position continuity, unchanged history, per-bullet
## isolation, pause, and real FoundationBullet / CurvedLaser bodies.

const ROUND := preload("res://resources/projectiles/round.tres")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_state_rules()
	_test_expiry_and_continuity()
	await _test_live_bullets()
	if failures.is_empty():
		print("bullet_intervention_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("bullet_intervention_test: %s" % failure)
	quit(1)


func _straight(speed := 100.0) -> BulletBehaviorState:
	return BulletBehaviorState.new(BulletBehavior.new(), Vector2.DOWN, speed, Color.WHITE, 10.0)


func _test_state_rules() -> void:
	var state := _straight()
	var other := _straight()
	state.advance_to(1.0)
	other.advance_to(1.0)
	var before_now := state.position_at(1.0)
	var before_past := state.position_at(0.5)
	_expect(state.apply_effect(&"slow", 0.5), "a valid effect registers")
	_near(state.position_at(1.0), before_now, "position at the moment of intervention is continuous")
	_near(state.position_at(0.5), before_past, "past positions do not change")
	_near(state.position_at(2.0), Vector2(0, 150), "speed x0.5 halves travel afterwards")
	_near(state.velocity_at(1.5), Vector2(0, 50), "velocity reflects the multiplier")
	_near(other.position_at(2.0), Vector2(0, 200), "another bullet is unaffected")

	state.apply_effect(&"slow_b", 0.5)
	_near(state.position_at(2.0), Vector2(0, 125), "speed multipliers multiply across handles")
	state.apply_effect(&"slow_b", 1.0, 90.0)
	# DOWN rotated +90° (Godot 2D rotation) points to -X.
	_near(state.position_at(2.0), Vector2(-50, 100), "re-registering a handle replaces it; heading offsets rotate travel")
	state.apply_effect(&"tilt", 1.0, -30.0)
	_near(
		state.velocity_at(1.5),
		Vector2.DOWN.rotated(deg_to_rad(60.0)) * 50.0,
		"heading offsets add across handles",
	)
	state.remove_effect(&"slow")
	state.remove_effect(&"slow_b")
	state.remove_effect(&"tilt")
	_near(state.position_at(2.0), Vector2(0, 200), "removing every effect resumes base travel from the current spot")
	_expect(not state.remove_effect(&"slow"), "removing an absent handle is a no-op")
	_expect(not state.apply_effect(&""), "an empty handle is rejected")
	_expect(not state.apply_effect(&"bad", -1.0), "a negative speed multiplier is rejected")


func _test_expiry_and_continuity() -> void:
	var state := _straight()
	state.advance_to(1.0)
	state.apply_effect(&"stun", 0.0, 0.0, 0.5)
	_near(state.position_at(1.5), Vector2(0, 100), "a zero multiplier holds the bullet still")
	_near(state.position_at(2.5), Vector2(0, 200), "the known expiry is already in the prediction")
	_expect(not state.get_effect(&"stun").is_empty(), "the effect is active before expiry")
	state.advance_to(1.2)
	var at_1_1 := state.position_at(1.1)
	var at_1_2 := state.position_at(1.2)
	state.apply_effect(&"drift", 1.0, 90.0, 0.3)
	_near(state.position_at(1.2), at_1_2, "a second change is continuous too")
	_near(state.position_at(1.1), at_1_1, "history before the second change is kept")
	state.advance_to(2.0)
	_expect(state.get_effect(&"stun").is_empty(), "the effect is gone after its duration")

	# Curving base behaviour: continuity and history with a turning bullet.
	var turning := BulletBehaviorState.new(
		BulletBehavior.new().turn_at(90.0, 3.0), Vector2.DOWN, 80.0, Color.WHITE, 10.0
	)
	turning.advance_to(0.7)
	var turn_now := turning.position_at(0.7)
	var turn_past := turning.position_at(0.3)
	turning.apply_effect(&"slow", 0.5, 20.0)
	_near(turning.position_at(0.7), turn_now, "a turning bullet stays continuous")
	_near(turning.position_at(0.3), turn_past, "a turning bullet keeps its history")


func _test_live_bullets() -> void:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var shot := BarrageShot.new()
	shot.appearance = ROUND
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 10.0
	var bullet := shot.spawn(world, Vector2(100, 40), Vector2.DOWN, 100.0)
	var laser_shot := BarrageShot.new()
	laser_shot.kind = BarrageShot.Kind.TRAIL_LASER
	laser_shot.behavior = BulletBehavior.new()
	laser_shot.trail_duration = 1.0
	laser_shot.lifetime = 10.0
	var laser := laser_shot.spawn(world, Vector2(200, 40), Vector2.DOWN, 60.0) as CurvedLaser
	var legacy := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(legacy)
	for _i in 30:
		await physics_frame

	_expect(not EnemyBullets.apply_effect(legacy, &"slow", 0.5), "the legacy body does not support effects")
	_expect(EnemyBullets.apply_effect(bullet, &"slow", 0.25, 0.0, 1.0), "EnemyBullets applies an effect to a bullet")
	var start := bullet.global_position
	var predicted := (bullet as FoundationBullet).get_predicted_path(0.5)
	for _i in 30:
		await physics_frame
	_expect(
		predicted.size() > 1 and bullet.global_position.distance_to(predicted[-1]) < 0.5,
		"path prediction made after the intervention matches the real movement",
	)
	var moved := bullet.global_position.y - start.y
	_expect(absf(moved - 12.5) < 1.5, "the live bullet moves at 25 px/s under x0.25 (moved %.2f)" % moved)
	_expect(absf((bullet as FoundationBullet).get_travel_velocity().length() - 25.0) < 0.5, "travel velocity reports the slowed speed")

	paused = true
	var paused_at := bullet.global_position
	await create_timer(0.6).timeout
	paused = false
	_expect(bullet.global_position.is_equal_approx(paused_at), "pause freezes the slowed bullet")
	_expect(not EnemyBullets.get_effect(bullet, &"slow").is_empty(), "pause does not spend the effect duration")

	var old_age := laser.age - 0.2
	var old_point := laser.position_at(old_age)
	var head := laser.global_position
	_expect(EnemyBullets.apply_effect(laser, &"bend", 1.0, 90.0), "EnemyBullets applies an effect to a laser")
	for _i in 18:
		await physics_frame
	_near(laser.position_at(old_age), old_point, "the laser tail already drawn keeps its path")
	_expect(laser.global_position.x < head.x - 10.0, "the laser head turns with the heading offset")
	_expect(EnemyBullets.remove_effect(laser, &"bend"), "EnemyBullets removes an effect")

	world.queue_free()
	await process_frame


func _near(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.distance_to(expected) < 0.05, "%s (got %s, want %s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
