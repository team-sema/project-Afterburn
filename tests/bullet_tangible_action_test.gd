extends SceneTree

## Ghost bullets (combat.md 무판정 구간): TANGIBLE validation, state carried
## through parallel groups and repeats, the real hitbox switching off and on,
## no hit while off, a hit when it turns on over the player, and intangible
## bullets staying cancellable.

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
	_test_state()
	await _test_hit_after_reactivation()
	await _test_intangible_cancel()
	_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("bullet_tangible_action_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("bullet_tangible_action_test: %s" % failure)
	quit(1)


func _shot(behavior: BulletBehavior, kind := BarrageShot.Kind.BULLET) -> BarrageShot:
	var shot := BarrageShot.new()
	shot.kind = kind
	shot.behavior = behavior
	shot.lifetime = 8.0
	if kind == BarrageShot.Kind.BULLET:
		shot.appearance = ROUND
	return shot


func _test_validation() -> void:
	_expect(BulletBehavior.new().intangible().wait(0.3).tangible().validation_error().is_empty(), "off/on toggles are valid")
	var half := BulletAction.make(BulletAction.Type.TANGIBLE, 0.5, 0)
	_expect(not half.validation_error().is_empty(), "values other than 0/1 are rejected")
	var timed := BulletAction.set_tangible(false)
	timed.duration = 0.2
	_expect(not timed.validation_error().is_empty(), "tangible must be instantaneous")
	var grouped := BulletBehavior.new().parallel([
		BulletAction.set_tangible(false),
		BulletAction.make(BulletAction.Type.OPACITY, 0.3, 0.2),
	])
	_expect(grouped.validation_error().is_empty(), "tangible may run inside a parallel group")
	_expect(grouped.has_tangible_toggle(), "parallel children count as a tangible toggle")
	_expect(_shot(BulletBehavior.new().intangible()).is_valid(), "BULLET shots accept tangible toggles")
	var laser := _shot(BulletBehavior.new().intangible(), BarrageShot.Kind.TRAIL_LASER)
	_expect(not laser.is_valid(), "TRAIL_LASER shots reject tangible toggles")
	_expect(_shot(BulletBehavior.new().wait(0.2), BarrageShot.Kind.TRAIL_LASER).is_valid(), "the same laser without the toggle is valid")


func _test_state() -> void:
	var behavior := BulletBehavior.new().wait(0.5).intangible().wait(0.5).tangible().wait(0.5)
	var runtime := BulletBehaviorState.new(behavior, Vector2.DOWN, 90.0, Color.WHITE, 8.0)
	_expect(runtime.sample(0.2).tangible, "tangible by default")
	_expect(not runtime.sample(0.5).tangible, "off exactly at the action time")
	_expect(not runtime.sample(0.9).tangible, "stays off through the wait")
	_expect(runtime.sample(1.0).tangible and runtime.sample(1.4).tangible, "back on after the second toggle")
	_expect(not runtime.has_static_visuals(), "a toggle disables the static-visual fast path")

	var looping := BulletBehaviorState.new(BulletBehavior.new().intangible().wait(0.3).tangible().wait(0.3).repeat(), Vector2.DOWN, 90.0, Color.WHITE, 8.0)
	_expect(not looping.sample(0.1).tangible and looping.sample(0.4).tangible, "first cycle toggles")
	_expect(not looping.sample(0.7).tangible and looping.sample(1.0).tangible, "repeated cycle toggles again")

	var grouped := BulletBehaviorState.new(BulletBehavior.new().parallel([
		BulletAction.set_tangible(false),
		BulletAction.make(BulletAction.Type.OPACITY, 0.3, 0.4),
	]), Vector2.DOWN, 90.0, Color.WHITE, 8.0)
	_expect(not grouped.sample(0.1).tangible, "parallel toggle applies at group start")
	_expect(not grouped.sample(2.0).tangible, "parallel toggle persists after the group")


func _make_player(at: Vector2) -> Array:
	var holder := Node2D.new()
	holder.global_position = at
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	hurtbox.add_child(shape)
	holder.add_child(hurtbox)
	_world.add_child(holder)
	var hits := [0]
	hurtbox.hurt.connect(func(_hitbox: Variant) -> void: hits[0] += 1)
	return [holder, hits]


func _physics_frames(count: int) -> void:
	for index in count:
		await physics_frame


func _test_hit_after_reactivation() -> void:
	var center := Vector2(200, 200)
	var player := _make_player(center)
	var hits: Array = player[1]
	var behavior := BulletBehavior.new().intangible().wait(0.3).tangible().wait(2.0)
	var bullet := _shot(behavior).spawn(_world, center, Vector2.DOWN, 0.0) as FoundationBullet
	_expect(bullet != null, "ghost bullet spawns")
	if bullet == null:
		return
	await _physics_frames(12) # 0.2 s at 60 Hz: overlapping the player but off.
	_expect(is_instance_valid(bullet), "an intangible bullet survives overlapping the player")
	_expect(hits[0] == 0, "an intangible bullet does not hit")
	if is_instance_valid(bullet):
		_expect(not bullet.tangible, "body reports the hitbox off")
		_expect((bullet._hitbox.get_child(0) as CollisionShape2D).disabled, "collision shape is disabled while off")
		_expect(EnemyBullets.query_circle(_world, center, 4.0).has(bullet), "query_circle still finds the ghost")
	await _physics_frames(12) # Past 0.3 s: switched on while still overlapping.
	_expect(hits[0] == 1, "turning on over the player hits once (got %d)" % hits[0])
	_expect(not is_instance_valid(bullet) or bullet.is_queued_for_deletion(), "the reactivated bullet is consumed by the hit")
	(player[0] as Node).queue_free()
	await process_frame


func _test_intangible_cancel() -> void:
	var bullet := _shot(BulletBehavior.new().intangible().wait(2.0)).spawn(_world, Vector2(300, 120), Vector2.DOWN, 0.0) as FoundationBullet
	await _physics_frames(2)
	_expect(is_instance_valid(bullet) and not bullet.tangible, "fixture bullet is intangible")
	_expect(EnemyBullets.get_all(_world).has(bullet), "intangible bullets stay in the enemy bullet group")
	_expect(EnemyBullets.cancel(_world, bullet, EnemyBullets.REASON_LAB), "intangible bullets can be cancelled")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
