extends SceneTree
## Pooled enemy bullet cost (EnemyBulletPool + FoundationBullet handles) under
## a fixed, physics-clock-driven fire schedule at a moving player hurtbox.
## Scenarios: moderate / dense / extreme bullet loads, plus the extreme load
## with a time-warp style slow field (`_field`) and a brink style whole-screen
## slow (`_brink`) so the effect path is measured too. Run with a window:
##   tools/run-godot.cmd --script res://tests/benchmarks/bullet_pool_benchmark.gd
## Columns: `tick_ms` = script cost of one physics tick (priority sentinels),
## `server_ms` = the engine's own physics step after the callbacks,
## `process_ms` = the process pass. Frame intervals only detect spikes (a
## windowed D3D12 swapchain stays capped at the display refresh rate) and
## TIME_PHYSICS_PROCESS is the engine's rolling one-second maximum step.
## Results: artifacts/bullet_pool_benchmark.json (compare with the node-era
## numbers kept in artifacts/bullet_pool_prototype_benchmark.json).

const ROUND := preload("res://resources/projectiles/round.tres")
const RICE := preload("res://resources/projectiles/rice.tres")
const NEEDLE := preload("res://resources/projectiles/needle.tres")
const WARMUP_SECONDS := 3.0
const MEASURE_SECONDS := 8.0
const SCENARIOS := ["moderate", "dense", "extreme", "extreme_field", "extreme_brink"]

var results := []


class Sentinel extends Node:
	var on_physics := Callable()
	var on_process := Callable()

	func _physics_process(_delta: float) -> void:
		if on_physics.is_valid(): on_physics.call()

	func _process(_delta: float) -> void:
		if on_process.is_valid(): on_process.call()


