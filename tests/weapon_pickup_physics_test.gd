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
	var weapon_hud: Node = world.get_node("Layout/RightPanel/Margin/VBox/WeaponLoadoutHud")
	var swap_hint: Label = weapon_hud.get_node("MainSwapHint") as Label
	_expect(swap_hint.text.contains("[Z]"), "main weapon HUD shows the Z swap hint")
	_expect(swap_hint.get_index() < weapon_hud.get_node("MainRow").get_index(), "swap hint is above main slots")
	var loadout: Node = ship.call("get_weapon_loadout")
	var empty_slot: WeaponSlotState = loadout.call("get_auxiliary_slot", 0) as WeaponSlotState
	_expect(not empty_slot.can_upgrade(), "empty auxiliary slots cannot be upgraded")

	var pickup_scene: PackedScene = load("res://pickups/weapon_pickup.tscn")
	var pickup: Area2D = pickup_scene.instantiate() as Area2D
	gameplay.add_child(pickup)
	var weapon_definition: Resource = load("res://resources/weapons/definitions/aux_orbital_barrier.tres")
	pickup.call("setup", weapon_definition, ship.global_position)
	var pickup_label := pickup.get("_label") as Label
	_expect(pickup_label != null, "weapon pickup creates a name label")
	_expect(
		pickup_label.get_parent().is_in_group("weapon_pickup_label_host"),
		"weapon name renders in the native-resolution playfield UI",
	)
	_expect(pickup_label.get_viewport() != pickup.get_viewport(), "weapon name bypasses the pixel viewport")
	_expect(pickup_label.label_settings == null, "weapon name uses the antialiased default font")

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
	var segment: Node2D = barrier.get_node("OrbitRoot/Segment1") as Node2D
	var stats: StatsComponent = segment.get_node("StatsComponent") as StatsComponent
	var hitbox: HitboxComponent = segment.get_node("HitboxComponent") as HitboxComponent
	var hurtbox: HurtboxComponent = segment.get_node("HurtboxComponent") as HurtboxComponent
	stats.health = 0
	await process_frame
	_expect(not segment.is_queued_for_deletion(), "depleted barrier segments remain until weapon clears")
	_expect(not segment.get_node("Core").visible, "depleted barrier segments hide their visuals")
	_expect(hurtbox.is_invincible, "depleted barrier segments disable damage reception")
	_expect(not hitbox.monitoring, "depleted barrier segments stop dealing contact damage")
	_expect(not hurtbox.monitorable, "depleted barrier segments stop blocking attacks")
	_expect(
		int(barrier.call("get_consumable_remaining")) < 0,
		"barrier does not expose charge HUD values",
	)
	_expect(_visible_barrier_cores(barrier) == 2, "destroying one segment leaves two visible cores")

	# Destroy remaining segments → weapon is consumed and slot clears.
	for child in barrier.get_node("OrbitRoot").get_children():
		var other_stats := child.get_node_or_null("StatsComponent") as StatsComponent
		if other_stats != null and other_stats.health > 0:
			other_stats.health = 0
	await process_frame
	await process_frame
	_expect(barrier_slot.is_empty(), "fully destroyed barrier clears the auxiliary slot")

	# Re-equip via another pickup.
	var pickup2: Area2D = pickup_scene.instantiate() as Area2D
	gameplay.add_child(pickup2)
	pickup2.call("setup", weapon_definition, ship.global_position)
	for _index in 5:
		await physics_frame
		await process_frame
	_expect(loadout.call("has_auxiliary_weapon", &"aux_orbital_barrier"), "barrier can be re-equipped after consume")
	barrier_slot = loadout.call("get_auxiliary_slot", 0) as WeaponSlotState
	barrier = barrier_slot.equipped_weapon_instance
	segment = barrier.get_node("OrbitRoot/Segment1") as Node2D
	stats = segment.get_node("StatsComponent") as StatsComponent
	stats.health = 0
	await process_frame
	_expect(_visible_barrier_cores(barrier) == 2, "partial damage before refill")
	loadout.call("refill_auxiliary_weapon", &"aux_orbital_barrier")
	await process_frame
	_expect(_visible_barrier_cores(barrier) == 3, "same-weapon pickup restores all barrier segments")
	_expect(segment.get_node("Core").visible, "refilled segments become visible again")

	var main_pickup: Area2D = pickup_scene.instantiate() as Area2D
	gameplay.add_child(main_pickup)
	var laser_definition: Resource = load("res://resources/weapons/definitions/main_laser.tres")
	main_pickup.call("setup", laser_definition, ship.global_position)
	for _index in 5:
		await physics_frame
		await process_frame
	_expect(loadout.call("get_main_weapon_id") == &"main_blaster", "new main weapon stays in firing slot")
	_expect(loadout.call("get_reserve_weapon_id") == &"main_laser", "new main weapon fills the reserve slot")
	_expect(not is_instance_valid(main_pickup), "main weapon pickup is consumed")
	_expect(loadout.call("swap_main_and_reserve"), "z-swap exchanges main and reserve")
	_expect(loadout.call("get_main_weapon_id") == &"main_laser", "swap moves reserve into the firing slot")
	_expect(loadout.call("get_reserve_weapon_id") == &"main_blaster", "swap stows previous main into reserve")

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


func _visible_barrier_cores(barrier: Node) -> int:
	var count := 0
	for child in barrier.get_node("OrbitRoot").get_children():
		var core := child.get_node_or_null("Core") as CanvasItem
		if core != null and core.visible:
			count += 1
	return count
