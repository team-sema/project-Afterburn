extends SceneTree

var failures := PackedStringArray()
var hurt_count := 0
var seen := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(320, 280)
	world.add_child(player)
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 2.0
	hurtbox.add_child(shape)
	player.add_child(hurtbox)
	hurtbox.hurt.connect(func(_hitbox): hurt_count += 1)
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	var elite := (load("res://enemies/elite_bomb.tscn") as PackedScene).instantiate() as Enemy
	elite.augment_registry = registry
	elite.position = Vector2(320, -30)
	world.add_child(elite)
	await process_frame
	await physics_frame
	var attack = elite.get_node("EnemyShootComponent")
	attack.set_process(false)
	_expect(elite.is_elite, "elite bomb is marked elite")
	_expect(not elite.get_node("EliteAimCone").visible, "mine thrower hides the aim cone")
	attack._process(1.0)
	_expect(attack.mines.is_empty(), "entry does not throw mines")
	elite.position.y = 72
	elite.movement_controller.update_movement(0.1)
	attack._process(0.01)
	_expect(attack.phase == attack.Phase.READY, "patrol begins the ready delay")
	attack._process(0.5)
	_expect(attack.mines.is_empty(), "ready delay does not throw")
	attack._process(0.1)
	_expect(attack.mines.size() == 1, "first mine is thrown after the ready delay")
	attack._process(0.3)
	attack._process(0.3)
	_expect(attack.mines.size() == 3, "one cycle throws three mines")
	_expect(attack.phase == attack.Phase.RECOVERY, "three mines enter recovery")
	var mines: Array = attack.mines.duplicate()
	for mine in mines:
		mine.set_process(false)
	if mines.size() == 3:
		_expect(mines[0].landing_position.is_equal_approx(Vector2(320, 280)), "first mine lands on the player")
		_expect(mines[1].landing_position.is_equal_approx(Vector2(248, 280)), "second mine lands left")
		_expect(mines[2].landing_position.is_equal_approx(Vector2(392, 280)), "third mine lands right")
		_expect(mines[0].global_position.is_equal_approx(elite.global_position), "mines start at the thrower")
		mines[0]._process(0.3)
		_expect(not mines[0].landed, "mine is still in flight")
		mines[0]._process(0.31)
		_expect(mines[0].landed and mines[0].global_position.is_equal_approx(Vector2(320, 280)), "mine lands after 0.6s")
		_expect(mines[0].is_flashing(), "landed mine starts flashing")
		mines[0]._process(1.45)
		_expect(not mines[0].is_queued_for_deletion(), "mine waits for the full warning")
		mines[0]._process(0.06)
		_expect(mines[0].is_queued_for_deletion(), "mine detonates after 1.5s")
		_expect(get_nodes_in_group("enemy_projectiles").size() == 10, "detonation fires a ten-bullet ring")
		_expect(hurt_count == 1, "blast hurts the player inside the radius")
		_expect(attack.mines.size() == 2, "detonated mine leaves tracking")
		mines[1]._process(2.2)
		_expect(mines[1].is_queued_for_deletion(), "second mine detonates")
		_expect(hurt_count == 1, "blast outside the radius does not hurt")
	# Ring bullets spawned on the player hurtbox would be consumed by it.
	hurtbox.free()
	player.position = Vector2(30, 355)
	var clamped: Vector2 = attack._landing_point(1)
	_expect(clamped.is_equal_approx(Vector2(24, 336)), "landing points stay inside the screen margin")
	player.position = Vector2(320, 280)
	attack._process(2.3)
	_expect(attack.mines_thrown == 3, "recovery does not throw")
	_new_bullets()
	attack._process(0.11)
	_expect(attack.phase == attack.Phase.FIELD_WARNING and attack.mines_thrown == 3, "pattern B follows the mine cycle")
	var anchor := elite.get_node("Anchor") as Node2D
	_expect(anchor.modulate == attack.WARNING_COLOR, "body flashes before the minefield")
	_expect(not elite.movement_controller.is_processing(), "minefield warning stops patrol")
	attack._process(0.55)
	_expect(attack.get_volleys_fired() == 0, "warning lasts 0.6s")
	attack._process(0.06)
	await process_frame
	var field := _new_bullets()
	_expect(field.size() == 24, "minefield fires three rings of eight")
	_expect(anchor.modulate == Color.WHITE, "body flash clears when the field fires")
	if field.size() == 24:
		var inner: FoundationBullet = field[0]
		var outer: FoundationBullet = field[16]
		var inner_state: BulletBehaviorState = inner.behavior_state
		_expect(is_equal_approx(inner_state.velocity_at(0.0).length(), 70.0) and is_equal_approx(outer.behavior_state.velocity_at(0.0).length(), 140.0), "layers leave at 70 and 140")
		_expect(inner_state.velocity_at(0.0).normalized().is_equal_approx(attack.field_direction), "first layer is centred on the player")
		_expect(inner_state.velocity_at(1.25).length() < 0.01 and inner_state.velocity_at(2.1).length() < 0.01, "orbs float in place")
		var origin: Vector2 = inner._origin
		_advance(inner, 1.25)
		_expect(absf(inner.global_position.distance_to(origin) - 56.0) < 2.0, "inner layer stops about 56px out")
		_advance(inner, 2.6)
		_expect(is_equal_approx(inner.visual_scale, 1.35) and inner.hitbox_scale == 1.0, "orbs swell without growing their hitbox")
		_expect(inner.render_tint.g > 0.9, "orbs flush white as the warning")
		var twist := rad_to_deg(inner_state.velocity_at(0.0).angle_to(inner_state.velocity_at(3.7)))
		_expect(absf(twist - 30.0) < 0.5 and absf(inner_state.velocity_at(3.7).length() - 120.0) < 0.5, "first burst twists +30 degrees outward")
	attack._process(1.19)
	_expect(attack.phase == attack.Phase.FIELD, "second burst waits 1.2s")
	attack._process(0.02)
	await process_frame
	var second := _new_bullets()
	_expect(second.size() == 24, "second burst repeats the field")
	if second.size() == 24:
		var state: BulletBehaviorState = second[0].behavior_state
		_expect(state.velocity_at(0.0).normalized().is_equal_approx(attack.field_direction.rotated(deg_to_rad(22.5))), "second burst is rotated 22.5 degrees")
		_expect(absf(rad_to_deg(state.velocity_at(0.0).angle_to(state.velocity_at(3.7))) + 30.0) < 0.5, "second burst twists the other way")
	_expect(attack.phase == attack.Phase.RECOVERY and not attack.next_is_field, "minefield returns to pattern A")
	_expect(elite.movement_controller.is_processing(), "patrol resumes after the field")
	attack._process(2.39)
	_expect(attack.mines_thrown == 3, "recovery after the field does not throw")
	attack._process(0.02)
	_expect(attack.mines_thrown == 4, "mine cycle resumes after 2.4s")
	attack.apply_action_rate_multiplier(10.0)
	attack._process(0.3)
	_expect(attack.mines_thrown == 5, "base throw interval elapsed")
	_expect(absf(attack._remaining - 0.15) < 0.05, "action rate keeps the minimum throw interval")
	attack._process(0.15)
	_expect(attack.mines_thrown == 6 and attack.phase == attack.Phase.RECOVERY, "action-rate cycle completes")
	_expect(absf(attack._remaining - 1.2) < 0.05, "action rate keeps the minimum recovery")
	attack._process(attack._remaining + 0.01)
	_expect(attack.phase == attack.Phase.FIELD_WARNING, "action-rate cycle still alternates")
	attack._process(0.6)
	_expect(attack.phase == attack.Phase.FIELD, "action rate keeps the full body warning")
	attack._process(0.79)
	_expect(attack.phase == attack.Phase.FIELD, "action rate keeps the minimum field gap")
	attack._process(0.02)
	_expect(attack.phase == attack.Phase.RECOVERY, "second burst fires after 0.8s")
	attack.next_is_field = true
	attack._process(attack._remaining + 0.61)
	_expect(attack.barrage_player.running, "field is playing before the elite dies")
	_expect(attack.get_ring_count() == 10, "base ring count is ten")
	attack.shot_count += 2
	_expect(attack.get_ring_count() == 12, "volume augment adds ring bullets")
	attack.apply_arming_rate_multiplier(1.5)
	_expect(is_equal_approx(attack.get_arm_duration(), 1.0), "fast fuse shortens mine arming")
	attack.apply_arming_rate_multiplier(3.0)
	_expect(is_equal_approx(attack.get_arm_duration(), 0.8), "mine arming keeps its minimum warning")
	var live: Array = attack.mines.duplicate()
	var bullets := get_nodes_in_group("enemy_projectiles").size()
	_expect(not live.is_empty(), "mines are pending before the elite dies")
	elite.stats_component.health = 0
	attack._process(0.1)
	_expect(not attack.barrage_player.running, "elite death stops the minefield")
	await process_frame
	var removed := true
	for mine in live:
		removed = removed and not is_instance_valid(mine)
	_expect(removed, "elite death removes pending mines")
	_expect(get_nodes_in_group("enemy_projectiles").size() == bullets, "removed mines do not fire rings")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("elite mine smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_bullets() -> Array:
	var result := []
	for bullet in get_nodes_in_group("enemy_projectiles"):
		if not seen.has(bullet):
			seen[bullet] = true
			result.append(bullet)
	return result


func _advance(bullet: Node, age: float) -> void:
	while bullet.age < age - 0.0001:
		bullet._physics_process(minf(1.0 / 60.0, age - bullet.age))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
