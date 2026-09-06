extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	root.add_child(gameplay)
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var offer_controller := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var generator := gameplay.get_node("EnemyGenerator")
	var elite_controller := gameplay.get_node("ThreatEliteController") as ThreatEliteController
	var enemy_registry := gameplay.get_node("EnemyAugmentRegistry") as EnemyAugmentRegistry
	progression.set_process(false)
	generator.spawn_timer.stop()

	progression._process(60.0)
	_expect(progression.get_threat_level() == 1, "Threat stays at 1 until the first elite is defeated")
	_expect(progression.elite_gate_active, "first timer fill opens the Threat 2 elite gate")
	_expect(generator.normal_spawns_paused, "elite gate pauses normal encounters")
	_expect(progression.pending_offers.is_empty(), "enemy augment is not queued before elite defeat")
	var elite := elite_controller.active_elite
	_expect(is_instance_valid(elite), "Threat 2 spawns one tracked elite")
	if is_instance_valid(elite):
		_expect(elite.is_elite and elite.is_in_group("elites"), "spawned enemy is marked elite")
		_expect(elite.spawn_id == &"threat_elite", "elite uses the dedicated encounter id")
		_expect(elite.stats_component.health == 180, "first elite starts with 180 HP")
		var shoot := elite.get_node("EnemyShootComponent") as EnemyShootComponent
		var barrage := elite.get_node("EliteBarrageShootComponent") as EnemyShootComponent
		_expect(
			is_equal_approx(shoot.fire_interval, 1.25)
			and shoot.burst_count == 2
			and shoot.shot_count == 1
			and shoot.use_actor_forward_direction,
			"elite periodically fires two forward shots",
		)
		_expect(
			is_equal_approx(barrage.fire_interval, 7.5)
			and barrage.burst_count == 12
			and is_equal_approx(barrage.burst_interval, 0.09)
			and not barrage.use_actor_forward_direction,
			"elite periodically pours aimed fire toward the player",
		)
		_expect(
			elite.movement_controller.sequence.resource_path.ends_with("elite_entry_patrol.tres"),
			"elite enters the upper band and patrols",
		)

	progression._process(90.0)
	_expect(progression.get_threat_level() == 1, "Threat does not advance or accumulate during elite combat")
	_expect(get_nodes_in_group("elites").size() == 1, "elite gate never duplicates the active elite")
	if is_instance_valid(elite):
		elite.stats_component.health = 0
		_expect(paused, "elite defeat pauses combat for the bullet cancel reward")
		_expect(progression.bullet_cancel_reward_active, "elite reward locks player augment input")
		_expect(not offer_controller.is_offer_active, "enemy offer waits for the XP vacuum")
		await elite_controller.elite_defeated
	_expect(progression.get_threat_level() == 2, "elite defeat advances to Threat 2")
	_expect(progression.current_experience == 1, "elite guaranteed XP is vacuumed before its offer")
	_expect(not progression.bullet_cancel_reward_active, "reward lock clears after the XP vacuum")
	_expect(progression.elite_gate_active, "gate remains active through the reward offer")
	_expect(offer_controller.is_offer_active, "elite defeat requests an augment offer")
	_expect(
		offer_controller.active_offer_type == AugmentOfferController.OfferType.ENEMY,
		"elite reward is the enemy augment offer",
	)
	await process_frame
	await process_frame
	_expect(offer_controller.selection_ui.visible, "enemy offer UI opens while reward pause stays active")
	_expect(enemy_registry.get_active_augments().is_empty(), "enemy stays unchanged until a choice is applied")

	var chosen := offer_controller.enemy_augment_pool[0]
	enemy_registry.add_augment(chosen)
	offer_controller.call("_complete_offer", AugmentOfferController.OfferType.ENEMY)
	_expect(enemy_registry.get_stack_count(chosen.augment_id) == 1, "enemy augment applies after elite defeat")
	_expect(not progression.elite_gate_active, "enemy offer completion closes the elite gate")
	_expect(not generator.normal_spawns_paused, "normal encounters resume after the enemy offer")

	progression._process(60.0)
	_expect(progression.get_threat_level() == 2, "the next timer fill waits for the next elite defeat")
	_expect(progression.elite_gate_active, "Threat 3 opens a fresh elite gate")
	var next_elite := elite_controller.active_elite
	_expect(is_instance_valid(next_elite), "Threat 3 spawns a new elite")
	if is_instance_valid(next_elite):
		_expect(next_elite.stats_component.health == 288, "Threat 3 elite scales before health augment")

	gameplay.queue_free()
	await process_frame
	if failures.is_empty():
		print("threat elite progression smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("threat elite progression smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
