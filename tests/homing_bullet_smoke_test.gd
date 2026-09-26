extends SceneTree

var failures: Array[String] = []
var world: Node2D
var target: Node2D
var resolve_calls := 0
var replacement: Node2D

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func resolver() -> Node2D:
	resolve_calls += 1
	return replacement if is_instance_valid(replacement) else null

func shot(behavior: BulletBehavior, kind := BarrageShot.Kind.BULLET) -> BarrageShot:
	var result := BarrageShot.new()
	result.kind = kind
	result.appearance = preload("res://resources/projectiles/round.tres")
	result.behavior = behavior
	result.lifetime = 8
	return result

func spawn(recipe: BarrageShot, speed := 20.0, tracked: Node2D = target) -> Node2D:
	var bullet := recipe.spawn(world, Vector2(200, 100), Vector2.DOWN, speed, false, tracked, resolver)
	bullet.set_physics_process(false)
	return bullet

func update(bullet: Node2D, time: float) -> void:
	bullet.age = time
	if bullet is CurvedLaser: bullet._update_body()
	else: bullet._update_pose()

func run() -> void:
	test_timeline()
	world = Node2D.new()
	root.add_child(world)
	target = Node2D.new()
	world.add_child(target)
	target.position = Vector2(500, 100)
	var behavior := BulletBehavior.new().homing(90, 1).turn_by(30, 0.5).wait(1)
	var bullet := spawn(shot(behavior))
	var runtime: BulletBehaviorState = bullet.behavior_state
	var predicted := runtime.position_at(0.25)
	expect(resolve_calls == 0 and runtime.playback_time == 0, "prediction neither resolves a target nor advances time")
	update(bullet, 0.25)
	expect(absf(runtime.sample(0.25).heading + 22.5) < 0.001, "homing obeys maximum turn rate")
	expect(runtime.position_at(0.25).distance_to(predicted) < 0.001, "fixed target prediction equals movement")
	var history := runtime.position_at(0.137)
	var old_future := runtime.position_at(0.75)
	target.position = Vector2(-100, 100)
	update(bullet, 0.5)
	expect(runtime.position_at(0.137) == history, "moving target preserves historical substep positions")
	expect(runtime.position_at(0.75).distance_to(old_future) > 1, "moving target invalidates future prediction")
	update(bullet, 1)
	var final_heading: float = runtime.sample(1).heading
	update(bullet, 1.5)
	expect(absf(runtime.sample(1.5).heading - final_heading - 30) < 0.001, "relative action starts from actual homing end heading")
	expect(absf(runtime.sample(3).heading - runtime.sample(1.5).heading) < 0.001, "completed heading persists")
	# Lost target: coast, then reacquire only during actual updates.
	var seeker := spawn(shot(BulletBehavior.new().homing(60, 6)))
	update(seeker, 0.2)
	var heading: float = seeker.behavior_state.sample(0.2).heading
	target.free()
	seeker.behavior_state.position_at(2)
	expect(resolve_calls == 0, "future sampling does not reacquire a deleted target")
	update(seeker, 0.4)
	expect(resolve_calls == 1 and absf(seeker.behavior_state.sample(0.4).heading - heading) < 0.001, "missing target coasts and tries once per tick")
	replacement = Node2D.new()
	world.add_child(replacement)
	replacement.position = Vector2(500, 100)
	update(seeker, 0.6)
	expect(resolve_calls == 2 and seeker.behavior_state.sample(0.6).heading < heading, "reacquired target resumes turning")
	update(seeker, 0.8)
	expect(resolve_calls == 2, "valid target is retained without resolver calls")
	target = replacement
	# Foreign viewport / malformed resolver results are treated as no target.
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var foreign := Node2D.new()
	viewport.add_child(foreign)
	foreign.position = Vector2(500, 100)
	var isolated := shot(BulletBehavior.new().homing(90, 1)).spawn(world, Vector2(200, 100), Vector2.DOWN, 20, false, foreign, func(): return "invalid")
	isolated.set_physics_process(false)
	update(isolated, 0.2)
	expect(isolated.behavior_state.sample(0.2).heading == 0, "foreign viewport and malformed provider cannot steer")
	viewport.queue_free()
	# Coincident and exactly opposite target; two bullets must not share input.
	target.position = Vector2(200, 100)
	var overlap := spawn(shot(BulletBehavior.new().homing(90, 1)), 0)
	update(overlap, 0.2)
	expect(overlap.behavior_state.sample(0.2).heading == 0, "coincident target keeps heading")
	target.position = Vector2(200, 0)
	var opposite := spawn(shot(BulletBehavior.new().homing(90, 1)), 0)
	update(opposite, 0.2)
	expect(absf(opposite.behavior_state.sample(0.2).heading - 18) < 0.001, "180 degree tie turns positive")
	expect(overlap.behavior_state.sample(0.2).heading == 0, "bullet histories are independent")
	# Parallel homing may finish before other channels; finite repeats accumulate.
	var parallel := BulletBehavior.new().parallel([BulletAction.homing(90, 0.25), BulletAction.make(BulletAction.Type.SPEED, 40, 0.5), BulletAction.tint_to(Color.RED, 0.5)]).repeat(2)
	var combined := spawn(shot(parallel))
	update(combined, 0.5)
	expect(absf(combined.behavior_state.sample(0.49).heading - 22.5) < 0.001, "short homing child stops before parallel group ends")
	expect(combined.behavior_state.sample(0.5).speed == 40 and combined.behavior_state.sample(0.5).tint == Color.RED, "parallel speed and color interpolate")
	update(combined, 1.2)
	expect(absf(combined.behavior_state.sample(1.2).heading - 45) < 0.001, "finite homing repeats preserve accumulated heading")
	expect(not BulletBehavior.new().parallel([BulletAction.homing(90, 1), BulletAction.turn_by(30, 1)]).validation_error().is_empty(), "conflicting heading actions rejected")
	for invalid in [BulletBehavior.new().homing(0, 1), BulletBehavior.new().homing(90, 0), BulletBehavior.new().homing(-1, 1)]:
		expect(not invalid.validation_error().is_empty(), "invalid homing rejected")
	# Laser uses exactly the same committed history for body and threat sampling.
	target.position = Vector2(500, 100)
	var laser := spawn(shot(BulletBehavior.new().homing(90, 4), BarrageShot.Kind.TRAIL_LASER)) as CurvedLaser
	update(laser, 0.4)
	var tail := laser.position_at(0.2)
	var forecast := laser.get_predicted_path(0.2)
	update(laser, 0.6)
	expect(forecast[-1].distance_to(laser.global_position) < 0.001, "laser forecast endpoint agrees with actual head")
	target.position = Vector2(-100, 100)
	update(laser, 0.8)
	expect(laser.position_at(0.2) == tail, "laser keeps old tail after target changes")
	expect(laser._body[-1].distance_to(laser.global_position) < 0.001, "laser visible head matches physical position")
	# Pause uses the same engine clock as existing projectiles.
	seeker.set_physics_process(true)
	var frozen: Vector2 = seeker.global_position
	paused = true
	await create_timer(0.05, true).timeout
	expect(seeker.global_position == frozen, "tree pause freezes homing")
	paused = false
	world.queue_free()
	await process_frame
	await test_player_and_collision()
	await test_lab()
	if failures.is_empty(): print("homing bullet smoke test: PASS")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func test_player_and_collision() -> void:
	world = Node2D.new()
	root.add_child(world)
	target = Node2D.new()
	world.add_child(target)
	target.position = Vector2(200, 160)
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 2
	collision.shape = circle
	hurtbox.add_child(collision)
	target.add_child(hurtbox)
	var hits: Array = []
	hurtbox.hurt.connect(func(hit): hits.append(hit))
	var emitter := Node2D.new()
	world.add_child(emitter)
	emitter.position = Vector2(200, 100)
	var player := BarragePlayer.new()
	world.add_child(player)
	var projectiles: Array[Node2D] = []
	player.volley_fired.connect(func(nodes): projectiles.assign(nodes))
	var sequence := BarrageSequence.new().fire_fan(shot(BulletBehavior.new().homing(180, 2)), 1, 0, 90)
	target.position = Vector2(500, 100)
	expect(player.play(sequence, emitter, world, target), "non-aimed homing pattern accepts target")
	var bullet := projectiles[0]
	expect(absf(bullet.behavior_state.sample(0.1).heading + 18) < 0.001, "BarragePlayer passes tracking target even when aimed is false")
	target.position = Vector2(200, 160)
	emitter.free()
	player.free()
	await create_timer(0.9).timeout
	expect(hits.size() == 1 and not is_instance_valid(bullet), "homing survives emitter removal and hits actual hurtbox")
	world.queue_free()
	await process_frame
	# Resolver callbacks can stop the pattern during its first projectile spawn.
	world = Node2D.new()
	root.add_child(world)
	emitter = Node2D.new()
	world.add_child(emitter)
	player = BarragePlayer.new()
	world.add_child(player)
	player.resolve_target = func():
		player.stop()
		return null
	sequence = BarrageSequence.new().fire_fan(shot(BulletBehavior.new().homing(90, 1)), 3, 30, 20)
	player.play(sequence, emitter, world)
	expect(not player.running and get_nodes_in_group("enemy_projectiles").size() == 1, "resolver stop prevents remaining volley spawns")
	world.queue_free()
	await process_frame

