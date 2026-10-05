extends SceneTree

## Bullet -> bullet SPAWN (combat.md 탄→탄 SPAWN): validation limits, the
## once-only schedule, heading-relative and aimed volleys, consume vs keep,
## stop-then-aim, and children counting as ordinary enemy bullets.

const ROUND := preload("res://resources/projectiles/round.tres")

var failures: PackedStringArray = []
var _world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = Node2D.new()
	_world.add_to_group("gameplay_world")
	root.add_child(_world)
	_test_validation()
	_test_schedule()
	await _test_split()
	await _test_heading_relative_keep()
	await _test_stop_then_aim()
	_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("bullet_spawn_action_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("bullet_spawn_action_test: %s" % failure)
	quit(1)


func _shot(behavior: BulletBehavior = null) -> BarrageShot:
	var shot := BarrageShot.new()
	shot.appearance = ROUND
	shot.behavior = behavior if behavior != null else BulletBehavior.new()
	shot.lifetime = 8.0
	return shot


func _volley(layout: BarrageVolley.Layout, count: int, speed := 60.0, shot: BarrageShot = null) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot if shot != null else _shot()
	volley.layout = layout
	volley.count = count
	volley.speed = speed
	return volley


func _test_validation() -> void:
	var ring := _volley(BarrageVolley.Layout.RING, 8)
	_expect(BulletBehavior.new().wait(0.5).spawn(ring, true).validation_error().is_empty(), "a split behavior is valid")

	var nested := _volley(BarrageVolley.Layout.SINGLE, 1, 60.0, _shot(BulletBehavior.new().spawn(ring)))
	_expect(not BulletBehavior.new().spawn(nested).validation_error().is_empty(), "spawned bullets cannot spawn again")

	var self_ref := BulletBehavior.new()
	var loop_volley := _volley(BarrageVolley.Layout.SINGLE, 1, 60.0, _shot(self_ref))
	self_ref.spawn(loop_volley)
	_expect(not self_ref.validation_error().is_empty(), "a self-referencing spawn is rejected without recursing")

	var huge := _volley(BarrageVolley.Layout.RING, BulletAction.SPAWN_MAX_COUNT + 1)
	_expect(not BulletBehavior.new().spawn(huge).validation_error().is_empty(), "a spawn volley over 32 bullets is rejected")
	_expect(
		BulletBehavior.new().spawn(_volley(BarrageVolley.Layout.RING, BulletAction.SPAWN_MAX_COUNT)).validation_error().is_empty(),
		"a 32-bullet spawn volley is allowed",
	)

	var locked := _volley(BarrageVolley.Layout.SINGLE, 1)
	locked.aim = BarrageVolley.Aim.LOCKED
	_expect(not BulletBehavior.new().spawn(locked).validation_error().is_empty(), "LOCKED aim is rejected for spawns")

	var timed := BulletAction.spawn(ring)
	timed.duration = 0.5
	_expect(not timed.validation_error().is_empty(), "spawn must be instantaneous")

	var five := BulletBehavior.new()
	for _i in BulletAction.SPAWN_MAX_PER_BULLET + 1:
		five.wait(0.1).spawn(ring)
	_expect(not five.validation_error().is_empty(), "more than four spawn actions are rejected")

	var grouped: Array[BulletAction] = [BulletAction.spawn(ring)]
	_expect(not BulletBehavior.new().parallel(grouped).validation_error().is_empty(), "spawn inside parallel is rejected")

	var laser := _shot(BulletBehavior.new().spawn(ring))
	laser.kind = BarrageShot.Kind.TRAIL_LASER
	_expect(not laser.is_valid(), "laser bodies cannot carry spawn actions")
	_expect(not BulletBehavior.new().spawn(null).validation_error().is_empty(), "a spawn needs a payload")


func _test_schedule() -> void:
	var ring := _volley(BarrageVolley.Layout.RING, 4)
	var state := BulletBehaviorState.new(BulletBehavior.new().wait(0.5).spawn(ring).wait(0.5).spawn(ring), Vector2.DOWN, 100.0, Color.WHITE, 8.0)
	state.position_at(3.0)
	state.sample(2.0)
	_expect(state.take_due_spawns(0.4).is_empty(), "nothing is due before the spawn time, even after future queries")
	var first := state.take_due_spawns(0.6)
	_expect(first.size() == 1 and is_equal_approx(float(first[0].time), 0.5), "the first spawn comes due at 0.5s")
	_expect(state.take_due_spawns(0.6).is_empty(), "a spawn fires only once")
	var second := state.take_due_spawns(5.0)
	_expect(second.size() == 1 and is_equal_approx(float(second[0].time), 1.0), "the second spawn comes due at 1.0s")

	# 4-bullet ring every 0.05s for 8s would be 640 bullets; the 128 budget allows 32 rings.
	var looping := BulletBehaviorState.new(BulletBehavior.new().wait(0.05).spawn(ring).repeat(0), Vector2.DOWN, 100.0, Color.WHITE, 8.0)
	var taken := looping.take_due_spawns(3.0)
	_expect(taken.size() == 32, "a repeating spawn stops once 128 children are spent (%d rings)" % taken.size())
	_expect(looping.take_due_spawns(8.0).is_empty(), "a spent budget never spawns again")
	var eight := _volley(BarrageVolley.Layout.RING, 30)
	var overrun := BulletBehaviorState.new(BulletBehavior.new().wait(0.1).spawn(eight).repeat(0), Vector2.DOWN, 100.0, Color.WHITE, 8.0)
	_expect(overrun.take_due_spawns(8.0).size() == 4, "a volley that would overrun the budget is not fired (4 x 30 = 120)")

	var stopped := BulletBehaviorState.new(BulletBehavior.new().speed_to(0.0, 0.2), Vector2.RIGHT, 100.0, Color.WHITE, 8.0)
	_near(stopped.heading_at(1.0), Vector2.RIGHT, "a stopped bullet keeps its heading")


func _test_split() -> void:
	var ring := _volley(BarrageVolley.Layout.RING, 8, 60.0)
	var parent := _shot(BulletBehavior.new().wait(0.5).spawn(ring, true)).spawn(_world, Vector2(150, 100), Vector2.DOWN, 100.0) as FoundationBullet
	_expect(parent != null, "the parent bullet spawns")
	var split_point := Vector2(150, 150)
	var before := _bullets()
	await _physics_seconds(0.55)
	_expect(not is_instance_valid(parent) or parent.is_queued_for_deletion(), "a consuming spawn removes the parent")
	var children := _bullets().filter(func(node: Node) -> bool: return not before.has(node))
	_expect(children.size() == 8, "the ring spawns 8 children (%d)" % children.size())
	var headings: Array[float] = []
	for child in children:
		var bullet := child as FoundationBullet
		_expect(bullet.global_position.distance_to(split_point) < 6.0, "children start at the split point (%s)" % str(bullet.global_position))
		headings.append(rad_to_deg(Vector2.DOWN.angle_to(bullet.get_travel_velocity())))
		_expect(bullet.is_in_group(EnemyBullets.GROUP), "children are ordinary enemy bullets (clear XP applies)")
	headings.sort()
	_expect(headings.size() == 8 and absf(headings[1] - headings[0] - 45.0) < 1.0, "the ring spreads 45 degrees apart")
	for child in children:
		child.queue_free()
	await process_frame


func _test_heading_relative_keep() -> void:
	var single := _volley(BarrageVolley.Layout.SINGLE, 1, 80.0)
	single.angle_degrees = 90.0
	var parent := _shot(BulletBehavior.new().wait(0.3).spawn(single)).spawn(_world, Vector2(60, 200), Vector2.RIGHT, 100.0) as FoundationBullet
	var before := _bullets()
	await _physics_seconds(0.4)
	_expect(is_instance_valid(parent) and not parent.is_queued_for_deletion(), "a non-consuming spawn keeps the parent flying")
	var children := _bullets().filter(func(node: Node) -> bool: return not before.has(node))
	_expect(children.size() == 1, "one child is fired")
	if children.size() == 1:
		# Heading RIGHT rotated +90 degrees (Godot 2D) points DOWN.
		_near((children[0] as FoundationBullet).get_travel_velocity().normalized(), Vector2.DOWN, "volley angles are relative to the parent heading")
	for node in children + [parent]:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame


func _test_stop_then_aim() -> void:
	var target := Node2D.new()
	_world.add_child(target)
	target.global_position = Vector2(250, 250)
	var aimed := _volley(BarrageVolley.Layout.SINGLE, 1, 90.0)
	aimed.aim = BarrageVolley.Aim.EACH_SHOT
	var behavior := BulletBehavior.new().speed_to(0.0, 0.2).wait(0.2).spawn(aimed, true)
	var parent := _shot(behavior).spawn(_world, Vector2(100, 100), Vector2.DOWN, 100.0, false, target) as FoundationBullet
	var before := _bullets()
	await _physics_seconds(0.5)
	var children := _bullets().filter(func(node: Node) -> bool: return not before.has(node))
	_expect(children.size() == 1, "the stopped bullet fires one aimed child")
	if children.size() == 1:
		var child := children[0] as FoundationBullet
		var to_target := child.global_position.direction_to(target.global_position)
		_expect(child.get_travel_velocity().normalized().dot(to_target) > 0.99, "the child aims at the target")
	_expect(not is_instance_valid(parent) or parent.is_queued_for_deletion(), "the aimed split consumed the parent")

	# Without a target the aimed volley is skipped, like a targetless aimed fire.
	var lonely := _shot(BulletBehavior.new().wait(0.1).spawn(aimed)).spawn(_world, Vector2(40, 40), Vector2.DOWN, 50.0) as FoundationBullet
	before = _bullets()
	await _physics_seconds(0.2)
	_expect(_bullets().filter(func(node: Node) -> bool: return not before.has(node)).is_empty(), "no target means no aimed child")
	for node in children + [lonely, target]:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame


func _bullets() -> Array[Node]:
	return get_nodes_in_group(EnemyBullets.GROUP)


func _physics_seconds(seconds: float) -> void:
	var frames := ceili(seconds * Engine.physics_ticks_per_second)
	for _i in frames:
		await physics_frame


func _near(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.distance_to(expected) < 0.01, "%s (got %s, want %s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
