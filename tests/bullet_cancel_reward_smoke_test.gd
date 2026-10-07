extends SceneTree

const STEP := 1.0 / 60.0

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_happy_path()
	await _test_offscreen_bullets_are_discarded()
	await _test_distant_orb_arrives_within_budget()
	await _test_cap_collects_stragglers()
	await _test_freed_collector_during_vacuum()
	await _test_ship_death_skips_elite_offer()
	if failures.is_empty():
		print("bullet cancel reward smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("bullet cancel reward smoke test: %s" % failure)
	quit(1)


func _make_gameplay() -> Node:
	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	root.add_child(gameplay)
	(gameplay.get_node("AugmentProgressionController") as AugmentProgressionController).set_process(false)
	gameplay.get_node("EnemyGenerator").spawn_timer.stop()
	return gameplay


func _free_gameplay(gameplay: Node) -> void:
	paused = false
	if is_instance_valid(gameplay):
		gameplay.queue_free()
	await process_frame


func _make_enemy_bullet(gameplay: Node, at: Vector2) -> Node2D:
	var bullet := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	gameplay.add_child(bullet)
	bullet.global_position = at
	return bullet


func _make_orb(gameplay: Node, amount: int, at: Vector2) -> ExperienceOrb:
	var orb := (load("res://pickups/experience_orb.tscn") as PackedScene).instantiate() as ExperienceOrb
	gameplay.add_child(orb)
	orb.setup(amount, at)
	return orb


func _test_happy_path() -> void:
	var gameplay := _make_gameplay()
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var reward := gameplay.get_node("BulletCancelRewardController") as BulletCancelRewardController
	var collector := gameplay.get_node("Ship/ExperienceCollector") as Area2D

	_make_orb(gameplay, 4, collector.global_position + Vector2(90.0, -80.0))
	_make_enemy_bullet(gameplay, collector.global_position + Vector2(-70.0, -120.0))
	_make_enemy_bullet(gameplay, collector.global_position + Vector2(80.0, -140.0))
	var deferred_enemy_bullet := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	deferred_enemy_bullet.global_position = collector.global_position + Vector2(110.0, -100.0)
	var player_bullet := (load("res://projectiles/player_blaster.tscn") as PackedScene).instantiate() as Node2D
	gameplay.add_child(player_bullet)
	player_bullet.global_position = collector.global_position + Vector2(0.0, -60.0)
	for preset in ["round", "orb"]:
		var foundation := (load("res://projectiles/foundation_bullet.tscn") as PackedScene).instantiate() as FoundationBullet
		foundation.appearance = load("res://resources/projectiles/%s.tres" % preset)
		foundation.behavior = load("res://resources/projectiles/wave_behavior.tres")
		gameplay.add_child(foundation)
		foundation.global_position = collector.global_position + Vector2(30, -100)
		foundation.launch(Vector2.DOWN, 95)

	var laser := (load("res://projectiles/curved_laser.tscn") as PackedScene).instantiate() as CurvedLaser
	gameplay.add_child(laser)
	laser.global_position = collector.global_position + Vector2(0, -120)
	laser.launch(Vector2.DOWN, 90)
	laser._physics_process(0.8)
	gameplay.add_child.call_deferred(deferred_enemy_bullet)
	var converted_count := await reward.collect_projectiles_and_vacuum()
	await process_frame

	_expect(not paused, "the reward never pauses the tree")
	_expect(converted_count == 6, "each on-screen projectile and whole curved laser becomes one XP orb (%d)" % converted_count)
	_expect(reward.last_discarded_count == 0, "no on-screen projectile is discarded")
	_expect(get_nodes_in_group("enemy_projectiles").is_empty(), "converted enemy projectiles are cleared")
	_expect(not is_instance_valid(deferred_enemy_bullet), "same-frame deferred enemy projectiles are cleared")
	_expect(is_instance_valid(player_bullet), "player projectiles are preserved")
	_expect(progression.current_experience == 10, "existing XP and converted bullets are collected (%d)" % progression.current_experience)
	_expect(not reward.is_active, "reward sequence finishes after every attracted orb is collected")
	await _free_gameplay(gameplay)


func _test_offscreen_bullets_are_discarded() -> void:
	var gameplay := _make_gameplay()
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var reward := gameplay.get_node("BulletCancelRewardController") as BulletCancelRewardController
	var rect := reward.get_conversion_rect()

	var inside := _make_enemy_bullet(gameplay, rect.get_center())
	var edge := _make_enemy_bullet(gameplay, Vector2(rect.position.x + 2.0, rect.get_center().y))
	var above := _make_enemy_bullet(gameplay, Vector2(rect.get_center().x, rect.position.y - 300.0))
	var beside := _make_enemy_bullet(gameplay, Vector2(rect.end.x + 120.0, rect.get_center().y))
	var converted_count := await reward.collect_projectiles_and_vacuum()
	await process_frame

	_expect(converted_count == 2, "only bullets inside VisibleRect + margin become orbs (%d)" % converted_count)
	_expect(reward.last_discarded_count == 2, "off-screen bullets are counted as discarded (%d)" % reward.last_discarded_count)
	for bullet in [inside, edge, above, beside]:
		_expect(not is_instance_valid(bullet), "every enemy bullet is cancelled, on screen or not")
	_expect(progression.current_experience == 2, "off-screen bullets give no XP (%d)" % progression.current_experience)
	await _free_gameplay(gameplay)


func _test_distant_orb_arrives_within_budget() -> void:
	var gameplay := _make_gameplay()
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var budget_steps := 0

	# Still collector, orb 900 px off screen: must land inside the budget.
	var still_collector := Area2D.new()
	gameplay.add_child(still_collector)
	still_collector.global_position = Vector2(320, 300)
	var far_orb := _make_orb(gameplay, 3, still_collector.global_position + Vector2(0, -900))
	far_orb.set_process(false)
	budget_steps = ceili(far_orb.forced_arrival_time / STEP) + 1
	_expect(far_orb.start_forced_attraction(still_collector), "orb accepts forced attraction")
	var steps := 0
	while is_instance_valid(far_orb) and not far_orb.is_queued_for_deletion() and steps < 600:
		far_orb._process(STEP)
		steps += 1
	_expect(steps <= budget_steps, "a 900 px orb arrives within the forced budget (%d / %d steps)" % [steps, budget_steps])
	_expect(progression.current_experience == 3, "the distant orb pays its XP")

	# Collector fleeing at 300 px/s (faster than the 190 px/s floor) is still caught.
	var moving_collector := Area2D.new()
	gameplay.add_child(moving_collector)
	moving_collector.global_position = Vector2(320, 300)
	var chase_orb := _make_orb(gameplay, 1, moving_collector.global_position + Vector2(-400, -250))
	chase_orb.set_process(false)
	chase_orb.start_forced_attraction(moving_collector)
	steps = 0
	while is_instance_valid(chase_orb) and not chase_orb.is_queued_for_deletion() and steps < 600:
		moving_collector.global_position += Vector2(300.0 * STEP, 0)
		chase_orb._process(STEP)
		steps += 1
	_expect(steps <= budget_steps, "an orb catches a ship moving faster than the floor speed (%d / %d steps)" % [steps, budget_steps])

	# A close orb flies at least at the floor speed, so it lands early.
	var near_orb := _make_orb(gameplay, 1, still_collector.global_position + Vector2(0, -40))
	near_orb.set_process(false)
	near_orb.start_forced_attraction(still_collector)
	steps = 0
	while is_instance_valid(near_orb) and not near_orb.is_queued_for_deletion() and steps < 600:
		near_orb._process(STEP)
		steps += 1
	_expect(steps <= ceili(40.0 / near_orb.maximum_attraction_speed / STEP) + 1, "a near orb keeps the 190 px/s floor (%d steps)" % steps)
	await _free_gameplay(gameplay)


func _test_cap_collects_stragglers() -> void:
	var gameplay := _make_gameplay()
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var reward := gameplay.get_node("BulletCancelRewardController") as BulletCancelRewardController
	var collector := gameplay.get_node("Ship/ExperienceCollector") as Area2D
	reward.collect_cap_time = 0.15
	# A deliberately slow orb: 5 s budget from 3000 px away would take seconds.
	var slow_orb := _make_orb(gameplay, 5, collector.global_position + Vector2(0, -3000))
	slow_orb.forced_arrival_time = 5.0
	var started_ms := Time.get_ticks_msec()
	await reward.collect_projectiles_and_vacuum()
	var elapsed := (Time.get_ticks_msec() - started_ms) / 1000.0
	await process_frame

	_expect(not reward.is_active, "the reward ends once the cap passes")
	_expect(elapsed < 1.5, "the cap ends the wait long before the slow orb would land (%.2f s)" % elapsed)
	_expect(not is_instance_valid(slow_orb), "the cap collects the straggler")
	_expect(progression.current_experience == 5, "the straggler's XP is still paid (%d)" % progression.current_experience)
	await _free_gameplay(gameplay)


func _test_freed_collector_during_vacuum() -> void:
	# Elite reward awaits one frame before vacuum. If the ship (and its collector)
	# is freed in that window, typed Area2D args used to error at the call site.
	var gameplay := _make_gameplay()
	var reward := gameplay.get_node("BulletCancelRewardController") as BulletCancelRewardController
	var ship := gameplay.get_node("Ship") as Node

	var orb := _make_orb(gameplay, 2, Vector2(40, 40))
	# Vacuum awaits one process frame first; free the ship in that gap.
	ship.queue_free()
	var converted_count := await reward.collect_projectiles_and_vacuum()
	await process_frame

	_expect(converted_count >= 0, "freed collector does not crash the vacuum coroutine")
	_expect(not reward.is_active, "vacuum ends cleanly after collector is freed")
	_expect(not reward.has_live_collector(), "the controller reports the lost collector")
	_expect(not is_instance_valid(orb) or not orb.start_forced_attraction(null), "orb rejects a null collector")
	await _free_gameplay(gameplay)


func _test_ship_death_skips_elite_offer() -> void:
	var gameplay := _make_gameplay()
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var offer_controller := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var elite_controller := gameplay.get_node("ThreatEliteController") as ThreatEliteController
	var reward := gameplay.get_node("BulletCancelRewardController") as BulletCancelRewardController
	_expect(progression.request_elite_milestone(), "test opens an elite gate")
	var elite := elite_controller.active_elite
	_expect(is_instance_valid(elite), "elite spawns for the ship-death case")
	if is_instance_valid(elite):
		elite.stats_component.health = 0
		_expect(not paused, "elite defeat keeps the game running")
		_expect(progression.bullet_cancel_reward_active, "player augment input locks during the reward")
		gameplay.get_node("Ship").queue_free()
		for i in 4:
			await process_frame
		_expect(not reward.is_active, "the reward stops when the ship dies")
		_expect(not progression.bullet_cancel_reward_active, "the reward lock clears after the ship dies")
		_expect(not offer_controller.is_offer_active, "no enemy offer opens for a dead ship")
		_expect(not paused, "a dead ship never leaves the tree paused")
	await _free_gameplay(gameplay)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
