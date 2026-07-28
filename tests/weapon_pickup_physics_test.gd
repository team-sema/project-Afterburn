extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var ship: Node2D = gameplay.get_node("Ship") as Node2D
	var loadout: Node = ship.call("get_weapon_loadout")
	var empty_slot: WeaponSlotState = loadout.call("get_auxiliary_slot", 0) as WeaponSlotState
	_expect(not empty_slot.can_upgrade(), "empty auxiliary slots cannot be upgraded")

	var pickup_scene: PackedScene = load("res://pickups/weapon_pickup.tscn")
	var pickup: Area2D = pickup_scene.instantiate() as Area2D
	gameplay.add_child(pickup)
	var weapon_definition: Resource = load("res://resources/weapons/definitions/aux_orbital_barrier.tres")
	pickup.call("setup", weapon_definition, ship.global_position)

	for _index in 5:
		await physics_frame
		await process_frame

	_expect(
		loadout.call("has_auxiliary_weapon", &"aux_orbital_barrier"),
		"orbital barrier pickup equips the auxiliary weapon",
	)
	var barrier_slot: WeaponSlotState = loadout.call("get_auxiliary_slot", 0) as WeaponSlotState
	_expect(barrier_slot.can_upgrade(), "equipped auxiliary slots can be upgraded")

	var barrier: Node = barrier_slot.equipped_weapon_instance
	barrier.set("segment_regeneration_time", 0.05)
	var segment: Node2D = barrier.get_node("OrbitRoot/Segment1") as Node2D
	var stats: StatsComponent = segment.get_node("StatsComponent") as StatsComponent
	var hitbox: HitboxComponent = segment.get_node("HitboxComponent") as HitboxComponent
	var hurtbox: HurtboxComponent = segment.get_node("HurtboxComponent") as HurtboxComponent
	stats.health = 0
	_expect(not segment.is_queued_for_deletion(), "depleted barrier segments remain in the scene")
	_expect(segment.modulate.a < 1.0, "depleted barrier segments become translucent")
	_expect(hurtbox.is_invincible, "depleted barrier segments disable damage reception")
	await process_frame
	_expect(not hitbox.monitoring, "depleted barrier segments stop dealing contact damage")
	_expect(not hurtbox.monitorable, "depleted barrier segments stop blocking attacks")

	await create_timer(0.1).timeout
	await process_frame
	_expect(stats.health == 2, "barrier segment health regenerates")
	_expect(is_equal_approx(segment.modulate.a, 1.0), "regenerated barrier segments become opaque")
	_expect(not hurtbox.is_invincible, "regenerated barrier segments receive damage again")
	_expect(hitbox.monitoring, "regenerated barrier segments deal contact damage again")
	_expect(hurtbox.monitorable, "regenerated barrier segments block attacks again")

	var main_pickup: Area2D = pickup_scene.instantiate() as Area2D
	gameplay.add_child(main_pickup)
	var laser_definition: Resource = load("res://resources/weapons/definitions/main_laser.tres")
	main_pickup.call("setup", laser_definition, ship.global_position)
	for _index in 5:
		await physics_frame
		await process_frame
	var acquisition_controller: Node = gameplay.get_node("WeaponAcquisitionController")
	var confirm_ui: CanvasLayer = acquisition_controller.get("confirm_ui") as CanvasLayer
	_expect(confirm_ui.visible, "different main weapon pickup opens the replacement confirmation")
	confirm_ui.call("_on_cancel")
	await process_frame
	await process_frame
	_expect(loadout.call("get_main_weapon_id") == &"main_blaster", "declining replacement keeps the current main weapon")
	_expect(not is_instance_valid(main_pickup), "declined main weapon pickup is removed")

	if failures.is_empty():
		print("weapon pickup physics test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon pickup physics test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