## Fixed schedule: every emitter is {origin, period, events: [{t, volley}]}.
class Driver extends Node:
	var clock := 0.0
	var emitters: Array = []
	var fire := Callable()
	var target: Node2D
	var on_tick := Callable()

	func _physics_process(delta: float) -> void:
		clock += delta
		target.position = Vector2(320, 290) + Vector2(sin(clock * TAU / 1.7) * 240.0, sin(clock * TAU / 1.1) * 40.0)
		if on_tick.is_valid(): on_tick.call()
		for emitter in emitters:
			var cycle: int = emitter.cycle
			var period: float = emitter.period
			var events: Array = emitter.events
			while true:
				var index: int = emitter.next
				if index >= events.size():
					emitter.cycle = cycle + 1
					cycle += 1
					emitter.next = 0
					index = 0
				var event: Dictionary = events[index]
				var due: float = cycle * period + float(event.t)
				if due > clock:
					break
				var volley: BarrageVolley = event.volley
				var origin: Vector2 = emitter.origin
				for direction in volley.directions(0.0, target.position - origin):
					fire.call(volley.shot, origin, direction, volley.speed)
				emitter.next = index + 1


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This benchmark requires a rendered window; omit --headless.")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for scenario_name in SCENARIOS:
		await _scenario(scenario_name)
	FileAccess.open("res://artifacts/bullet_pool_benchmark.json", FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	print("bullet pool benchmark: COMPLETE")
	quit()


func _scenario(scenario_name: String) -> void:
	var world := Node2D.new()
	root.add_child(world)
	var target := Node2D.new()
	target.position = Vector2(320, 290)
	world.add_child(target)
	# A real player-side hurtbox: the pool tests bullets against it and hits
	# free the bullet, as in the game.
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 3.0
	hurtbox.add_child(shape)
	var hits := [0]
	hurtbox.hurt.connect(func(_hitbox) -> void: hits[0] += 1)
	target.add_child(hurtbox)
	var driver := Driver.new()
	driver.target = target
	driver.emitters = _emitters(scenario_name)
	world.add_child(driver)
	driver.fire = func(shot: BarrageShot, origin: Vector2, direction: Vector2, speed: float) -> void:
		shot.spawn(world, origin, direction, speed, false, target, Callable(), true)
	var effects_applied := [0]
	var field_handle := &"bench_field"
	var brink_handle := &"bench_brink"
	if scenario_name.ends_with("_field"):
		var field := BulletSlowField.new(field_handle, 0.5)
		var seen: Dictionary = {}
		driver.on_tick = func() -> void:
			field.update(world, target.position, 50.0)
			for id in field._inside:
				if not seen.has(id):
					seen[id] = true
					effects_applied[0] += 1
	elif scenario_name.ends_with("_brink"):
		# Brink rule: for the first 2 s of every 4 s, every bullet on screen
		# (and every new one) gets x0.2 for the time left.
		driver.on_tick = func() -> void:
			var phase := fmod(driver.clock, 4.0)
			if phase >= 2.0: return
			for bullet in EnemyBullets.get_all(world):
				if EnemyBullets.get_effect(bullet, brink_handle).is_empty() and EnemyBullets.apply_effect(bullet, brink_handle, 0.2, 0.0, 2.0 - phase):
					effects_applied[0] += 1
	# Sentinels bracket every physics tick and every process pass.
	var physics_start := [0]
	var process_start := [0]
	var physics_end := [0]
	var stepped := [false]
	var tick_list: Array[float] = []
	var pass_list: Array[float] = []
	var gap_list: Array[float] = []
	var count_list: Array[int] = []
	var measuring := [false]
	var first := Sentinel.new()
	first.process_physics_priority = -1000000
	first.process_priority = -1000000
	first.process_mode = Node.PROCESS_MODE_ALWAYS
	first.on_physics = func() -> void: physics_start[0] = Time.get_ticks_usec()
	first.on_process = func() -> void:
		var now := Time.get_ticks_usec()
		process_start[0] = now
		if stepped[0]:
			stepped[0] = false
			if measuring[0]:
				gap_list.append(float(now - physics_end[0]))
	var last := Sentinel.new()
	last.process_physics_priority = 1000000
	last.process_priority = 1000000
	last.process_mode = Node.PROCESS_MODE_ALWAYS
	last.on_physics = func() -> void:
		var now := Time.get_ticks_usec()
		if measuring[0]:
			tick_list.append(float(now - physics_start[0]))
			count_list.append(get_node_count_in_group(&"enemy_projectiles"))
		physics_end[0] = Time.get_ticks_usec()
		stepped[0] = true
	last.on_process = func() -> void:
		if measuring[0]:
			pass_list.append(float(Time.get_ticks_usec() - process_start[0]))
	root.add_child(first)
	root.add_child(last)
	var measure_render := RenderingServer.has_method("viewport_set_measure_render_time")
	if measure_render:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var intervals := PackedFloat64Array()
	var physics_monitor := PackedFloat64Array()
	var draws := PackedInt32Array()
	var render_cpu := PackedFloat64Array()
	var render_gpu := PackedFloat64Array()
	var start := Time.get_ticks_usec()
	var previous := start
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - start) / 1000000.0
		if elapsed > WARMUP_SECONDS:
			measuring[0] = true
			intervals.append((now - previous) / 1000.0)
			physics_monitor.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			if measure_render:
				render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		previous = now
		if elapsed >= WARMUP_SECONDS + MEASURE_SECONDS:
			break
	measuring[0] = false
	var straight := 0
	for bullet in EnemyBullets.get_all(world):
		if bullet is FoundationBullet and bullet._straight:
			straight += 1
	var tick_us := PackedFloat64Array(tick_list)
	var pass_us := PackedFloat64Array(pass_list)
	var gap_us := PackedFloat64Array(gap_list)
	var counts := PackedInt32Array(count_list)
	gap_us.sort()
	tick_us.sort()
	pass_us.sort()
	counts.sort()
	intervals.sort()
	physics_monitor.sort()
	draws.sort()
	render_cpu.sort()
	render_gpu.sort()
	var result := {
		"scenario": scenario_name,
		"ticks": tick_us.size(),
		"tick_ms": _round3(_percentile(tick_us, 0.5) / 1000.0),
		"tick_p95_ms": _round3(_percentile(tick_us, 0.95) / 1000.0),
		"tick_max_ms": _round3(tick_us[-1] / 1000.0) if not tick_us.is_empty() else 0.0,
		"server_ms": _round3(_percentile(gap_us, 0.5) / 1000.0),
		"server_p95_ms": _round3(_percentile(gap_us, 0.95) / 1000.0),
		"process_ms": _round3(_percentile(pass_us, 0.5) / 1000.0),
		"process_p95_ms": _round3(_percentile(pass_us, 0.95) / 1000.0),
		"physics_monitor_ms": _round3(_percentile(physics_monitor, 0.5)),
		"physics_monitor_max_ms": _round3(physics_monitor[-1]) if not physics_monitor.is_empty() else 0.0,
		"frames": intervals.size(),
		"frame_ms": _round3(_percentile(intervals, 0.5)),
		"frame_p95_ms": _round3(_percentile(intervals, 0.95)),
		"frame_max_ms": _round3(intervals[-1]),
		"render_cpu_ms": _round3(_percentile(render_cpu, 0.5)) if measure_render else -1.0,
		"render_gpu_ms": _round3(_percentile(render_gpu, 0.5)) if measure_render else -1.0,
		"bullets_min": counts[0] if not counts.is_empty() else 0,
		"bullets_median": _percentile_int(counts, 0.5),
		"bullets_max": counts[-1] if not counts.is_empty() else 0,
		"draw_calls": _percentile_int(draws, 0.5),
		"hits": hits[0],
		"effects_applied": effects_applied[0],
		"straight_at_end": straight,
	}
	results.append(result)
	print(JSON.stringify(result))
	first.queue_free()
	last.queue_free()
	world.queue_free()
	await process_frame
	await process_frame


