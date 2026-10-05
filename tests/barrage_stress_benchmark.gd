extends SceneTree
## Live-fire stress benchmark: BarragePlayers run real game patterns at a
## moving target with physics, off-screen despawn and rendering all active,
## unlike the pose-only render benchmark. Run with a rendered window:
##   tools/run-godot.cmd --rendering-method gl_compatibility --script res://tests/barrage_stress_benchmark.gd
## Frame intervals include presentation/waits; physics_ms is the 60 Hz tick
## cost that must stay well under 16.7 ms.

const WARMUP_SECONDS := 3.0
const MEASURE_SECONDS := 8.0

var results := []


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This benchmark requires a rendered window; omit --headless.")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _scenario("heavy_mixed", [
		{"seq": _caster({"rest": 4.2}), "pos": Vector2(200, 70)},
		{"seq": _caster({"rest": 4.8, "spin": -7.0}), "pos": Vector2(440, 70)},
		{"seq": _aimed_fan({"ways": 5, "shots": 3, "rest": 2.4, "speed": 90.0}), "pos": Vector2(120, 50)},
		{"seq": _aimed_fan({"ways": 7, "spread": 30.0, "shots": 2, "rest": 2.0}), "pos": Vector2(520, 50)},
		{"seq": _pattern("res://patterns/showcase/wave_curtain_pattern.gd"), "pos": Vector2(320, 30)},
	])
	await _scenario("laser_mixed", [
		{"seq": _pattern("res://patterns/showcase/laser_whirl_pattern.gd"), "pos": Vector2(240, 90)},
		{"seq": _pattern("res://patterns/showcase/laser_whirl_pattern.gd"), "pos": Vector2(400, 90)},
		{"seq": _caster({"rest": 4.8}), "pos": Vector2(320, 50)},
	])
	await _scenario("spawn_trails", [
		{"seq": _pattern("res://patterns/showcase/comet_trail_pattern.gd"), "pos": Vector2(250, 60)},
		{"seq": _pattern("res://patterns/showcase/comet_trail_pattern.gd"), "pos": Vector2(390, 60)},
		{"seq": _aimed_fan({"ways": 5, "shots": 3, "rest": 2.4}), "pos": Vector2(320, 40)},
	])
	await _scenario("extreme_mixed", [
		{"seq": _caster({"rest": 3.6}), "pos": Vector2(160, 70)},
		{"seq": _caster({"rest": 4.2, "spin": -7.0}), "pos": Vector2(480, 70)},
		{"seq": _pattern("res://patterns/showcase/wave_curtain_pattern.gd"), "pos": Vector2(320, 30)},
		{"seq": _pattern("res://patterns/showcase/laser_whirl_pattern.gd"), "pos": Vector2(320, 100)},
		{"seq": _pattern("res://patterns/showcase/comet_trail_pattern.gd"), "pos": Vector2(320, 60)},
		{"seq": _aimed_fan({"ways": 7, "spread": 30.0, "shots": 3, "rest": 1.8}), "pos": Vector2(90, 50)},
		{"seq": _aimed_fan({"ways": 7, "spread": 30.0, "shots": 3, "rest": 1.8}), "pos": Vector2(550, 50)},
		{"seq": _spike_burst(), "pos": Vector2(320, 80)},
	])
	FileAccess.open("res://artifacts/barrage_stress_benchmark.json", FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	print("barrage stress benchmark: COMPLETE")
	quit()


func _scenario(scenario_name: String, emitters: Array) -> void:
	var world := Node2D.new()
	root.add_child(world)
	var target := Node2D.new()
	world.add_child(target)
	target.position = Vector2(320, 290)
	var resolver := func() -> Node2D: return target
	for spec in emitters:
		var emitter := Node2D.new()
		emitter.position = spec.pos
		world.add_child(emitter)
		var player := BarragePlayer.new()
		player.resolve_target = resolver
		world.add_child(player)
		if not player.play(spec.seq, emitter, world):
			push_error("%s: %s" % [scenario_name, player.last_error])
			quit(1)
			return
	var intervals := PackedFloat64Array()
	var physics := PackedFloat64Array()
	var process := PackedFloat64Array()
	var counts := PackedInt32Array()
	var draws := PackedInt32Array()
	var start := Time.get_ticks_usec()
	var previous := start
	var clock := 0.0
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - start) / 1000000.0
		clock += (now - previous) / 1000000.0
		target.position = Vector2(320, 290) + Vector2(sin(clock * TAU / 1.7) * 240.0, sin(clock * TAU / 1.1) * 40.0)
		if elapsed > WARMUP_SECONDS:
			intervals.append((now - previous) / 1000.0)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			counts.append(get_node_count_in_group(&"enemy_projectiles"))
			draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		previous = now
		if elapsed >= WARMUP_SECONDS + MEASURE_SECONDS:
			break
	intervals.sort()
	physics.sort()
	process.sort()
	counts.sort()
	draws.sort()
	var result := {
		"scenario": scenario_name,
		"frames": intervals.size(),
		"frame_ms": _round3(_percentile(intervals, 0.5)),
		"frame_p95_ms": _round3(_percentile(intervals, 0.95)),
		"frame_max_ms": _round3(intervals[-1]),
		"physics_ms": _round3(_percentile(physics, 0.5)),
		"physics_p95_ms": _round3(_percentile(physics, 0.95)),
		"physics_max_ms": _round3(physics[-1]),
		"process_ms": _round3(_percentile(process, 0.5)),
		"bullets_min": counts[0],
		"bullets_median": counts[counts.size() / 2],
		"bullets_max": counts[-1],
		"draw_calls": draws[draws.size() / 2],
	}
	results.append(result)
	print(JSON.stringify(result))
	world.queue_free()
	await process_frame
	await process_frame


func _percentile(sorted_values: PackedFloat64Array, fraction: float) -> float:
	return sorted_values[int((sorted_values.size() - 1) * fraction)]


func _round3(value: float) -> float:
	return snappedf(value, 0.001)


func _pattern(path: String) -> BarrageSequence:
	return load(path).new() as BarrageSequence


func _caster(params: Dictionary) -> BarrageSequence:
	var sequence := load("res://patterns/caster_pattern.gd").new() as BarrageSequence
	sequence.build(params)
	return sequence


func _aimed_fan(params: Dictionary) -> BarrageSequence:
	var sequence := load("res://patterns/aimed_burst_pattern.gd").new() as BarrageSequence
	sequence.build(params)
	return sequence


## Every 3 s: two interleaved 256-bullet rings fired together while the field
## is already busy, to expose the worst spawn-spike frame.
func _spike_burst() -> BarrageSequence:
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/round.tres")
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 5.0
	var layers: Array[BarrageVolley] = []
	for index in 2:
		var ring := BarrageVolley.new()
		ring.shot = shot
		ring.layout = BarrageVolley.Layout.RING
		ring.count = 256
		ring.speed = 110.0 + index * 25.0
		ring.angle_degrees = index * 0.703125
		layers.append(ring)
	return BarrageSequence.new().fire_together(layers).wait(3.0).repeat()
