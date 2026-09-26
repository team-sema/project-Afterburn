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
	var bridge: Node2D = boss.parts[-1]
	check(turrets.size() == 6 and hangars.size() == 2 and escorts.size() == 4, "Six turrets, two hangars and four deck escorts")
	check(boss.health == 800, "Full encounter HP includes future sections")
	bridge.take_damage(9999)
	check(boss.health == 800, "Offscreen bridge cannot take damage")
	var mount_offset: Vector2 = boss.parts[0].global_position - boss.global_position
	var entry_y: float = boss.parts[0].global_position.y
	await create_timer(1.2).timeout
	check(boss.transitioning and not boss.parts[0].active, "Mounted turret remains combat-disabled during entry")
	check(boss.parts[0].global_position.y > entry_y, "Turret descends before activation")
	check((boss.parts[0].global_position - boss.global_position).is_equal_approx(mount_offset), "Turret preserves its mount offset while hull moves")
	check(boss.parts[0].visual.modulate == Color.WHITE, "Intact turret remains visible during entry")
	await create_timer(1.2).timeout
	check(boss.phase == 0 and not boss.transitioning, "Intro arrives at aft defense")
	# Real ship + real projectile/Hurtbox integration, not only direct HP mutation.
	lab.ship.position = Vector2(62,280)
	await create_timer(2.0).timeout
	check(boss.health < 800, "Player's actual blaster damages the exposed turret")
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
	await create_timer(1.5).timeout
	check(boss.transitioning and not hangars[0].active, "Hangars descend before their combat phase")
	check(hangars[0].global_position.y > 0 and hangars[0].visual.modulate == Color.WHITE, "Hangar is already visible while moving into view")
	check(boss.parts[0].visual.modulate.a < 1.0, "Destroyed turret remains dim wreckage")
	await create_timer(1.0).timeout
	check(boss.phase == 1 and boss.health == 560, "Overkill and repeated destruction cannot damage future sections")
	check(lab.bar.value == 560, "Pinned HUD does not refill between sections")
	hangars[0].take_damage(10)
	check(hangars[0].health == 110 and hangars[1].health == 120 and boss.health == 550, "Hangar damage is independent and contributes once to shared HP")
	for hangar in hangars:
		hangar.set_physics_process(false)
		hangar.launch_clock = 1
		hangar._physics_process(0.75)
		check(hangar.launch_charge > 0.7 and absf(hangar.doors[0].position.x) > 7, "Hangar doors open before the first fighter")
		hangar._physics_process(0.25)
		hangar._physics_process(0.35)
		hangar._physics_process(0.35)
	check(boss.fighters.size() == 6, "Both hangars launch three-fighter squadrons")
	boss._launch_fighter(0, hangars[0])
	check(boss.fighters.size() == 6, "Six-fighter cap prevents extra spawns")
	var first_fighter: Node2D = boss.fighters[0]
	var last_fighter: Node2D = boss.fighters[2]
	var departure_y: float = first_fighter.position.y
	first_fighter._physics_process(1.0)
	last_fighter._physics_process(1.0)
	check(first_fighter.position.y > departure_y and first_fighter.position.x < last_fighter.position.x, "Launched fighters accelerate down the deck and split into formation lanes")
	check(boss.health == 550, "Fighters do not contribute to boss HP")
	for fighter in boss.fighters: fighter.take_damage(9999)
	await process_frame
	check(boss.health == 550, "Fighter kills do not reduce boss HP")
	hangars[0].launch_clock = 0
	hangars[0]._physics_process(0.01)
	check(hangars[0].launch_remaining == 2, "First fighter leaves two queued departures")
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
	check(boss.phase == 1 and not boss.transitioning and boss.health == 320, "Remaining escort guns must also be destroyed")
	for escort in escorts: escort.take_damage(9999)
	await create_timer(2.5).timeout
	check(boss.phase == 2 and boss.health == 240, "Bridge section is reachable")
	check(boss.fighters.is_empty(), "Transition removes surviving fighters")
	bridge.take_damage(9999)
	await process_frame
	await process_frame
	check(boss.defeated and boss.health == 0 and lab.bar.value == 0, "Final destruction completes encounter and HUD")
	check(get_nodes_in_group("enemy_projectiles").is_empty(), "Final destruction removes dangerous projectiles")
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
	check(not paused and lab.boss.health == 800 and lab.hits == 0, "Restart while paused resets world and counters")
	check(lab.camera.zoom == Vector2.ONE and lab.camera.position == Vector2(120,180), "Restart restores normal camera framing")
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