func _percentile(sorted_values: PackedFloat64Array, fraction: float) -> float:
	if sorted_values.is_empty(): return 0.0
	return sorted_values[int((sorted_values.size() - 1) * fraction)]


func _percentile_int(sorted_values: PackedInt32Array, fraction: float) -> int:
	if sorted_values.is_empty(): return 0
	return sorted_values[int((sorted_values.size() - 1) * fraction)]


func _round3(value: float) -> float:
	return snappedf(value, 0.001)


## Fresh resources per run so no scenario inherits another's shared caches.
func _shot(appearance: BulletAppearance, behavior: BulletBehavior, lifetime: float) -> BarrageShot:
	var shot := BarrageShot.new()
	shot.appearance = appearance
	shot.behavior = behavior
	shot.lifetime = lifetime
	if not shot.is_valid():
		push_error("benchmark shot must be valid")
		quit(1)
	return shot


func _volley(shot: BarrageShot, layout: BarrageVolley.Layout, count: int, speed: float, angle := 0.0, spread := 0.0, aim := BarrageVolley.Aim.NONE) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = layout
	volley.count = count
	volley.speed = speed
	volley.angle_degrees = angle
	volley.spread_degrees = spread
	volley.aim = aim
	return volley


func _emitter(origin: Vector2, period: float, events: Array) -> Dictionary:
	return {"origin": origin, "period": period, "events": events, "cycle": 0, "next": 0}


## Caster ring curtain: 5 rings of 16 at 95 px/s, 0.1 s apart, spun 7° per ring.
func _caster(origin: Vector2, rest: float, spin: float) -> Dictionary:
	var shot := _shot(ROUND, BulletBehavior.new(), 8.0)
	var events := []
	for index in 5:
		events.append({"t": index * 0.1, "volley": _volley(shot, BarrageVolley.Layout.RING, 16, 95.0, -90.0 + index * spin)})
	return _emitter(origin, 0.4 + rest, events)


