extends SceneTree

## Prismatic weapon modules: laser spectrum prism (three beams, x0.45 each),
## plasma singularity (holds, pulls and swallows bullets, collapse bonus,
## doubled fire interval) and barrier stasis orbit (slow field, unbreakable
## segments, no contact damage).


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


	func set_trait(weapon_id: StringName, trait_id: StringName, rank: int) -> void:
		if rank > 0:
			traits[trait_id] = rank
		else:
			traits.erase(trait_id)
		weapon_trait_changed.emit(weapon_id, trait_id, rank)


const ROUND := preload("res://resources/projectiles/round.tres")

var failures: PackedStringArray = []
## target name -> damage values received.
var _hits: Dictionary = {}
var _world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = Node2D.new()
	_world.add_to_group("gameplay_world")
	root.add_child(_world)
	await _test_laser_spectrum()
	await _test_plasma_singularity()
	await _test_barrier_stasis()
	_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("prism_weapon_modules_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("prism_weapon_modules_test: %s" % failure)
	quit(1)


func _test_laser_spectrum() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var laser := (load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene).instantiate() as LaserWeaponSystem
	laser.position = Vector2(150.0, 300.0)
	root.add_child(laser)
	await physics_frame
	laser.setup_weapon(null, loadout, 0, &"main_laser")
	laser.damage_tick_timer.stop()
	await physics_frame
	_expect(laser.get_beam_paths().size() == 1, "without the module the laser has one beam")

	var centre := _make_target("centre", Vector2(150.0, 151.0))
	await physics_frame
	await physics_frame
	laser.apply_damage_tick()
	var plain_damage := _last_hit("centre")

	loadout.set_trait(&"main_laser", &"laser_spectrum_prism", 1)
	await physics_frame
	var paths := laser.get_beam_paths()
	_expect(paths.size() == 3, "the spectrum prism splits the laser into three beams")
	var right_mid := laser.to_global(paths[2][0].lerp(paths[2][paths[2].size() - 1], 0.5))
	_expect(absf(right_mid.x - 150.0 - 143.0 * tan(deg_to_rad(12.0))) < 1.0, "the side beam leans 12 degrees")
	var right_tip := laser.to_global(paths[2][paths[2].size() - 1])
	var main_tip := laser.to_global(paths[0][paths[0].size() - 1])
	_expect(absf(right_tip.y - main_tip.y) < 0.5, "side beams reach the same height as the main beam")
	var side_glows := laser.get_children().filter(func(child: Node) -> bool: return child is Sprite2D and child.visible)
	_expect(side_glows.size() == 3, "three glow sprites are drawn")

	var side := _make_target("side", right_mid)
	await physics_frame
	await physics_frame
	_hits["centre"] = []
	laser.apply_damage_tick()
	_expect(_hits["side"].size() == 1, "an enemy on a side beam is hit")
	_expect(_hits["centre"].size() == 1, "the centre enemy is hit once by the main beam")
	_expect(
		_last_hit("centre") == maxi(1, roundi(float(plain_damage) * 0.45)),
		"each beam deals x0.45 (plain %d, now %d)" % [plain_damage, _last_hit("centre")],
	)

	loadout.set_trait(&"main_laser", &"laser_spectrum_prism", 0)
	await process_frame
	_expect(laser.get_beam_paths().size() == 1, "losing the module removes the side beams")
	centre.queue_free()
	side.queue_free()
	laser.queue_free()
	loadout.queue_free()
	await process_frame


func _test_plasma_singularity() -> void:
	var definition := load("res://resources/weapons/traits/plasma_singularity_prism.tres") as WeaponTraitDefinition
	var config := definition.get_params_for_rank(1)

	# Weapon: fire interval x2.5.
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var weapon := (load("res://player_ship/weapons/plasma_bomb_weapon_system.tscn") as PackedScene).instantiate() as PlasmaBombWeaponSystem
	root.add_child(weapon)
	weapon.setup_weapon(null, loadout, 0, &"plasma_bomb")
	var interval := weapon.fire_rate_timer.wait_time
	loadout.set_trait(&"plasma_bomb", &"plasma_singularity_prism", 1)
	_expect(is_equal_approx(weapon.fire_rate_timer.wait_time, interval * 2.5), "the singularity stretches the fire interval x2.5")
	weapon.shutdown_weapon()
	weapon.queue_free()
	loadout.queue_free()

	var core := Vector2(150.0, 150.0)
	var bomb := (load("res://projectiles/plasma_bomb_projectile.tscn") as PackedScene).instantiate() as PlasmaBombProjectile
	bomb.configure_bomb(1.0, 0.0, 32.0, 0.0, 20)
	bomb.configure_singularity(config)
	_world.add_child(bomb)
	bomb.global_position = core
	var target := _make_target("blast", core + Vector2(0.0, 20.0))
	var enemy := Node2D.new()
	enemy.add_to_group("enemies")
	var modifier := MoveModifierComponent.new()
	modifier.name = "MoveModifierComponent"
	enemy.add_child(modifier)
	_world.add_child(enemy)
	enemy.global_position = core + Vector2(-50.0, 0.0)
	await physics_frame
	await physics_frame

	bomb.detonate_now()
	_expect(bomb.is_singularity_active(), "the first detonation turns the bomb into a singularity")
	var lens := bomb.get_lens()
	_expect(lens != null and lens.get_parent() == _world, "the singularity places a screen lens beside the bomb")
	_expect(
		lens != null and is_equal_approx(lens.radius, bomb.get_collapse_radius()) and lens.radius < bomb.get_singularity_pull_radius(),
		"the lens matches the collapse radius, inside the pull range",
	)
	var passing := _spawn_bullet(core + Vector2(22.0, -60.0), Vector2.DOWN, 60.0)
	var far := _spawn_bullet(core + Vector2(140.0, -60.0), Vector2.DOWN, 60.0)
	# Players: one inside the pull range, one outside.
	var player_in := _make_player("player_in", core + Vector2(35.0, 0.0))
	var player_out := _make_player("player_out", core + Vector2(-120.0, 0.0))
	var hurt_in := player_in.get_node("HurtComponent") as HurtComponent
	var box_in := hurt_in.hurtbox_component
	for _i in 3:
		await physics_frame
	_expect(box_in.is_invincible and hurt_in.is_invincibility_held(), "a player inside the pull range is invincible")
	_expect(
		not (player_out.get_node("HurtComponent") as HurtComponent).hurtbox_component.is_invincible,
		"a player outside the pull range is not",
	)
	# A resting bullet (never pulled or swallowed) on each player.
	var on_in := _spawn_bullet(player_in.global_position, Vector2.RIGHT, 0.0)
	var on_out := _spawn_bullet(player_out.global_position, Vector2.RIGHT, 0.0)
	for _i in 3:
		await physics_frame
	_expect(_hits["player_in"].is_empty(), "a bullet on the sheltered player does not hurt it")
	_expect(_hits["player_out"].size() == 1, "a bullet on a player outside the range still hurts")
	on_in.queue_free()
	hurt_in.start_invincibility(0.05)
	await create_timer(0.15).timeout
	_expect(box_in.is_invincible, "iframes running out do not end the shelter")
	player_in.global_position = core + Vector2(0.0, 100.0)
	for _i in 2:
		await physics_frame
	_expect(not box_in.is_invincible, "leaving the pull range ends the invincibility")
	player_in.global_position = core + Vector2(35.0, 0.0)
	for _i in 2:
		await physics_frame
	_expect(box_in.is_invincible and bomb.get_sheltered_count() == 1, "coming back in shelters the player again")
	var swallowed := 0
	for _i in 60:
		await physics_frame
		swallowed = bomb.get_swallowed_count()
	_expect(is_instance_valid(bomb) and bomb.is_singularity_active(), "the singularity holds for its duration")
	_expect(_hits["blast"].is_empty(), "no blast damage while the singularity holds")
	_expect(not is_instance_valid(passing) or passing.is_queued_for_deletion(), "a bullet passing beside the core is pulled in and swallowed")
	_expect(swallowed >= 1, "swallowed bullets are counted")
	_expect(is_instance_valid(far) and EnemyBullets.get_effect(far, &"plasma_singularity").is_empty(), "a bullet outside the pull radius is untouched")
	_expect(modifier.external_velocity.x > 1.0, "a nearby enemy is dragged toward the core")
	_expect(lens != null and lens.get_strength() >= 1.0, "the lens is at full strength while holding")
	_expect(lens != null and lens.horizon_px > PlasmaBombProjectile.HORIZON_BASE_PX, "swallowed bullets widen the event horizon")

	for _i in 120:
		if not is_instance_valid(bomb):
			break
		swallowed = bomb.get_swallowed_count()
		await physics_frame
	_expect(not is_instance_valid(bomb), "the singularity collapses after 2 seconds")
	_expect(not box_in.is_invincible and not hurt_in.is_invincibility_held(), "the collapse ends the shelter")
	_expect(is_instance_valid(lens) and lens.is_collapsing(), "the lens outlives the bomb to play the collapse wave")
	await create_timer(SingularityLens.COLLAPSE_TIME + 0.2).timeout
	_expect(not is_instance_valid(lens), "the lens frees itself after the collapse wave")
	_expect(_hits["blast"].size() == 1, "the collapse hits once")
	var expected := roundi(20.0 * (1.0 + minf(2.0, 0.08 * float(swallowed))))
	_expect(
		not _hits["blast"].is_empty() and _hits["blast"][0] == expected,
		"collapse damage grows by 8%% per swallowed bullet (%s, want %d)" % [str(_hits["blast"]), expected],
	)
	target.queue_free()
	enemy.queue_free()
	for node in [far, on_out, player_in, player_out]:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame


func _test_barrier_stasis() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var ship := Node2D.new()
	root.add_child(ship)
	ship.global_position = Vector2(150.0, 200.0)
	var barrier := (load("res://player_ship/weapons/orbital_barrier_weapon_system.tscn") as PackedScene).instantiate() as OrbitalBarrierWeaponSystem
	root.add_child(barrier)
	barrier.setup_weapon(ship, loadout, 0, &"aux_orbital_barrier")
	await physics_frame

	var segment := barrier.orbit_root.get_child(0) as Node2D
	var enemy_hurtbox := _make_target("contact", Vector2(400.0, 400.0))
	var segment_hitbox := segment.get_node("HitboxComponent") as HitboxComponent
	barrier.call("_on_barrier_hitbox_entered", enemy_hurtbox, segment_hitbox)
	_expect(_hits["contact"].size() == 1, "a plain barrier strikes enemies on contact")

	loadout.set_trait(&"aux_orbital_barrier", &"barrier_stasis_prism", 1)
	var radius := barrier.get_stasis_radius()
	_expect(is_equal_approx(radius, barrier.orbit_radius * 2.0), "the stasis field reaches twice the orbit radius")
	var inside := _spawn_bullet(ship.global_position + Vector2(radius - 6.0, 0.0), Vector2.RIGHT, 50.0)
	var outside := _spawn_bullet(ship.global_position + Vector2(0.0, -radius - 40.0), Vector2.UP, 50.0)
	for _i in 3:
		await process_frame
	_expect(barrier.get_stasis_count() == 1, "only the bullet inside the field is slowed")
	_expect(absf(inside.get_travel_velocity().length() - 20.0) < 0.5, "a bullet in the field moves at x0.4")
	_expect(absf(outside.get_travel_velocity().length() - 50.0) < 0.5, "a bullet outside keeps its speed")
	for _i in 40:
		await physics_frame
	_expect(inside.global_position.distance_to(ship.global_position) > radius, "the slowed bullet still drifts out")
	await process_frame
	_expect(absf(inside.get_travel_velocity().length() - 50.0) < 0.5, "leaving the field restores full speed")

	var heavy := HitboxComponent.new()
	heavy.damage = 5
	barrier.call("_on_segment_hurt", heavy, segment)
	_expect(not barrier.is_segment_broken(segment), "stasis segments do not break")
	heavy.free()
	barrier.call("_on_barrier_hitbox_entered", enemy_hurtbox, segment_hitbox)
	_expect(_hits["contact"].size() == 1, "stasis segments deal no contact damage")

	var back := _spawn_bullet(ship.global_position + Vector2(-radius + 4.0, 0.0), Vector2.DOWN, 10.0)
	for _i in 3:
		await process_frame
	_expect(not EnemyBullets.get_effect(back, &"barrier_stasis").is_empty(), "a bullet entering the field gets the slow")
	barrier.shutdown_weapon()
	_expect(EnemyBullets.get_effect(back, &"barrier_stasis").is_empty(), "shutting the barrier down releases the slow")

	for node in [inside, outside, back, enemy_hurtbox, barrier, ship, loadout]:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame


func _spawn_bullet(origin: Vector2, direction: Vector2, speed: float) -> FoundationBullet:
	var shot := BarrageShot.new()
	shot.appearance = ROUND
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 20.0
	return shot.spawn(_world, origin, direction, speed) as FoundationBullet


## Minimal player: "player" group, player-layer hurtbox and a HurtComponent.
func _make_player(target_name: String, position: Vector2) -> Node2D:
	var player := Node2D.new()
	player.name = target_name
	player.add_to_group("player")
	var stats := StatsComponent.new()
	stats.health = 99
	player.add_child(stats)
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	hurtbox.add_child(shape)
	player.add_child(hurtbox)
	var hurt := HurtComponent.new()
	hurt.name = "HurtComponent"
	hurt.stats_component = stats
	hurt.hurtbox_component = hurtbox
	player.add_child(hurt)
	root.add_child(player)
	player.global_position = position
	_hits[target_name] = []
	hurtbox.hurt.connect(func(hitbox: Variant) -> void: _hits[target_name].append((hitbox as HitboxComponent).damage))
	return player


func _make_target(target_name: String, position: Vector2) -> HurtboxComponent:
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = target_name
	hurtbox.collision_layer = 1 << 1
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 1.0
	shape.shape = circle
	hurtbox.add_child(shape)
	root.add_child(hurtbox)
	hurtbox.global_position = position
	_hits[target_name] = []
	hurtbox.hurt.connect(func(hitbox: Variant) -> void: _hits[target_name].append((hitbox as HitboxComponent).damage))
	return hurtbox


func _last_hit(target_name: String) -> int:
	var list: Array = _hits.get(target_name, [])
	return int(list[-1]) if not list.is_empty() else -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
