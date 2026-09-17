extends SceneTree

const BULLET := preload("res://projectiles/foundation_bullet.tscn")
const ROUND := preload("res://resources/projectiles/round.tres")
const RICE := preload("res://resources/projectiles/rice.tres")
const ORB := preload("res://resources/projectiles/orb.tres")
# Use an explicit nonzero wave fixture: the editable Lab preset may be flat.
var WAVE := BulletBehavior.new().lateral_wave(12.0, 1.2).repeat()
const STRAIGHT := preload("res://resources/projectiles/straight_behavior.tres")
const LAB := preload("res://projectiles/bullet_lab.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _bullet(parent: Node, appearance: BulletAppearance, motion: BulletBehavior, origin: Vector2, direction: Vector2, speed: float) -> FoundationBullet:
	var bullet := BULLET.instantiate() as FoundationBullet
	bullet.appearance = appearance
	bullet.behavior = motion
	parent.add_child(bullet)
	bullet.global_position = origin
	bullet.launch(direction, speed)
	bullet.set_physics_process(false)
	return bullet


func _run() -> void:
	var origin := Vector2(160, 100)
	for direction in [Vector2.DOWN, Vector2.RIGHT, Vector2(1, 1).normalized()]:
		for phase in [0.0, 1.0, PI]:
			var config := WAVE.duplicate(true) as BulletBehavior
			config.actions[0].phase = phase
			var bullet := _bullet(root, ROUND, config, origin, direction, 95)
			_expect(bullet.global_position.is_equal_approx(origin), "nonzero phase never jumps at launch")
			bullet._physics_process(0.3)
			var offset := bullet.global_position - origin
			_expect(is_equal_approx(offset.dot(direction), 28.5), "wave preserves forward travel for every launch axis")
			var expected_lateral := 12 * (sin(PI / 2 + phase) - sin(phase))
			_expect(is_equal_approx(offset.dot(direction.orthogonal()), expected_lateral), "wave displacement follows the launch-local normal")
			bullet.free()
	var stepped := _bullet(root, RICE, WAVE, origin, Vector2.DOWN, 95)
	var single := _bullet(root, RICE, WAVE, origin, Vector2.DOWN, 95)
	for index in 60:
		stepped._physics_process(0.01)
	single._physics_process(0.6)
	_expect(stepped.global_position.distance_to(single.global_position) < 0.001, "frame partition does not change the trajectory")
	_expect(absf(angle_difference(single.global_rotation, single.get_threat_velocity().angle() + PI * 0.5)) < 0.001, "rice follows instantaneous travel direction")
	var first_shape := stepped.get_node("HitboxComponent/CollisionShape2D") as CollisionShape2D
	var second_shape := single.get_node("HitboxComponent/CollisionShape2D") as CollisionShape2D
	_expect(first_shape.shape != second_shape.shape, "collision shapes are per projectile")
	stepped.behavior.actions[0].value = 0
	_expect(is_equal_approx(single.behavior.actions[0].value, 12.0), "active motion is isolated")
	stepped.free()
	single.free()
	var zero_wave := WAVE.duplicate(true) as BulletBehavior
	zero_wave.actions[0].value = 0
	var straight := _bullet(root, ROUND, STRAIGHT, origin, Vector2.DOWN, 95)
	var wave := _bullet(root, ROUND, zero_wave, origin, Vector2.DOWN, 95)
	straight._physics_process(1.0)
	wave._physics_process(1.0)
	_expect(straight.global_position.is_equal_approx(wave.global_position), "zero amplitude equals straight travel")
	straight.free()
	wave.free()
	var predictor := _bullet(root, ROUND, WAVE, origin, Vector2.DOWN, 95)
	var points := predictor.get_threat_path(0.6)
	predictor._physics_process(0.6)
	_expect(points[points.size() - 1].distance_to(predictor.global_position) < 0.001, "future path ends at actual future position")
	_expect(points.size() > 2 and absf(points[6].x - origin.x) > 10, "prediction includes the wave bulge, not just the chord")
	predictor.free()
	var expires := _bullet(root, ROUND, STRAIGHT, origin, Vector2.DOWN, 0)
	expires._physics_process(8)
	_expect(expires.is_queued_for_deletion(), "stationary bullets still expire")
	var outside := _bullet(root, ROUND, STRAIGHT, Vector2(2, 100), Vector2.LEFT, 95)
	outside._physics_process(0.5)
	_expect(outside.is_queued_for_deletion(), "bullets are removed after leaving the field")
	var invalid := WAVE.duplicate(true) as BulletBehavior
	invalid.actions[0].period = 0
	_expect(not invalid.validation_error().is_empty(), "invalid motion configuration is rejected")
	await process_frame
	await _test_lab()
	if failures.is_empty():
		print("bullet foundations smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_lab() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	await process_frame
	lab.pattern_player.stop()
	lab.clear_bullets()
	await process_frame
	_expect(root.gui_get_focus_owner() == lab.shape_choice, "lab starts with keyboard focus")
	var help: Control = lab.get_node("Controls").get_children().back()
	_expect(help.get_global_rect().end.y <= 360, "all lab instructions fit inside the viewport")
	lab.threat_button.grab_focus()
	await _tap(KEY_ENTER)
	await create_timer(0.25).timeout
	_expect(lab.monitor.sample_count == 0 and "OFF" in lab.status_label.text, "threat toggle stops real sampling and hides stale values")
	lab.restart()
	lab.pattern_player.stop()
	lab.clear_bullets()
	await create_timer(0.25).timeout
	_expect(not lab.threat_button.button_pressed and lab.monitor.sample_count == 0, "restart preserves threat OFF")
	lab.toggle_pause()
	await create_timer(0.55, true).timeout
	_expect(not "--" in lab.fps_label.text, "FPS display updates while gameplay is paused")
	lab.toggle_pause()
	lab.threat_button.grab_focus()
	await _tap(KEY_ENTER)
	await create_timer(0.25).timeout
	_expect(lab.monitor.sample_count > 0, "threat toggle resumes sampling")
	lab.shape_choice.grab_focus()
	await _tap(KEY_DOWN)
	_expect(root.gui_get_focus_owner() == lab.motion_choice, "Down moves to the next setting")
	await _tap(KEY_ENTER)
	_expect(lab.motion_choice.get_popup().visible, "Enter opens the focused setting")
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	_expect(lab.motion_choice.selected == 1, "arrow and Enter select wave motion")
	_expect(root.gui_get_focus_owner() == lab.motion_choice, "selection restores setting focus")
	lab.pattern_player.stop()
	lab.clear_bullets()
	await process_frame
	var field_viewport := lab.world.get_viewport() as SubViewport
	_expect(field_viewport.size == Vector2i(416, 288), "playfield fits the 640x360 lab")
	for appearance in [ROUND, RICE, ORB]:
		for motion in [STRAIGHT, WAVE]:
			lab.hurtbox.is_invincible = false
			lab.set("_invincible_left", 0.0)
			var before: int = lab.hits
			var bullet := _bullet(lab.world, appearance, motion, lab.target.position - Vector2(0, 25), Vector2.DOWN, 95)
			bullet.set_physics_process(true)
			await create_timer(0.5).timeout
			# Waves can move laterally away from a 2px target; aim along the known path.
			if motion == STRAIGHT:
				_expect(lab.hits == before + 1, "each straight appearance hits through the physics hurtbox")
			if is_instance_valid(bullet):
				bullet.queue_free()
			await process_frame
	# Test actual curved collision at a point on the wave, away from its centerline.
	lab.hurtbox.is_invincible = false
	lab.set("_invincible_left", 0.0)
	var target_position: Vector2 = lab.target.position
	var start := target_position - BulletBehaviorState.new(WAVE, Vector2.DOWN, 95, Color.WHITE, 8).position_at(0.3)
	var curved := _bullet(lab.world, ROUND, WAVE, start, Vector2.DOWN, 95)
	var hits_before: int = lab.hits
	curved.set_physics_process(true)
	await create_timer(0.5).timeout
	_expect(lab.hits == hits_before + 1, "wave collision follows the visible path")
	lab._on_hurt(null)
	_expect(lab.hits == hits_before + 1, "invulnerability prevents duplicate hits")
	lab.clear_bullets()
	await process_frame
	var stationary := _bullet(lab.world, ORB, STRAIGHT, Vector2(190.667, 220), Vector2.DOWN, 0)
	var sample: Dictionary = lab.monitor.take_sample_now()
	_expect(sample.relevant_projectile_count == 1 and sample.space > 0, "stationary large bullet still occupies danger space")
	stationary.queue_free()
	await process_frame
	var wave_bullet := _bullet(lab.world, ROUND, WAVE, Vector2(208, 190), Vector2.DOWN, 95)
	sample = lab.monitor.take_sample_now()
	_expect(sample.relevant_projectile_count == 1, "wave segments count as one projectile")
	var frozen := wave_bullet.global_position
	wave_bullet.set_physics_process(true)
	lab.toggle_pause()
	await create_timer(0.1, true).timeout
	_expect(wave_bullet.global_position == frozen, "pause freezes projectiles")
	lab.clear_bullets()
	await process_frame
	_expect(not is_instance_valid(wave_bullet), "clear works while paused")
	lab.shape_choice.select(1)
	lab.motion_choice.select(1)
	lab.restart()
	lab.pattern_player.stop()
	_expect(not paused and lab.hits == 0, "restart resets and resumes")
	lab._toggle_hitboxes(true)
	for bullet in get_nodes_in_group("enemy_projectiles"):
		if bullet is FoundationBullet and not bullet.is_queued_for_deletion():
			_expect(bullet.show_hitbox, "hitbox toggle reaches live projectiles")
	if "--capture" in OS.get_cmdline_user_args() or "--capture-performance" in OS.get_cmdline_user_args():
		lab._toggle_hitboxes(false)
		lab.start_pattern()
		await create_timer(1.8).timeout
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/bullet_lab_performance.png" if "--capture-performance" in OS.get_cmdline_user_args() else "res://artifacts/bullet_lab.png"
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		_expect(root.get_texture().get_image().save_png(path) == OK, "lab capture saved")
	lab.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame
