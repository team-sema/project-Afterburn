extends SceneTree

## Shared Behavior samples and trajectories (combat.md 실행 상태 캐시): bullets
## that share one Behavior instance read one state per age and one local-frame
## path per launch speed. Runs the same scene with sharing
## on and off and compares every bullet every tick, while trajectory effects
## hit only some bullets of a ring. Also covers world-heading turn_to rings,
## homing, wall bounces and SPAWN children, and checks who shares a table.

const ROUND := preload("res://resources/projectiles/round.tres")
const TICKS := 100
const TOLERANCE := 0.0001
## Shared paths integrate in a local frame and rotate per bullet, so world
## positions differ from per-bullet integration by float rounding only.
const POSITION_TOLERANCE := 0.01

var failures: PackedStringArray = []
var _next_index := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	node_added.connect(_tag_bullet)
	BulletBehaviorState.share_samples = false
	var reference := await _record(false)
	BulletBehaviorState.share_samples = true
	var shared := await _record(true)
	_compare(reference, shared)
	if failures.is_empty():
		print("bullet_shared_sample_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("bullet_shared_sample_test: %s" % failure)
	quit(1)


func _tag_bullet(node: Node) -> void:
	if node is FoundationBullet:
		node.set_meta(&"test_index", _next_index)
		_next_index += 1


func _shot(behavior: BulletBehavior) -> BarrageShot:
	var shot := BarrageShot.new()
	shot.appearance = ROUND
	shot.behavior = behavior
	shot.lifetime = 8.0
	return shot


## Spawns the scene, applies the same interventions by spawn index, and returns
## {tick: {index: [position, tint, opacity, visual scale, hitbox scale, tangible]}}.
func _record(sharing: bool) -> Dictionary:
	_next_index = 0
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var target := Node2D.new()
	target.position = Vector2(320, 320)
	world.add_child(target)

	var lateral := BulletAction.make(BulletAction.Type.LATERAL_WAVE, 8.0, 0.5)
	lateral.period = 0.5
	var mixed := _shot(BulletBehavior.new().wait(0.2).parallel([
		BulletAction.turn_by(90, 0.6),
		BulletAction.tint_to(Color.CYAN, 0.6),
		BulletAction.make(BulletAction.Type.OPACITY, 0.4, 0.6),
		BulletAction.hitbox_scale_to(1.5, 0.6),
	]).speed_to(30, 0.3).then(lateral).intangible().wait(0.2).tangible())
	var turn_to := _shot(BulletBehavior.new().turn_to(45, 0.5).tint_to(Color.RED, 0.4))
	var homing := _shot(BulletBehavior.new().wait(0.2).homing(180, 1.0))
	var bounce := _shot(BulletBehavior.new().turn_by(60, 0.8))
	bounce.bounce_walls = BulletWallBounce.SIDES
	var child_volley := BarrageVolley.new()
	child_volley.shot = _shot(BulletBehavior.new().turn_by(-120, 0.6).opacity_to(0.5, 0.4))
	child_volley.layout = BarrageVolley.Layout.RING
	child_volley.count = 6
	child_volley.speed = 50
	var parent := _shot(BulletBehavior.new().wait(0.3).spawn(child_volley, true))

	var ring: Array[FoundationBullet] = []
	var turners: Array[FoundationBullet] = []
	for index in 12:
		var direction := Vector2.DOWN.rotated(TAU * index / 12.0)
		ring.append(mixed.spawn(world, Vector2(320, 180), direction, 80.0, false, null, Callable(), true))
		turners.append(turn_to.spawn(world, Vector2(160, 120), direction, 60.0, false, null, Callable(), true))
		homing.spawn(world, Vector2(480, 120), direction, 70.0, false, target, Callable(), true)
	for index in 6:
		bounce.spawn(world, Vector2(60 + index * 100, 200), Vector2.RIGHT.rotated(index * 0.4), 140.0, false, null, Callable(), true)
	for index in 3:
		parent.spawn(world, Vector2(200 + index * 120, 60), Vector2.DOWN, 60.0, false, target, Callable(), true)

	if sharing:
		_expect(is_same(ring[0].behavior_state._memo, ring[5].behavior_state._memo), "a ring on one Behavior shares one sample table")
		_expect(not is_same(turners[0].behavior_state._memo, turners[3].behavior_state._memo), "turn_to bullets key their table on the launch direction")
		_expect(ring[0].behavior_state._path != null and is_same(ring[0].behavior_state._path, ring[5].behavior_state._path), "a ring on one Behavior shares one trajectory")
		_expect(not is_same(turners[0].behavior_state._path, turners[3].behavior_state._path), "turn_to bullets key their trajectory on the launch direction")
		var homers := EnemyBullets.query_circle(world, Vector2(480, 120), 1.0)
		_expect(not homers.is_empty() and homers[0].behavior_state._memo == null, "homing bullets keep per-bullet samples")

	var frames := {}
	for tick in TICKS:
		if tick == 20:
			EnemyBullets.apply_effect(ring[0], &"slow", 0.35)
			EnemyBullets.apply_effect(ring[3], &"swirl", 1.0, 30.0, 0.5)
			EnemyBullets.apply_effect(ring[7], &"slow", 0.5, -20.0)
		if tick == 45:
			EnemyBullets.remove_effect(ring[0], &"slow")
		await physics_frame
		var frame := {}
		for node in get_nodes_in_group(EnemyBullets.GROUP):
			var bullet := node as FoundationBullet
			if bullet == null or bullet.is_queued_for_deletion() or not bullet.has_meta(&"test_index"):
				continue
			frame[bullet.get_meta(&"test_index")] = [bullet.global_position, bullet.render_tint, bullet.render_opacity, bullet.visual_scale, bullet.hitbox_scale, bullet.tangible]
		frames[tick] = frame
	world.queue_free()
	await process_frame
	return frames


func _compare(reference: Dictionary, shared: Dictionary) -> void:
	var compared := 0
	var worst := 0.0
	for tick in TICKS:
		var expected: Dictionary = reference[tick]
		var actual: Dictionary = shared[tick]
		if expected.size() != actual.size():
			failures.append("tick %d: %d bullets with sharing vs %d without" % [tick, actual.size(), expected.size()])
			return
		for index in expected:
			var a: Array = expected[index]
			var b: Array = actual.get(index, [])
			if b.is_empty():
				failures.append("tick %d: bullet %d missing with sharing" % [tick, index])
				return
			var drift := (a[0] as Vector2).distance_to(b[0])
			var tint_gap := absf((a[1] as Color).r - (b[1] as Color).r) + absf((a[1] as Color).g - (b[1] as Color).g) + absf((a[1] as Color).b - (b[1] as Color).b)
			if drift > POSITION_TOLERANCE or tint_gap > TOLERANCE or absf(a[2] - b[2]) > TOLERANCE or absf(a[3] - b[3]) > TOLERANCE or absf(a[4] - b[4]) > TOLERANCE or a[5] != b[5]:
				failures.append("tick %d bullet %d differs: %s vs %s" % [tick, index, a, b])
				return
			worst = maxf(worst, drift)
			compared += 1
	_expect(compared > 3000, "compared enough bullet samples (%d)" % compared)
	print("bullet_shared_sample_test: %d samples, worst position drift %.6f px" % [compared, worst])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
