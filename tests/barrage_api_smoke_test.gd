extends SceneTree

var failures: Array[String] = []
var world: Node2D
var emitter: Node2D
var player: BarragePlayer
var volleys: Array = []
var completions := 0

func _initialize() -> void:
	run.call_deferred()

func recipe() -> BarrageVolley:
	var shot := BarrageShot.new()
	shot.appearance = BulletAppearance.new()
	shot.behavior = BulletBehavior.new()
	var volley := BarrageVolley.new()
	volley.shot = shot
	return volley

func run() -> void:
	world = Node2D.new()
	world.position = Vector2(15, 20)
	root.add_child(world)
	emitter = Node2D.new()
	emitter.position = Vector2(100, 50)
	world.add_child(emitter)
	player = BarragePlayer.new()
	world.add_child(player)
	player.volley_fired.connect(func(nodes):
		volleys.append(nodes)
		for node in nodes:
			node.set_physics_process(false))
	player.finished.connect(func(): completions += 1)
	var volley := recipe()
	volley.layout = BarrageVolley.Layout.FAN
	volley.count = 5
	var directions := volley.directions()
	expect(directions.size() == 5 and directions[2].is_equal_approx(Vector2.DOWN), "fan is centered")
	expect(is_equal_approx(rad_to_deg(Vector2.DOWN.angle_to(directions[0])), -24), "fan endpoints use full spread")
	volley.count = 1
	expect(volley.directions()[0].is_equal_approx(Vector2.DOWN), "one-way fan has no division by zero")
	volley.layout = BarrageVolley.Layout.RING
	volley.count = 4
	directions = volley.directions()
	expect(directions[0].is_equal_approx(Vector2.DOWN) and directions[3].is_equal_approx(Vector2.RIGHT), "ring distributes without duplicate endpoint")
	volley.origin_offset = Vector2(3, 4)
	var sequence := BarrageSequence.new().fire(volley).wait(0.2).rotate(10).repeat(4)
	expect(player.play(sequence, emitter, world), "valid sequence plays")
	player.set_physics_process(false)
	expect(volleys.size() == 1 and volleys[0].size() == 4, "first volley fires immediately")
	var first: FoundationBullet = volleys[0][0]
	expect(first.global_position.is_equal_approx(emitter.global_position + Vector2(3, 4)), "spawn uses emitter offset and translated world")
	player.advance(0.6)
	expect(volleys.size() == 4, "large delta preserves all due volleys")
	expect((volleys[3][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(30))), "rotation accumulates across loops")
	player.advance(0.2)
	expect(not player.running and completions == 1, "finite repeat completes once after final wait")
	volleys.clear()
	player.play(sequence, emitter, world)
	player.set_physics_process(false)
	for i in 6:
		player.advance(0.1)
	expect(volleys.size() == 4, "split delta produces same volley count")
	expect((volleys[0][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN), "replay resets rotation")
	player.stop()
	var before := volleys.size()
	player.advance(20)
	expect(volleys.size() == before and is_instance_valid(first), "stop cancels future shots without clearing old shots")
	# Snapshot all nested Resources, not just the outer sequence.
	volleys.clear()
	player.play(sequence, emitter, world)
	player.set_physics_process(false)
	volley.count = 20
	volley.shot.appearance.core_size = Vector2(50, 50)
	sequence.steps.clear()
	player.advance(0.2)
	expect(volleys.size() == 2 and volleys[1].size() == 4, "running sequence isolates steps and volley settings")
	expect((volleys[1][0] as FoundationBullet).appearance.core_size == Vector2(8, 8), "nested appearance is snapshotted")
	# Snapshots isolate settings but must share textures: batching keys on texture RID,
	# so two emitters of the same preset have to land in the same MultiMesh.
	var textured := BarrageShot.new()
	textured.appearance = preload("res://resources/projectiles/needle.tres")
	textured.behavior = BulletBehavior.new().wait(0.5).turn_by(30, 1)
	textured.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
	var textured_sequence := BarrageSequence.new().fire_ring(textured, 4).wait(1)
	var shot_a: BarrageShot = textured_sequence.snapshot().steps[0].get_volleys()[0].shot
	var shot_b: BarrageShot = textured_sequence.snapshot().steps[0].get_volleys()[0].shot
	expect(shot_a != textured and shot_a.appearance != textured.appearance and shot_a.behavior.actions[0] != textured.behavior.actions[0] and shot_a.trail_effect != textured.trail_effect, "snapshot copies external presets and nested actions")
	expect(shot_a.appearance.texture == textured.appearance.texture and shot_a.trail_effect.texture == textured.trail_effect.texture, "snapshot shares textures instead of duplicating GPU assets")
	expect(shot_a.appearance.render_key() == shot_b.appearance.render_key(), "two snapshots of one preset keep the same render key")
	var bullet_a := shot_a.spawn(world, emitter.global_position, Vector2.DOWN, 50) as FoundationBullet
	var bullet_b := shot_b.spawn(world, emitter.global_position, Vector2.DOWN, 50) as FoundationBullet
	expect(bullet_a != null and bullet_b != null and bullet_a._render_key == bullet_b._render_key, "bullets from separate snapshots batch together")
	var preset_color := textured.appearance.core_color
	textured.appearance.core_color = Color.RED
	expect(shot_a.appearance.core_color == preset_color, "snapshot ignores later preset edits")
	textured.appearance.core_color = preset_color
	bullet_a.queue_free()
	bullet_b.queue_free()
	player.pause()
	player.advance(3)
	expect(volleys.size() == 2, "local pause consumes no time")
	player.resume()
	paused = true
	player.advance(3)
	expect(volleys.size() == 2, "tree pause consumes no time")
	paused = false
	player.advance(0.2)
	expect(volleys.size() == 3, "resume continues remaining wait")
	player.stop()
	# Aim samples the target for each volley; already fired directions remain fixed.
	volleys.clear()
	var target := Node2D.new()
	world.add_child(target)
	target.position = emitter.position + Vector2(50, 0)
	var aimed := recipe()
	aimed.aimed = true
	var aiming := BarrageSequence.new().fire(aimed).wait(0.1).repeat()
	expect(player.play(aiming, emitter, world, target), "aimed sequence accepts target")
	player.set_physics_process(false)
	target.position = emitter.position + Vector2(0, 50)
	player.advance(0.1)
	expect((volleys[0][0] as FoundationBullet)._direction.is_equal_approx(Vector2.RIGHT) and (volleys[1][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN), "aim updates at each emission")
	target.queue_free()
	player.advance(0.1)
	expect(not player.running and volleys.size() == 2, "deleted target stops aimed sequence")
	# rotate_to sets the base angle absolutely and never accumulates across loops.
	volleys.clear()
	var absolute := BarrageSequence.new().rotate_to(90).fire(recipe()).rotate(45).fire(recipe()).wait(0.1).repeat(2)
	expect(player.play(absolute, emitter, world), "rotate_to sequence plays")
	player.set_physics_process(false)
	player.advance(0.1)
	expect(volleys.size() == 4, "rotate_to sequence fires every volley")
	expect((volleys[0][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(90))) and (volleys[1][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(135))), "rotate_to then rotate compose")
	expect((volleys[2][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(90))), "rotate_to resets the accumulated base angle on the next loop")
	player.stop()
	# aim() locks the emitter-to-target direction for LOCKED volleys; EACH_SHOT keeps re-aiming.
	volleys.clear()
	var lock_target := Node2D.new()
	world.add_child(lock_target)
	lock_target.position = emitter.position + Vector2(50, 0)
	var locked := recipe()
	locked.aim = BarrageVolley.Aim.LOCKED
	var tracking := recipe()
	tracking.aim = BarrageVolley.Aim.EACH_SHOT
	var lock_sequence := BarrageSequence.new().aim().fire(locked).wait(0.1).fire_together([locked, tracking]).wait(0.1)
	expect(lock_sequence.needs_target() and not player.play(lock_sequence, emitter, world), "aim() requires a target in fixed-target mode")
	expect(player.play(lock_sequence, emitter, world, lock_target), "locked sequence plays with a target")
	player.set_physics_process(false)
	lock_target.position = emitter.position + Vector2(0, 50)
	player.advance(0.1)
	expect(volleys.size() == 2 and volleys[1].size() == 2, "locked and tracking volleys fire together")
	expect((volleys[0][0] as FoundationBullet)._direction.is_equal_approx(Vector2.RIGHT) and (volleys[1][0] as FoundationBullet)._direction.is_equal_approx(Vector2.RIGHT), "LOCKED volleys keep the aim() direction while the target moves")
	expect((volleys[1][1] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN), "EACH_SHOT volley re-aims at the current target position")
	player.stop()
	volleys.clear()
	expect(player.play(BarrageSequence.new().fire_together([locked, recipe()]).wait(0.1), emitter, world, lock_target), "LOCKED without aim() is still a valid sequence")
	player.set_physics_process(false)
	expect(volleys.size() == 1 and volleys[0].size() == 1 and (volleys[0][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN), "LOCKED volley without a lock is skipped; the unaimed volley still fires")
	player.stop()
	lock_target.queue_free()
	# relative_to_emitter rotates unaimed directions with the emitter; default stays world-down.
	volleys.clear()
	emitter.rotation = deg_to_rad(90)
	var turret := recipe()
	turret.relative_to_emitter = true
	expect(player.play(BarrageSequence.new().fire_together([turret, recipe()]), emitter, world), "turret sequence plays")
	expect(volleys.size() == 1 and volleys[0].size() == 2, "turret volley fires")
	expect((volleys[0][0] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN.rotated(deg_to_rad(90))) and (volleys[0][1] as FoundationBullet)._direction.is_equal_approx(Vector2.DOWN), "relative_to_emitter follows emitter rotation while the default volley ignores it")
	emitter.rotation = 0
	var compat := recipe()
	compat.aimed = true
	expect(compat.aim == BarrageVolley.Aim.EACH_SHOT and compat.aimed, "aimed=true maps to Aim.EACH_SHOT")
	compat.aim = BarrageVolley.Aim.LOCKED
	compat.aimed = true
	expect(compat.aim == BarrageVolley.Aim.LOCKED, "aimed=true never downgrades LOCKED")
	# Laser recipe and emitter lifetime.
	var laser_volley := recipe()
	laser_volley.shot.kind = BarrageShot.Kind.CURVED_LASER
	laser_volley.shot.turn_degrees = -70
	laser_volley.layout = BarrageVolley.Layout.RING
	laser_volley.count = 12
	volleys.clear()
	player.play(BarrageSequence.new().fire(laser_volley).wait(4).repeat(), emitter, world)
	player.set_physics_process(false)
	expect(volleys[0].size() == 12 and volleys[0][0] is CurvedLaser and volleys[0][0].turn_degrees == -70, "API creates configured laser flower")
	var surviving: Node2D = volleys[0][0]
	emitter.queue_free()
	player.advance(4)
	expect(not player.running and volleys.size() == 1 and not surviving.is_queued_for_deletion(), "emitter deletion stops future emissions and leaves fired projectiles")
	await process_frame
	expect(is_instance_valid(surviving), "fired projectile survives actual emitter destruction")
	emitter = Node2D.new()
	world.add_child(emitter)
	var invalid := BarrageSequence.new().fire(recipe()).repeat()
	expect(not player.play(invalid, emitter, world), "reject zero-duration infinite loop")
	expect(not player.last_error.is_empty(), "validation returns readable error")
	expect(not player.play(BarrageSequence.new().wait(-1), emitter, world), "reject negative wait")
	var bad := recipe()
	bad.count = 0
	expect(not player.play(BarrageSequence.new().fire(bad), emitter, world), "reject invalid counts before spawning")
	expect(not player.play(BarrageSequence.new().fire(recipe()), emitter, emitter), "reject emitter-owned projectile parent")
	volleys.clear()
	var bounded := BarrageSequence.new().fire(recipe()).wait(0.0001).repeat()
	player.play(bounded, emitter, world)
	player.set_physics_process(false)
	player.advance(1)
	expect(volleys.size() < 260 and player.running, "catch-up work is bounded per tick")
	var pending := volleys.size()
	player.advance(0)
	expect(volleys.size() > pending, "bounded work keeps unconsumed time")
	player.stop()
	# A signal handler is allowed to cancel the sequence synchronously.
	var cancel := func(_shots): player.stop()
	player.volley_fired.connect(cancel)
	volleys.clear()
	player.play(BarrageSequence.new().fire(recipe()).fire(recipe()), emitter, world)
	expect(volleys.size() == 1 and not player.running, "reentrant stop prevents later steps")
	player.volley_fired.disconnect(cancel)
	var pause_on_fire := func(_shots): player.pause()
	player.volley_fired.connect(pause_on_fire)
	volleys.clear()
	player.play(BarrageSequence.new().fire(recipe()).fire(recipe()), emitter, world)
	player.set_physics_process(false)
	expect(volleys.size() == 1, "pause from signal stops same-frame remaining steps")
	player.volley_fired.disconnect(pause_on_fire)
	player.resume()
	player.advance(0)
	expect(volleys.size() == 2 and not player.running, "signal-paused steps resume without loss")
	player.play(BarrageSequence.new().wait(0.1).fire(recipe()), emitter, world)
	player.set_physics_process(false)
	emitter.free()
	player.advance(0.1)
	expect(not player.running, "already freed emitter is handled without dereferencing")
	emitter = Node2D.new()
	world.add_child(emitter)
	player.play(BarrageSequence.new().wait(0.1).fire(recipe()), emitter, world)
	player.pause()
	world.remove_child(emitter)
	expect(not player.running, "tree exit cancels even while locally paused")
	world.add_child(emitter)
	player.resume()
	player.advance(1)
	expect(not player.running, "re-entering tree never resurrects a cancelled sequence")
	var replacement := Node2D.new()
	world.add_child(replacement)
	player.play(BarrageSequence.new().wait(0.1).fire(recipe()), emitter, world)
	player.play(BarrageSequence.new().wait(0.1).fire(recipe()), replacement, world)
	player.set_physics_process(false)
	emitter.free()
	expect(player.running, "previous emitter lifetime binding is detached on replacement")
	player.advance(0.1)
	expect(not player.running, "replacement sequence completes normally")
	var saved := load("res://resources/projectiles/rotating_ring_sequence.tres") as BarrageSequence
	expect(saved != null and saved.validation_error().is_empty(), "saved Resource is executable")
	world.queue_free()
	await process_frame
	var lab = load("res://labs/bullet/presets/barrage_api_lab.tscn").instantiate()
	root.add_child(lab)
	expect(lab.pattern_choice.selected == 5, "dedicated scene opens the API demonstration")
	lab.pattern_choice.select(5)
	lab._selection_changed(5)
	lab.pattern_player.set_physics_process(false)
	expect(lab.shape_choice.selected == 1 and lab.pattern_player.running, "API example is selectable in lab")
	lab.pattern_player.advance(1.0)
	var live := 0
	for node in get_nodes_in_group("enemy_projectiles"):
		if not node.is_queued_for_deletion():
			live += 1
	expect(live == 96, "saved six-volley pattern emits exactly 96 bullets")
	var example_volleys: Array = []
	lab.pattern_player.volley_fired.connect(func(shots): example_volleys.append(shots))
	lab.pattern_player.advance(1.19)
	expect(example_volleys.is_empty(), "saved example rests after sixth volley")
	lab.pattern_player.advance(0.01)
	expect(example_volleys.size() == 1, "saved example rest is exactly 1.2 seconds")
	if "--capture" in OS.get_cmdline_user_args():
		lab.restart()
		await create_timer(0.95).timeout
		lab.toggle_pause()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/barrage_api_lab.png")
	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("barrage API smoke test: PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
