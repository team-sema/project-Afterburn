extends SceneTree

const LAB := preload("res://labs/bullet/presets/curved_laser_lab.tscn")
const LASER := preload("res://projectiles/curved_laser.tscn")
var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	await process_frame
	_expect(lab.shape_choice.selected == 4 and lab.pattern_choice.selected == 4, "direct-entry scene starts with the laser flower")
	lab.pattern_player.stop()
	_expect(get_nodes_in_group("enemy_projectiles").size() == 12, "flower emits twelve laser objects, not individual trail bullets")
	lab.clear_bullets()
	await process_frame
	var laser := LASER.instantiate() as CurvedLaser
	laser.position = Vector2(208, 85)
	lab.world.add_child(laser)
	laser.launch(Vector2.DOWN, 90)
	laser.set_physics_process(false)
	laser._physics_process(1.1)
	var head := laser.global_position
	lab.target.position = laser.position_at(0.5)
	_expect(head.distance_to(lab.target.position) > 45, "test contact is far behind the head")
	await physics_frame
	await physics_frame
	await process_frame
	laser.get_node("HitboxComponent").apply_contacts()
	_expect(lab.hits == 1, "body capsules inflict a real physics hit away from the head")
	laser.get_node("HitboxComponent").apply_contacts()
	_expect(lab.hits == 1, "overlapping segments and repeated checks respect invulnerability")
	_expect(not laser.is_queued_for_deletion(), "laser persists after contact")
	await create_timer(0.7).timeout
	await physics_frame
	await physics_frame
	laser.get_node("HitboxComponent").apply_contacts()
	_expect(lab.hits == 2, "body can hit again after immunity expires without leaving the laser")
	laser._physics_process(0.6)
	var path := laser.get_predicted_path(0.8)
	_expect(path[0].distance_to(laser.position_at(0.3)) < 0.001, "path prediction includes the current tail")
	_expect(path[path.size() - 1].distance_to(laser.position_at(2.5)) < 0.001, "path prediction includes the future head")
	lab.safety_meter.measure()
	_expect(lab.safety_meter.relevant_projectile_count <= 1, "body segments never inflate the bullet count")
	laser.show_hitbox = true
	lab.toggle_pause()
	var frozen := laser.age
	laser.set_physics_process(true)
	await create_timer(0.1, true).timeout
	_expect(laser.age == frozen, "pause freezes the entire laser")
	lab.clear_bullets()
	await process_frame
	_expect(not is_instance_valid(laser), "clear removes the entire laser while paused")
	lab.toggle_pause()
	var straight := LASER.instantiate() as CurvedLaser
	straight.turn_degrees = 0
	straight.position = Vector2(208, 200)
	lab.world.add_child(straight)
	straight.launch(Vector2.DOWN, 90)
	straight.set_physics_process(false)
	straight._physics_process(1.1)
	_expect(straight.global_position.y > 288 and not straight.is_queued_for_deletion(), "offscreen head retains its onscreen body")
	straight._physics_process(2)
	_expect(straight.is_queued_for_deletion(), "laser is removed when the entire body exits")
	await process_frame
	lab.shape_choice.select(0)
	lab._shape_changed(0)
	_expect(lab.shape_choice.selected == 0 and lab.motion_choice.selected == 0, "ordinary bullets remain selectable after the flower")
	lab.shape_choice.select(4)
	lab._shape_changed(4)
	lab.motion_choice.select(3)
	lab._motion_changed(3)
	await process_frame
	for bullet in get_nodes_in_group("enemy_projectiles"):
		if bullet is CurvedLaser and not bullet.is_queued_for_deletion():
			_expect(bullet.behavior_state.sample(0.5).heading < 0, "left turn behavior is applied")
	var help: Control = lab.get_node("Controls").get_children().back()
	_expect(help.get_global_rect().end.y <= 360, "laser controls fit the viewport")
	if "--capture" in OS.get_cmdline_user_args():
		lab.motion_choice.select(2)
		lab.restart()
		await create_timer(1.55).timeout
		lab.toggle_pause()
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png("res://artifacts/curved_laser_lab.png") == OK, "rendered flower screenshot saved")
	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("curved laser smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