## Aimed needle fan bursts: `ways` bullets over `spread`°, `shots` volleys 0.15 s apart.
func _aimed_fan(origin: Vector2, ways: int, spread: float, shots: int, rest: float, speed: float) -> Dictionary:
	var shot := _shot(NEEDLE, BulletBehavior.new(), 8.0)
	var events := []
	for index in shots:
		events.append({"t": index * 0.15, "volley": _volley(shot, BarrageVolley.Layout.FAN, ways, speed, 0.0, spread, BarrageVolley.Aim.EACH_SHOT)})
	return _emitter(origin, (shots - 1) * 0.15 + rest, events)


## Wavy rice curtain like wave_curtain_pattern: two 70° fans out of phase.
func _wave_curtain(origin: Vector2) -> Dictionary:
	var even := _shot(RICE, BulletBehavior.new().lateral_wave(16.0, 1.3).repeat(), 5.0)
	var odd := _shot(RICE, BulletBehavior.new().lateral_wave(16.0, 1.3, PI).repeat(), 5.0)
	return _emitter(origin, 0.8, [
		{"t": 0.0, "volley": _volley(even, BarrageVolley.Layout.FAN, 17, 150.0, 0.0, 70.0)},
		{"t": 0.4, "volley": _volley(odd, BarrageVolley.Layout.FAN, 16, 150.0, 0.0, 70.0)},
	])


## Spike: two interleaved 256-bullet rings together every 3 s.
func _spike_burst(origin: Vector2, offset := 0.0) -> Dictionary:
	var shot := _shot(ROUND, BulletBehavior.new(), 5.0)
	return _emitter(origin, 3.0, [
		{"t": offset, "volley": _volley(shot, BarrageVolley.Layout.RING, 256, 110.0, 0.0)},
		{"t": offset, "volley": _volley(shot, BarrageVolley.Layout.RING, 256, 135.0, 0.703125)},
	])


## Dense ring curtain: 5 rings of `count` at 80 px/s so they linger on screen.
func _ring_curtain(origin: Vector2, count: int, rest: float, spin: float) -> Dictionary:
	var shot := _shot(ROUND, BulletBehavior.new(), 8.0)
	var events := []
	for index in 5:
		events.append({"t": index * 0.12, "volley": _volley(shot, BarrageVolley.Layout.RING, count, 80.0, -90.0 + index * spin)})
	return _emitter(origin, 0.48 + rest, events)


func _emitters(scenario_name: String) -> Array:
	match scenario_name.trim_suffix("_field").trim_suffix("_brink"):
		"moderate":
			return [
				_caster(Vector2(200, 70), 4.2, 7.0),
				_caster(Vector2(440, 70), 4.8, -7.0),
				_aimed_fan(Vector2(120, 50), 5, 15.0, 3, 2.4, 90.0),
				_aimed_fan(Vector2(520, 50), 7, 30.0, 2, 2.0, 80.0),
				_wave_curtain(Vector2(320, 30)),
			]
		"dense":
			return [
				_caster(Vector2(160, 70), 3.6, 7.0),
				_caster(Vector2(480, 70), 4.2, -7.0),
				_wave_curtain(Vector2(320, 30)),
				_aimed_fan(Vector2(90, 50), 7, 30.0, 3, 1.8, 80.0),
				_aimed_fan(Vector2(550, 50), 7, 30.0, 3, 1.8, 80.0),
				_spike_burst(Vector2(320, 80)),
			]
		"extreme":
			return [
				_ring_curtain(Vector2(160, 70), 26, 2.4, 7.0),
				_ring_curtain(Vector2(480, 70), 26, 2.4, -7.0),
				_wave_curtain(Vector2(320, 30)),
				_aimed_fan(Vector2(90, 50), 7, 30.0, 3, 1.8, 80.0),
				_aimed_fan(Vector2(550, 50), 7, 30.0, 3, 1.8, 80.0),
				_spike_burst(Vector2(320, 80)),
				_spike_burst(Vector2(320, 120), 1.5),
			]
	return []
