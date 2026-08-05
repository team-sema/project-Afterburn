extends SceneTree

## Facility module smoke: boss mult, hull-only emergency, boost action, iframes, radar, shield charge.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_boss_damage_resolver()
	await _test_shield_charge_speed()
	_test_engine_boost_input_exists()
	await _test_enemy_boss_flag()
	await _test_world_modules()

	if failures.is_empty():
		print("facility weapon modules smoke: PASS")
		quit()
		return
	for failure in failures:
		printerr(failure)
	print("facility weapon modules smoke: FAIL (%d)" % failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_boss_damage_resolver() -> void:
	var weapon := WeaponSystem.new()
	root.add_child(weapon)
	weapon.set_facility_damage_multiplier(1.0)
	weapon.set_boss_damage_multiplier(1.3)
	var normal := weapon.resolve_hit_damage(100, null)
	_expect(normal == 100, "non-boss resolve stays base")

	var boss_scene := load("res://enemies/normal_enemy.tscn") as PackedScene
	if boss_scene == null:
		failures.append("normal_enemy.tscn missing")
		weapon.queue_free()
		return
	var boss := boss_scene.instantiate() as Enemy
	boss.is_boss = true
	root.add_child(boss)
	await process_frame
	var hurtbox := boss.get_node_or_null("HurtboxComponent") as HurtboxComponent
	_expect(hurtbox != null, "boss has HurtboxComponent")
	if hurtbox != null:
		var boss_dmg := weapon.resolve_hit_damage(100, hurtbox)
		_expect(boss_dmg == 130, "boss resolve applies 1.3 (got %d)" % boss_dmg)
	boss.queue_free()
	weapon.queue_free()


func _test_shield_charge_speed() -> void:
	var shield := ShieldComponent.new()
	shield.base_max_shield = 1
	shield.regen_charge_duration = 10.0
	root.add_child(shield)
	await process_frame
	shield.absorb_damage(1)
	shield.set_charge_speed_multiplier(2.0)
	shield._process(2.5)
	_expect(
		is_equal_approx(shield.get_charge_progress(), 0.5),
		"×2 charge speed: 2.5/10 → 0.5 (got %.3f)" % shield.get_charge_progress()
	)
	shield.queue_free()


func _test_engine_boost_input_exists() -> void:
	_expect(InputMap.has_action(&"engine_boost"), "engine_boost input action registered")


func _test_enemy_boss_flag() -> void:
	var scene := load("res://enemies/normal_enemy.tscn") as PackedScene
	var enemy := scene.instantiate() as Enemy
	root.add_child(enemy)
	await process_frame
	_expect(not enemy.is_boss, "default enemy is not boss")
	_expect(not enemy.is_in_group("bosses"), "default not in bosses group")
	enemy.is_boss = true
	enemy.add_to_group("bosses")
	_expect(enemy.is_boss and enemy.is_in_group("bosses"), "boss flag + group")
	enemy.queue_free()


func _test_world_modules() -> void:
	var world := (load("res://world.tscn") as PackedScene).instantiate() as Control
	root.add_child(world)
	for _i in 6:
		await process_frame
	var ship := world.get_node(
		"Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay/Ship"
	) as Node2D
	var registry := world.get_node(
		"Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay/PlayerAugmentRegistry"
	) as PlayerAugmentRegistry
	var boost := ship.get_node_or_null("EngineBoostComponent") as EngineBoostComponent
	var buffs := ship.get_node_or_null("ShipCombatBuffController") as ShipCombatBuffController
	var shield := ship.get_node("ShieldComponent") as ShieldComponent
	var collector := ship.get_node("ExperienceCollector") as ExperienceCollectorComponent
	_expect(boost != null, "EngineBoostComponent on ship")
	_expect(buffs != null, "ShipCombatBuffController on ship")
	_expect(shield.get_max_shield() == 1, "start shield 1")

	var radar := load("res://resources/player_augments/facilities/facility_radar.tres") as PlayerAugment
	var base_radius := collector.collection_radius
	registry.install_augment(radar)
	await process_frame
	_expect(
		is_equal_approx(collector.collection_radius, base_radius * 1.5),
		"radar pickup ×1.5 (got %.2f base %.2f)" % [collector.collection_radius, base_radius]
	)

	# Expand shield slot then install charge module (default capacity 1, radar already filled radar).
	registry.expand_slots(&"shield")
	var charge := load("res://resources/player_augments/facilities/facility_shield_charge.tres") as PlayerAugment
	registry.install_augment(charge)
	await process_frame
	_expect(is_equal_approx(shield.charge_speed_multiplier, 2.0), "shield charge speed ×2")

	var hangar_def := registry.get_facility_definition(&"hangar")
	_expect(hangar_def != null and hangar_def.display_name == "동력로", "hangar renamed 동력로")

	var barrier := load("res://player_ship/weapons/orbital_barrier_weapon_system.tscn") as PackedScene
	var barrier_node := barrier.instantiate() as OrbitalBarrierWeaponSystem
	_expect(is_equal_approx(barrier_node.segment_arc_length, 11.33), "barrier arc ~1/3 of 34")
	barrier_node.queue_free()

	world.queue_free()
	await process_frame
