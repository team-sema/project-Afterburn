extends SceneTree

const Reference = preload("res://tests/fixtures/behavior_reference.gd")
var failures: Array[String] = []
var comparisons := 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok and failures.size() < 20: failures.append(message)

func compare_behavior(behavior: BulletBehavior, label: String) -> void:
	var cached := BulletBehaviorState.new(behavior, Vector2(0.6, 0.8), 90, Color.CYAN, 30)
	var reference = Reference.new(behavior, Vector2(0.6, 0.8), 90, Color.CYAN, 31)
	var times: Array[float] = [0, 0.1, 0.3, 0.5, 1, 1.2, 2.4, 3.9, 8, 29.999, 30]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3918
	for i in 200: times.append(rng.randf_range(0, 30))
	# Query far into the future first, then interleave old and new samples.
	cached.position_at(30)
	for time in times:
		var actual := cached.sample(time)
		# The old subtract-from-time loop can land infinitesimally before an
		# exact decimal boundary. Compare its right-hand limit, matching the
		# contract that the next/instant Action runs at the boundary itself.
		var expected: Dictionary = reference.sample(time + 1.0e-9)
		for key in expected:
			if expected[key] is Color:
				expect(actual[key].is_equal_approx(expected[key]), label + " color at " + str(time))
			else:
				expect(absf(actual[key] - expected[key]) < 0.00001, label + " " + key + " at " + str(time))
		expect(cached.position_at(time).distance_to(reference.position_at(time)) < 0.001, label + " position at " + str(time))
		expect(cached.velocity_at(time).distance_to(reference.velocity_at(time + 1.0e-9)) < 0.001, label + " velocity at " + str(time))
		comparisons += 1
	# Returned dictionaries cannot mutate a stored checkpoint.
	var detached := cached.sample(0.1)
	detached.speed = 123456
	expect(cached.sample(0.1).speed != 123456, label + " sample isolation")
	expect(cached.playback_time == 0, label + " prediction does not advance playback")
	cached.advance_to(1.234)
	var past := cached.position_at(1.234)
	var future := cached.position_at(12.345)
	cached.invalidate_prediction()
	expect(cached.cached_until == cached.playback_time, label + " future horizon resets")
	expect(cached.position_at(1.234) == past, label + " committed boundary preserved")
	expect(cached.position_at(12.345) == future, label + " future regenerated deterministically")
	cached.advance_to(0.5)
	expect(cached.playback_time == 1.234, label + " history cannot rewind playback")
	for i in 2300: cached.position_at(i / 100.0)
	expect(cached._position_queries.size() <= BulletBehaviorState.QUERY_CACHE_LIMIT, label + " query cache bounded")
	var segments := cached._starts.size()
	for i in 100: cached.sample(29.99 - i / 10.0)
	expect(cached._starts.size() == segments, label + " old actions are not accumulated twice")

func run() -> void:
	var boundary := BulletBehaviorState.new(BulletBehavior.new().wait(0.3).wait(0.2).turn_by(90, 0).wait(0.5).repeat(), Vector2.DOWN, 90, Color.WHITE, 8)
	expect(boundary.sample(0.5).heading == 90 and boundary.sample(1.5).heading == 180, "instant action applies at exact decimal/repeat boundary")
	expect(boundary.sample(0.5 - 0.000001).heading == 0, "instant action does not apply before boundary")
	compare_behavior(BulletBehavior.new(), "straight")
	compare_behavior(BulletBehavior.new().turn_by(90, 0).wait(0.3).speed_to(0, 0).wait(0.2).speed_to(90, 0).turn_by(13, 0.5).repeat(), "instant/repeat")
	compare_behavior(BulletBehavior.new().turn_to(170, 0.3).turn_at(-80, 0.2).turn_by(22, 0.7).repeat(3), "finite heading")
	compare_behavior(BulletBehavior.new().heading_wave(35, 2.4).wait(0.5).speed_to(1.5, 1).repeat(), "previous mixed pattern")
	compare_behavior(BulletBehavior.new().lateral_wave(15, 0.4, 0.3).wait(0.1).parallel([
		BulletAction.turn_by(35, 0.5), BulletAction.make(BulletAction.Type.SPEED, 30, 0.3),
		BulletAction.tint_to(Color.RED, 0.2), BulletAction.visual_scale_to(2, 0.4),
		BulletAction.hitbox_scale_to(3, 0.1), BulletAction.make(BulletAction.Type.OPACITY, 0.2, 0),
	]).repeat(), "parallel channels/lateral")
	compare_behavior(BulletBehavior.new().turn_by(5, 0).speed_to(50, 0).repeat(3), "zero-duration finite")
	var pattern = load("res://patterns/mixed_sixteen_pattern.gd").new()
	compare_behavior(pattern.steps[0].get_volleys()[1].shot.behavior, "current user pattern")
	var repeated := BulletBehavior.new().heading_wave(35, 2.4).wait(0.5).speed_to(1.5, 1).repeat()
	var cached := BulletBehaviorState.new(repeated, Vector2.DOWN, 90, Color.WHITE, 30)
	var reference = Reference.new(repeated, Vector2.DOWN, 90, Color.WHITE, 30)
	cached.sample(30)
	for age in [0.5, 6.0, 24.0]:
		var start := Time.get_ticks_usec()
		for i in 1000: reference.sample(age + i / 100000.0)
		var old_usec := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for i in 1000: cached.sample(age + i / 100000.0)
		print("CACHE_AGE_BENCHMARK age=", age, " reference_us_per_query=", old_usec / 1000.0, " cached_us_per_query=", (Time.get_ticks_usec() - start) / 1000.0)
	if failures.is_empty(): print("behavior cache smoke test: PASS comparisons=", comparisons)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
