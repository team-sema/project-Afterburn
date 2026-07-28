extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var progression: Node = gameplay.get_node("AugmentProgressionController")
	var offer_controller: Node = gameplay.get_node("AugmentOfferController")

	_expect(progression.level == 1, "run starts at level 1")
	_expect(progression.experience_required == 5, "first level requires 5 XP")

	var ship: Node2D = gameplay.get_node("Ship") as Node2D
	var collector: Area2D = ship.get_node("ExperienceCollector") as Area2D
	var orb_scene: PackedScene = load("res://pickups/experience_orb.tscn")
	var orb: Area2D = orb_scene.instantiate() as Area2D
	gameplay.add_child(orb)
	orb.setup(5, collector.global_position + Vector2(60.0, 0.0))
	for _index in 2:
		await physics_frame
		await process_frame
	_expect(progression.current_experience == 0, "orb outside the collector radius is not collected")
	orb.global_position = collector.global_position + Vector2(20.0, 0.0)
	var collected_amount: int = await orb.collected

	_expect(collected_amount == 5, "collector receives the orb's XP amount")
	_expect(progression.level == 2, "collecting 5 XP levels the player")
	_expect(progression.current_experience == 0, "spent XP is removed after level-up")
	_expect(progression.experience_required == 7, "next level requires 7 XP")
	_expect(offer_controller.is_offer_active, "level-up requests an augment offer")
	_expect(
		offer_controller.active_offer_type == AugmentOfferController.OfferType.PLAYER,
		"level-up requests a player offer",
	)

	progression._process(60.0)
	_expect(progression.enemy_augment_tier == 1, "60 seconds reaches enemy augment tier 1")
	_expect(progression.pending_offers.size() == 1, "enemy offer waits behind an active player offer")
	if not progression.pending_offers.is_empty():
		_expect(
			progression.pending_offers.front() == AugmentOfferController.OfferType.ENEMY,
			"queued offer is an enemy offer",
		)

	if failures.is_empty():
		print("augment progression smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("augment progression smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