func test_lab() -> void:
	var lab = load("res://labs/bullet/presets/homing_bullet_lab.tscn").instantiate()
	root.add_child(lab)
	lab.pattern_player.stop()
	expect(lab.pattern_choice.selected == 8 and root.gui_get_focus_owner() == lab.shape_choice, "homing Lab starts with keyboard focus and homing selected")
	for node in get_nodes_in_group("enemy_projectiles"):
		node.set_physics_process(false)
	for selection in [8, 9]:
		lab.pattern_choice.select(selection)
		lab._selection_changed(selection)
		lab.pattern_player.stop()
		await process_frame
		var bullets := get_nodes_in_group("enemy_projectiles")
		expect(bullets.size() == 3, "homing Lab emits three projectiles")
		for node in bullets: node.set_physics_process(false)
		for tick in 90:
			lab.target.position = Vector2(208 + 100 * sin(tick / 60.0 * 2), 230)
			for node in bullets: update(node, (tick + 1) / 60.0)
		lab.hitbox_button.button_pressed = true
		if "--capture" in OS.get_cmdline_user_args():
			lab.toggle_pause()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/homing_" + ("bullet" if selection == 8 else "laser") + "_lab.png")
			lab.toggle_pause()
	lab.queue_free()
	await process_frame

func test_timeline() -> void:
	var lateral := BulletAction.make(BulletAction.Type.LATERAL_WAVE, 8, 0.4)
	lateral.period = 0.4
	var behavior := BulletBehavior.new().turn_by(30, 0).homing(90, 0.2).parallel([
		lateral, BulletAction.make(BulletAction.Type.SPEED, 80, 0.4),
		BulletAction.make(BulletAction.Type.OPACITY, 0.3, 0.2),
	]).turn_to(100, 0.3).heading_wave(20, 0.5).repeat(2)
	var reference_behavior := behavior.duplicate(true) as BulletBehavior
	reference_behavior.actions[1].type = BulletAction.Type.WAIT
	var dynamic := BulletBehaviorState.new(behavior, Vector2.DOWN, 20, Color.WHITE, 5)
	var reference := BulletBehaviorState.new(reference_behavior, Vector2.DOWN, 20, Color.WHITE, 5)
	dynamic.advance_to(4)
	for time in [0.0, 0.1, 0.2, 0.33, 0.6, 0.9, 1.4, 2.8, 3.99]:
		var actual := dynamic.sample(time)
		var expected := reference.sample(time)
		for key in ["heading", "speed", "lateral", "lateral_velocity", "opacity"]:
			expect(absf(actual[key] - expected[key]) < 0.0001, "no-target homing preserves other timeline channels: " + key)
		expect(dynamic.position_at(time).distance_to(reference.position_at(time)) < 0.001, "no-target homing follows normal Action movement")
	var infinite := BulletBehaviorState.new(BulletBehavior.new().homing(90, 0.1).turn_by(5, 0).repeat(), Vector2.DOWN, 0, Color.WHITE, 8)
	infinite.advance_to(0.35)
	expect(absf(infinite.sample(0.35).heading - 15) < 0.001, "infinite homing cycles execute instant boundary actions")
	# A dead resolver is a missing provider, not an error or a reason to remove a bullet.
	var provider := Node2D.new()
	var callback := Callable(provider, "get_parent")
	provider.free()
	var owner := Node2D.new()
	root.add_child(owner)
	infinite.configure_homing(owner, Vector2.ZERO, null, callback)
	infinite.advance_to(0.45)
	expect(absf(infinite.sample(0.45).heading - 20) < 0.001, "freed resolver leaves the projectile active")
	owner.free()
