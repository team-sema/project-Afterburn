extends SceneTree

## Prismatic rule cards: time warp field, brink and resonance fire
## (augments.md 규칙 카드), resolved through the offer controller in the real
## gameplay scene.

const ROUND := preload("res://resources/projectiles/round.tres")

var failures: PackedStringArray = []
var _gameplay: Node2D
## Sections that ran to the end; a script error inside one would skip its tail.
var _completed := 0


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	_run.call_deferred()


func _run() -> void:
	var world := load("res://world.tscn").instantiate() as Control
	root.add_child(world)
	_gameplay = world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay") as Node2D
	var ship := _gameplay.get_node("Ship") as Node2D
	var loadout := ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	var offer := _gameplay.get_node("AugmentOfferController") as AugmentOfferController
	for _i in 4:
		await process_frame

	await _test_time_warp(ship, loadout, offer)
	await _test_brink(ship, loadout, offer)
	await _test_resonance(ship, loadout, offer)
	_expect(_completed == 3, "every rule section ran to the end (%d/3)" % _completed)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ship_rule_prism_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("ship_rule_prism_test: %s" % failure)
	quit(1)


func _test_time_warp(ship: Node2D, loadout: PlayerWeaponLoadout, offer: AugmentOfferController) -> void:
	var card := load("res://resources/player_augments/rules/prism_time_warp.tres") as PlayerAugment
	_expect(card.tier == PlayerAugment.Tier.PRISMATIC and card.augment_type == PlayerAugmentKind.Kind.SHIP_RULE, "time warp is a prismatic rule card")
	_expect(offer._is_player_augment_available(card, loadout), "time warp is offered")
	var move := ship.get_node("MoveComponent") as MoveComponent
	var speed_before := move.velocity_multiplier
	_expect(await offer._resolve_player_augment(card), "time warp resolves")
	_expect(is_equal_approx(move.velocity_multiplier, speed_before * 0.8), "the ship moves at x0.8")
	_expect(not offer._is_player_augment_available(card, loadout), "time warp is one-time")
	var rule := ShipRules.get_runtime(ship, ShipRules.TIME_WARP) as TimeWarpRule
	_expect(rule != null, "time warp installs its field on the ship")

	var inside := _spawn_bullet(ship.global_position + Vector2(44.0, 0.0), Vector2.RIGHT, 30.0)
	var outside := _spawn_bullet(ship.global_position + Vector2(0.0, -120.0), Vector2.UP, 30.0)
	for _i in 3:
		await physics_frame
	_expect(absf(inside.get_travel_velocity().length() - 15.0) < 0.5, "a bullet within 50px moves at x0.5")
	_expect(absf(outside.get_travel_velocity().length() - 30.0) < 0.5, "a bullet outside keeps its speed")
	for _i in 60:
		await physics_frame
	_expect(inside.global_position.distance_to(ship.global_position) > 50.0, "the slowed bullet drifts out")
	_expect(absf(inside.get_travel_velocity().length() - 30.0) < 0.5, "leaving the field restores full speed")
	inside.queue_free()
	outside.queue_free()
	_completed += 1


