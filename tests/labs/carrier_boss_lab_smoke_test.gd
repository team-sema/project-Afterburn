extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var lab := preload("res://labs/bosses/carrier/carrier_boss_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var boss: Node2D = lab.boss
	var turrets: Array = boss.parts.filter(func(part): return part.mode == 0)
	var hangars: Array = boss.parts.filter(func(part): return part.mode == 1)
	var escorts: Array = boss.parts.filter(func(part): return part.mode == 4)
	var engines: Array = boss.parts.filter(func(part): return part.mode == 5)
	var bridge: Node2D = boss.parts[-1]
	check(turrets.size() == 6 and hangars.size() == 2 and escorts.size() == 4, "Six turrets, two hangars and four deck escorts")
	check(engines.size() == 2 and engines.all(func(part): return not part.required) and boss.parts.size() == 15, "Stern engines are the only optional targets")
	check(boss.health == 1920 and boss.maximum == 1920 and lab.bar.max_value == 1920, "Full encounter HP includes only required parts of every section")
	bridge.take_damage(9999)
	check(boss.health == 1920, "Offscreen bridge cannot take damage")
	# Layout guard: no part's art, barrel sweep or deck rails may sit on another part.
	var overlaps: Array[String] = []
	for i in boss.parts.size():
		for j in range(i + 1, boss.parts.size()):
			var a: Node2D = boss.parts[i]
			var b: Node2D = boss.parts[j]
			var rect_a: Rect2 = a.footprint()
			var rect_b: Rect2 = b.footprint()
			rect_a.position += a.position
			rect_b.position += b.position
			if rect_a.intersects(rect_b): overlaps.append("%d/%d" % [i, j])
	check(overlaps.is_empty(), "Carrier parts keep clear footprints: " + ", ".join(overlaps))
	var mount_offset: Vector2 = boss.parts[0].global_position - boss.global_position
	var entry_y: float = boss.parts[0].global_position.y
	await create_timer(1.2).timeout
	check(boss.transitioning and not boss.parts[0].active, "Mounted turret remains combat-disabled during entry")
	check(boss.parts[0].global_position.y > entry_y, "Turret descends before activation")
	check((boss.parts[0].global_position - boss.global_position).is_equal_approx(mount_offset), "Turret preserves its mount offset while hull moves")
	check(boss.parts[0].visual.modulate == Color.WHITE, "Intact turret remains visible during entry")
	check(boss.parts[0].deploy < 0.5 and hangars[0].deploy == 0.0, "Guns stay stowed until their section unfolds")
	await create_timer(1.2).timeout
	check(boss.phase == 0 and not boss.transitioning, "Intro arrives at aft defense")
	check(is_equal_approx(boss.parts[0].deploy, 1.0) and hangars[0].deploy == 0.0, "Only the arriving section deploys its hardware")
	# Stern engines: charge guide, then a live exhaust lane; destroying one ends it.
	var engine: Node2D = engines[0]
	engine.plume_clock = 0
	engine._process_engine(0.01)
	check(engine.beam.charge_left > 0 and not engine.beam.firing and engine.beam.shape.disabled, "Exhaust lane is telegraphed before it becomes harmful")
	engine.beam.charge_left = 0
	engine._process_engine(0.01)
	check(engine.beam.firing and engine.beam.body.visible, "Exhaust plume fires after its guide line")
	engine.take_damage(9999)
	check(not engine.beam.firing and boss.health == 1920, "Destroyed engine stops its plume without touching the shared bar")
	# Real ship + real projectile/Hurtbox integration, not only direct HP mutation.
	lab.ship.position = Vector2(boss.parts[0].global_position.x, 280)
	await create_timer(2.0).timeout
	check(boss.health < 1920, "Player's actual blaster damages the exposed turret")
	lab.ship.position = Vector2(10,320)
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/round.tres")
	shot.behavior = BulletBehavior.new()
	shot.spawn(lab.world, lab.ship.position + Vector2(0,-3), Vector2.DOWN, 20)
	await create_timer(0.2).timeout
	check(lab.hits > 0 and is_instance_valid(lab.ship), "Actual enemy bullets record hits without ending training")
	# Verify articulated aiming, lock and real projectile origin/direction.
	var gun: Node2D = turrets[1]
	gun.barrage.stop()
	gun.warning = false
	gun.cooldown = 10
	gun.pivot.rotation = 0
	gun._process_weapon(0.2)
	check(absf(gun.pivot.rotation) > 0.01 and absf(gun.pivot.rotation) <= deg_to_rad(20.01), "Turret tracks the target with a bounded slew rate")
	gun.warning = true
	gun.current_variant = 1
	gun.cooldown = 0.2
	var locked_angle: float = gun.pivot.rotation
	lab.ship.position.x = 230
	gun._process_weapon(0.1)
	check(is_equal_approx(gun.pivot.rotation, locked_angle), "Final warning locks the barrel despite target movement")
	var fired: Array[Node2D] = []
	gun.barrage.volley_fired.connect(func(projectiles): fired.append_array(projectiles), CONNECT_ONE_SHOT)
	gun.cooldown = 0
	var muzzle_origin: Vector2 = gun.muzzle.global_position
	gun._process_weapon(0)
	check(fired.size() == 1, "Aimed turret actually emits a single first shot")
	if not fired.is_empty():
		check(fired[0].global_position.is_equal_approx(muzzle_origin), "Shot starts at the articulated muzzle")
		check(fired[0]._direction.is_equal_approx(Vector2.DOWN.rotated(locked_angle)), "Bullet direction matches the visibly locked barrel")
	check(gun.recoil > 0, "Firing drives recoil and muzzle flash")
	gun.set_active(false)
	check(not gun.barrage.running, "Deactivation cancels queued burst shots")
	gun.set_active(true)
	lab.ship.position = Vector2(10,320)
	lab.toggle_pause()
	var frozen_position: Vector2 = boss.position
	var frozen_age: float = boss.parts[1].age
	await create_timer(0.2,true).timeout
	check(boss.position == frozen_position and boss.parts[1].age == frozen_age, "Pause freezes section and attack clocks")
	lab.toggle_pause()
	boss.parts[0].take_damage(9999)
	boss.parts[0].take_damage(9999)
	boss.parts[1].take_damage(9999)
	for turret in turrets: turret.take_damage(9999)
	# Park the live blaster in the deck gap between escort guns and hangars.
	lab.ship.position = Vector2(boss.global_position.x - 82,320)
	await create_timer(1.5).timeout
	check(boss.transitioning and not hangars[0].active, "Hangars descend before their combat phase")
	check(not boss.raiders_sent and boss.raiders.is_empty(), "Flight-deck approach launches no transit raiders")
	check(not engines[1].active and not engines[1].beam.firing, "Leaving the stern shuts down the surviving engine")
	check(hangars[0].global_position.y > 0 and hangars[0].visual.modulate == Color.WHITE, "Hangar is already visible while moving into view")
	check(boss.parts[0].visual.modulate.a < 1.0, "Destroyed turret remains dim wreckage")
	await create_timer(1.0).timeout
	check(boss.phase == 1 and boss.health == 1440, "Overkill and repeated destruction cannot damage future sections")
	check(lab.bar.value == 1440, "Pinned HUD does not refill between sections")
	hangars[0].take_damage(10)
	check(hangars[0].health == 237 and hangars[1].health == 240 and boss.health == 1437, "Closed hangar shutters absorb most damage")
	hangars[0].door_hold = 1.0
	hangars[0].take_damage(10)
	hangars[0].door_hold = 0
	check(hangars[0].health == 227 and hangars[1].health == 240 and boss.health == 1427, "Open hangar takes full damage, independently, once toward shared HP")
	for hangar in hangars:
		hangar.set_physics_process(false)
		hangar.launch_clock = 1
		hangar._physics_process(0.75)
		check(hangar.launch_charge > 0.7 and hangar.door_opening() > 0.99 and hangar.bay_alert() == 1.0, "Hangar doors open before the first fighter")
		check(hangar.lift_rise() > 0.3, "Lift raises the waiting aircraft before launch")
		hangar._physics_process(0.25)
		hangar._physics_process(0.35)
		hangar._physics_process(0.35)
	for hangar in hangars:
		hangar._physics_process(0.7)
		hangar._physics_process(0.15)
		check(hangar.door_opening() > 0.0 and hangar.door_opening() < 1.0, "Blast doors close after the hold")
		hangar._physics_process(0.2)
		check(hangar.door_opening() == 0.0 and hangar.slam_flash > 0, "Blast doors slam shut once the squadron is out")
	check(boss.fighters.size() == 6 and boss.fighters.all(func(craft): return craft.kind == 0), "Both hangars launch three-fighter squadrons")
	boss._launch_fighter(0, hangars[0])
	check(boss.fighters.size() == 6, "Six-fighter cap prevents extra spawns")
	var first_fighter: Node2D = boss.fighters[0]
	var last_fighter: Node2D = boss.fighters[2]
	var departure_y: float = first_fighter.position.y
	first_fighter._physics_process(1.0)
	last_fighter._physics_process(1.0)
	check(first_fighter.position.y > departure_y and first_fighter.position.x < last_fighter.position.x, "Launched fighters accelerate down the deck and split into formation lanes")
	check(boss.health == 1427, "Fighters do not contribute to boss HP")
	for fighter in boss.fighters: fighter.take_damage(9999)
	await process_frame
	check(boss.health == 1427, "Fighter kills do not reduce boss HP")
	hangars[0].launch_clock = 0
	hangars[0]._physics_process(0.01)
	check(hangars[0].launch_remaining == 2, "First fighter leaves two queued departures")
	var striker: Node2D = boss.fighters[-1]
	check(striker.kind == 1 and striker.ram != null, "Second sortie launches catapult strikers that ram")
	var rail_y: float = striker.position.y
	striker._physics_process(0.5)
	check(striker.warning and striker.position.y - rail_y < 10, "Striker holds on its rail while the lane is shown")
	striker._physics_process(0.1)
	striker._physics_process(0.1)
	check(striker.position.y - rail_y > 40, "Striker dashes straight down its rail")
	hangars[0].take_damage(9999)
	check(not hangars[0].barrage.running, "Destroyed hangar cancels future attacks")
	var survivors: int = boss.fighters.size()
	hangars[0]._physics_process(2)
	check(hangars[0].launch_remaining == 0 and boss.fighters.size() == survivors, "Hangar destruction cancels pending squadron departures")
	hangars[1].launch_clock = 0
	hangars[1]._physics_process(0.01)
	check(boss.fighters.size() == survivors + 1, "Surviving hangar keeps its own launch schedule")
	hangars[1].take_damage(9999)
	await process_frame
	check(boss.phase == 1 and not boss.transitioning and boss.health == 960, "Remaining escort guns must also be destroyed")
	for escort in escorts: escort.take_damage(9999)
	# Bridge gap: between the left fuel tank and the bridge tower.
	lab.ship.position = Vector2(boss.global_position.x - 80,320)
	await create_timer(1.5).timeout
	check(boss.transitioning and boss.raiders_sent, "Transit raiders cut in while the hull advances to the bridge")
	boss._spawn_raider(1.0)
	var raider: Node2D = boss.raiders[-1]
	check(raider.launch_speed > 0.0, "Raiders leave their hatch at the hull's speed")
	raider._physics_process(0.5)
	var raider_y: float = raider.position.y
	raider._physics_process(0.1)
	check(raider.position.y - raider_y >= 25.0, "Raiders dive faster than the hull transit")
	var hatch_y: float = boss.to_global(Vector2(0, boss.RAID_HATCH_Y[2])).y
	check(hatch_y > 0.0, "Raider hatches are on screen when the raiders launch")
	await create_timer(1.0).timeout
	check(boss.phase == 2 and boss.health == 800, "Bridge section is reachable")
	check(boss.fighters.is_empty(), "Transition removes surviving fighters")
	bridge.take_damage(400)
	check(bridge.stage == 1 and not bridge.barrage.running and lab.phase_label.text.ends_with("OVERDRIVE"), "Bridge enters overdrive at half HP")
	await create_timer(1.1).timeout
	check(bridge.armor_open > 0.95, "Overdrive armor opens to expose the laser core")
	bridge.barrage.stop()
	bridge.warning = false
	bridge.cooldown = 0
	bridge.attack_cycle = 0
	bridge._process_weapon(0.01)
	check(bridge.warning and bridge.current_variant == 3 and bridge.beam.charge_left > 0 and not bridge.beam.firing, "Laser charges with a harmless guide line")
	bridge.cooldown = 0
	bridge._process_weapon(0.0)
	check(bridge.laser_firing and bridge.beam.firing, "Laser fires after its charge")
	var sweep_start: float = bridge.pivot.rotation
	bridge._process_weapon(0.5)
	check(absf(bridge.pivot.rotation - sweep_start) > deg_to_rad(8), "Laser sweeps away from its locked line")
	bridge.take_damage(9999)
	await process_frame
	await process_frame
	check(boss.defeated and boss.health == 0 and lab.bar.value == 0, "Final destruction completes encounter and HUD")
	check(get_nodes_in_group("enemy_projectiles").is_empty(), "Final destruction removes dangerous projectiles")
	check(not bridge.beam.firing and boss.raiders.is_empty(), "Final destruction stops the laser and clears raiders")
	var hud_position: Vector2 = lab.bar.global_position
	check(lab.ship.process_mode == Node.PROCESS_MODE_DISABLED, "Finale stops player input and firing")
	await create_timer(1.4).timeout
	check(lab.camera.zoom.x < 1.0 and lab.camera.zoom.x > 0.28, "Camera pulls back progressively during chain explosions")
	check(lab.bar.global_position == hud_position and lab.bar.value == 0, "Zoom does not move or refill the HUD")
	check(not get_nodes_in_group("carrier_destruction_effects").is_empty(), "Finale creates live visual breakup effects")
	var effect: Node2D = get_nodes_in_group("carrier_destruction_effects")[-1]
	var frozen_effect_age: float = effect.age
	var frozen_destruction_age: float = boss.destruction_age
	var frozen_zoom: Vector2 = lab.camera.zoom
	lab.toggle_pause()
	await create_timer(0.3,true).timeout
	check(boss.destruction_age == frozen_destruction_age and lab.camera.zoom == frozen_zoom and effect.age == frozen_effect_age, "Pause freezes camera, sinking and debris together")
	lab.toggle_pause()
	await create_timer(7.9).timeout
	check(boss.destruction_complete and not boss.visible and boss.position.y > 750, "Carrier finishes its sinking sequence and fades out")
	check(lab.camera.zoom.is_equal_approx(Vector2.ONE*0.28), "Pullback reveals the full hull")
	var backgrounds: Array = lab.world.get_children().filter(func(child): return child.get_script() == preload("res://labs/bosses/carrier/carrier_background.gd"))
	check(backgrounds.size() == 1 and backgrounds[0].tiles[0].get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE), "Starfield keeps screen coverage at the smallest camera zoom")
	check(get_nodes_in_group("carrier_destruction_effects").is_empty(), "All explosion and debris effects clean themselves up")
	lab.toggle_pause()
	lab.restart()
	await process_frame
	await process_frame
	check(not paused and lab.boss.health == 1920 and lab.hits == 0, "Restart while paused resets world and counters")
	check(lab.camera.zoom == Vector2.ONE and lab.camera.position == Vector2(150,180), "Restart restores normal camera framing")
	check(lab.ship.process_mode != Node.PROCESS_MODE_DISABLED, "Restart restores player control")
	# Also dispose the world while its camera tween and chain explosions are live.
	for section in 3:
		await create_timer(2.4).timeout
		for part in lab.boss.parts:
			if part.section == section: part.take_damage(9999)
	await create_timer(1.2).timeout
	check(lab.camera.zoom.x < 1.0 and not lab.boss.destruction_complete, "Second run reaches an in-flight cinematic")
	var old_boss: WeakRef = weakref(lab.boss)
	var old_camera: WeakRef = weakref(lab.camera)
	lab.restart()
	await process_frame
	await process_frame
	check(old_boss.get_ref() == null and old_camera.get_ref() == null, "Restart during zoom frees the old boss and camera")
	check(get_nodes_in_group("carrier_destruction_effects").is_empty() and lab.camera.zoom == Vector2.ONE, "Interrupted finale leaves no effects or camera state behind")
	lab.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("PASS: carrier_boss_lab_smoke_test")
	quit(0 if failures.is_empty() else 1)
