extends SceneTree

## Wall bounce (combat.md 벽 반사): exact folding of a straight path, bounce
## budget and pass-through, entering from outside, velocity reflection, live
## bullets and trail lasers staying inside, prediction and effects.

const ROUND := preload("res://resources/projectiles/round.tres")
const RECT := Rect2(0, 0, 200, 400)

var failures: PackedStringArray = []
var _world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = Node2D.new()
	_world.add_to_group("gameplay_world")
	root.add_child(_world)
	_test_validation()
	_test_folding()
	await _test_live_bullet()
	await _test_trail_laser()
	_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("bullet_wall_bounce_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("bullet_wall_bounce_test: %s" % failure)
	quit(1)


func _shot(walls: int, count := 1) -> BarrageShot:
	var shot := BarrageShot.new()
	shot.appearance = ROUND
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 8.0
	shot.bounce_walls = walls
	shot.bounce_count = count
	return shot


func _test_validation() -> void:
	_expect(_shot(BulletWallBounce.SIDES).is_valid(), "a side-bouncing bullet is valid")
	_expect(_shot(BulletWallBounce.ALL, 0).is_valid(), "unlimited four-wall bounces are valid")
	var homing := _shot(BulletWallBounce.SIDES)
	homing.behavior = BulletBehavior.new().homing(90.0, 2.0)
	_expect(not homing.is_valid(), "homing cannot be mixed with bounces")
	var beam := BarrageShot.new()
	beam.kind = BarrageShot.Kind.BEAM
	beam.behavior = null
	beam.bounce_walls = BulletWallBounce.SIDES
	_expect(not beam.is_valid(), "beams do not bounce")
	_expect(not _shot(BulletWallBounce.SIDES, 65).is_valid(), "bounce count is capped at 64")
	_expect(not _shot(16).is_valid(), "unknown wall flags are rejected")


func _straight(start: Vector2, velocity: Vector2) -> Callable:
	return func(time: float) -> Vector2: return start + velocity * time


func _test_folding() -> void:
	var once := BulletWallBounce.new(_straight(Vector2(50, 100), Vector2(100, 0)), RECT, 0.0, BulletWallBounce.SIDES, 1, 10.0)
	_near(once.position_at(1.0), Vector2(150, 100), "before the wall the path is untouched")
	_near(once.position_at(2.0), Vector2(150, 100), "the right wall mirrors the path back")
	_near(once.reflect_vector(2.0, Vector2(100, 0)), Vector2(-100, 0), "velocity reflects after the bounce")
	_near(once.position_at(4.0), Vector2(-50, 100), "a spent budget lets the bullet pass the far wall")
	_expect(once.bounces_until(4.0) == 1, "one bounce is counted")
	_expect(once.handedness(2.0) == -1.0, "one mirror flips turning direction")

	var unlimited := BulletWallBounce.new(_straight(Vector2(50, 100), Vector2(100, 0)), RECT, 0.0, BulletWallBounce.SIDES, 0, 10.0)
	_near(unlimited.position_at(4.0), Vector2(50, 100), "unlimited bounces fold off both walls")
	_expect(unlimited.bounces_until(4.0) == 2, "both bounces are counted")
	_near(unlimited.position_at(1.0), Vector2(150, 100), "querying the future does not change the past")

	var padded := BulletWallBounce.new(_straight(Vector2(50, 100), Vector2(100, 0)), RECT, 10.0, BulletWallBounce.SIDES, 1, 10.0)
	_near(padded.position_at(2.0), Vector2(130, 100), "the radius keeps the bullet edge on the wall")

	var vertical := BulletWallBounce.new(_straight(Vector2(50, 100), Vector2(0, 100)), RECT, 0.0, BulletWallBounce.SIDES, 1, 10.0)
	_near(vertical.position_at(4.0), Vector2(50, 500), "disabled walls let the bullet leave")

	var entering := BulletWallBounce.new(_straight(Vector2(-50, 100), Vector2(100, 0)), RECT, 0.0, BulletWallBounce.SIDES, 1, 10.0)
	_near(entering.position_at(1.0), Vector2(50, 100), "a bullet fired from outside enters without bouncing")
	_near(entering.position_at(3.0), Vector2(150, 100), "and then bounces off the far wall")


func _test_live_bullet() -> void:
	var bounds := root.get_visible_rect()
	var radius := ROUND.bounding_radius()
	var bullet := _shot(BulletWallBounce.SIDES, 1).spawn(_world, Vector2(radius + 20, 100), Vector2(-1, 1).normalized(), 200.0) as FoundationBullet
	_expect(bullet != null, "a bouncing bullet spawns")
	if bullet == null:
		return
	var path := bullet.get_predicted_path(0.5)
	var min_x := INF
	for point in path:
		min_x = minf(min_x, point.x)
	_expect(min_x >= bounds.position.x + radius - 0.5, "the predicted path already bounces (min x %.1f)" % min_x)
	for _i in 30:
		await physics_frame
		_expect(bullet.global_position.x >= bounds.position.x + radius - 0.5, "the bullet stays inside the left wall")
	_expect(bullet.get_bounce_count() == 1, "the bullet bounced once")
	_expect(bullet.get_travel_velocity().x > 0.0, "it now travels right")
	var before := bullet.global_position
	_expect(EnemyBullets.apply_effect(bullet, &"slow", 0.5), "effects still apply to a bounced bullet")
	_near(bullet.world_position_at(bullet.age), before, "an effect keeps the bullet where it is")
	await physics_frame
	_expect(bullet.get_travel_velocity().x > 0.0, "a slowed bounced bullet keeps its reflected heading")
	bullet.queue_free()
	await process_frame


func _test_trail_laser() -> void:
	var bounds := root.get_visible_rect()
	var shot := BarrageShot.new()
	shot.kind = BarrageShot.Kind.TRAIL_LASER
	shot.behavior = BulletBehavior.new()
	shot.trail_duration = 0.6
	shot.lifetime = 4.0
	shot.bounce_walls = BulletWallBounce.SIDES
	var laser := shot.spawn(_world, Vector2(40, 120), Vector2(-1, 1).normalized(), 180.0) as CurvedLaser
	_expect(laser != null, "a bouncing trail laser spawns")
	if laser == null:
		return
	for _i in 30:
		await physics_frame
	_expect(laser.get_bounce_count() == 1, "the laser head bounced")
	var min_x := INF
	for point in laser.body_at(laser.age):
		min_x = minf(min_x, point.x)
	_expect(min_x >= bounds.position.x + shot.hit_width * 0.5 - 0.5, "the laser body folds at the wall (min x %.1f)" % min_x)
	laser.queue_free()
	await process_frame


func _near(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.distance_to(expected) < 0.05, "%s (got %s, want %s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