func _test_brink(ship: Node2D, loadout: PlayerWeaponLoadout, offer: AugmentOfferController) -> void:
	var card := load("res://resources/player_augments/rules/prism_brink.tres") as PlayerAugment
	var shield := ship.get_node("ShieldComponent") as ShieldComponent
	_expect(offer._is_player_augment_available(card, loadout), "brink is offered with a shield")
	var charge_before: float = shield.call("_charge_duration")
	_expect(await offer._resolve_player_augment(card), "brink resolves")
	_expect(is_equal_approx(shield.call("_charge_duration"), charge_before * 2.0), "shield charge takes twice as long")
	var rule := ShipRules.get_runtime(ship, ShipRules.BRINK) as BrinkRule

	shield.restore_shield(shield.get_max_shield())
	var early := _spawn_bullet(ship.global_position + Vector2(-100.0, -150.0), Vector2.RIGHT, 50.0)
	await physics_frame
	_expect(not rule.is_active(), "brink waits for the shield to break")
	shield.absorb_damage(shield.get_current_shield())
	_expect(rule.is_active(), "breaking the shield triggers brink")
	await physics_frame
	_expect(absf(early.get_travel_velocity().length() - 10.0) < 0.5, "bullets on screen slow to x0.2")
	for _i in 30:
		await physics_frame
	var late := _spawn_bullet(ship.global_position + Vector2(-100.0, -100.0), Vector2.RIGHT, 50.0)
	await physics_frame
	await physics_frame
	var late_effect := EnemyBullets.get_effect(late, BrinkRule.HANDLE)
	_expect(not late_effect.is_empty(), "a bullet fired during the window is slowed too")
	_expect(absf(late.get_travel_velocity().length() - 10.0) < 0.5, "the late bullet moves at x0.2")
	for _i in 100:
		await physics_frame
	_expect(not rule.is_active(), "brink ends after two seconds")
	_expect(absf(early.get_travel_velocity().length() - 50.0) < 0.5, "early bullets return to full speed")
	_expect(absf(late.get_travel_velocity().length() - 50.0) < 0.5, "late bullets return to full speed with the window")
	early.queue_free()
	late.queue_free()
	shield.restore_shield(shield.get_max_shield())
	_completed += 1


func _test_resonance(ship: Node2D, loadout: PlayerWeaponLoadout, offer: AugmentOfferController) -> void:
	var card := load("res://resources/player_augments/rules/prism_resonance_fire.tres") as PlayerAugment
	var blaster := loadout.get_bay(0).equipped_weapon_instance as WeaponSystem
	var rate_before := blaster.get_effective_fire_rate_multiplier()
	_expect(await offer._resolve_player_augment(card), "resonance fire resolves")
	_expect(is_equal_approx(blaster.get_effective_fire_rate_multiplier(), rate_before * 0.8), "weapons fire at x0.8")
	for path in [
		"res://resources/weapons/definitions/aux_orbital_barrier.tres",
		"res://resources/weapons/definitions/main_laser.tres",
	]:
		loadout.offer_equip_weapon(load(path) as WeaponDefinition)
	var laser := loadout.get_bay(2).equipped_weapon_instance as WeaponSystem
	_expect(
		laser != null and is_equal_approx(laser.get_effective_fire_rate_multiplier(), rate_before * 0.8),
		"a weapon equipped later fires at x0.8 too",
	)
	var rule := ShipRules.get_runtime(ship, ShipRules.RESONANCE_FIRE) as ResonanceRule
	var fired: Array[StringName] = []
	rule.bonus_fired.connect(func(weapon: WeaponSystem) -> void: fired.append(weapon.get_weapon_id()))

	var enemy := (load("res://enemies/normal_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.augment_registry = offer.enemy_registry
	_gameplay.add_child(enemy)
	enemy.global_position = Vector2(280.0, 60.0)
	enemy.stats_component.health = 0
	await process_frame
	_expect(fired.size() == 1 and fired[0] == &"main_blaster", "a real enemy defeat fires the first weapon once (%s)" % str(fired))
	get_first_node_in_group(Enemy.DEFEAT_LISTENER_GROUP).call("on_enemy_defeated", null)
	await process_frame
	_expect(fired.size() == 1, "a defeat within 0.1 s is dropped")
	for _i in 8:
		await physics_frame
	rule.on_enemy_defeated(null)
	await process_frame
	_expect(fired.size() == 2 and fired[1] == &"main_laser", "the next defeat skips the barrier and fires the laser (%s)" % str(fired))
	for _i in 8:
		await physics_frame
	rule.on_enemy_defeated(null)
	await process_frame
	_expect(fired.size() == 3 and fired[2] == &"main_blaster", "the turn wraps back to the first bay")
	_completed += 1


func _spawn_bullet(origin: Vector2, direction: Vector2, speed: float) -> FoundationBullet:
	var shot := BarrageShot.new()
	shot.appearance = ROUND
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 20.0
	return shot.spawn(_gameplay, origin, direction, speed) as FoundationBullet


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
