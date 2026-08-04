extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_blaster_configuration()
	_test_shotgun_configuration()
	_test_cannon_configuration()
	_test_homing_missile_configuration()
	_test_plasma_bomb_configuration()

	var world := Node2D.new()
	root.add_child(world)
	var timed_systems: Array[Node] = []
	var timed_paths := [
		"res://player_ship/weapons/blaster_weapon_system.tscn",
		"res://player_ship/weapons/shotgun_weapon_system.tscn",
		"res://player_ship/weapons/auxiliary_cannon_weapon_system.tscn",
		"res://player_ship/weapons/homing_missile_weapon_system.tscn",
		"res://player_ship/weapons/plasma_bomb_weapon_system.tscn",
	]
	for index in timed_paths.size():
		var system := load(timed_paths[index]).instantiate() as Node
		system.set("base_fire_interval", 4.0 + index)
		world.add_child(system)
		timed_systems.append(system)
	var laser := load("res://player_ship/weapons/laser_weapon_system.tscn").instantiate() as LaserWeaponSystem
	laser.base_tick_interval = 0.27
	laser.base_tick_damage = 7
	world.add_child(laser)
	var barrier := load("res://player_ship/weapons/orbital_barrier_weapon_system.tscn").instantiate() as OrbitalBarrierWeaponSystem
	barrier.base_damage = 11
	barrier.segment_max_health = 3
	world.add_child(barrier)
	await process_frame

	for index in timed_systems.size():
		var fire_timer := timed_systems[index].get_node("FireRateTimer") as Timer
		_expect(
			is_equal_approx(fire_timer.wait_time, 4.0 + index) and not fire_timer.is_stopped(),
			"timed weapon %d starts from its WeaponSystem fire interval" % index,
		)
	_expect(
		is_equal_approx((laser.get_node("DamageTickTimer") as Timer).wait_time, 0.27),
		"laser system owns its damage tick interval",
	)
	_expect(
		(laser.get_node("DamageHitbox") as HitboxComponent).damage == 7,
		"laser system owns its base damage",
	)
	for segment in barrier.get_node("OrbitRoot").get_children():
		_expect(
			(segment.get_node("HitboxComponent") as HitboxComponent).damage == 11,
			"orbital barrier system owns segment damage",
		)
		_expect(
			(segment.get_node("StatsComponent") as StatsComponent).health == 3,
			"orbital barrier system owns segment health",
		)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon system tuning test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon system tuning test: %s" % failure)
	quit(1)


func _test_blaster_configuration() -> void:
	var system := load("res://player_ship/weapons/blaster_weapon_system.tscn").instantiate() as BlasterWeaponSystem
	var projectile: Node = load("res://projectiles/player_blaster.tscn").instantiate()
	system.base_damage = 17
	system.projectile_speed = 123.0
	system.call("_configure_projectile", projectile)
	_expect((projectile.get_node("HitboxComponent") as HitboxComponent).damage == 17, "blaster system owns damage")
	_expect(
		(projectile.get_node("MoveComponent") as MoveComponent).velocity == Vector2(0, -123),
		"blaster system owns projectile speed",
	)
	projectile.free()
	system.free()


func _test_shotgun_configuration() -> void:
	var system := load("res://player_ship/weapons/shotgun_weapon_system.tscn").instantiate() as ShotgunWeaponSystem
	var projectile: Node = load("res://projectiles/player_shotgun_pellet.tscn").instantiate()
	system.base_damage = 6
	system.pellet_speed = 210.0
	system.call("_configure_projectile", projectile, Vector2.RIGHT)
	_expect((projectile.get_node("HitboxComponent") as HitboxComponent).damage == 6, "shotgun system owns pellet damage")
	_expect(
		(projectile.get_node("MoveComponent") as MoveComponent).velocity == Vector2(210, 0),
		"shotgun system owns pellet speed",
	)
	projectile.free()
	system.free()


func _test_cannon_configuration() -> void:
	var system := load("res://player_ship/weapons/auxiliary_cannon_weapon_system.tscn").instantiate() as AuxiliaryCannonWeaponSystem
	var projectile: Node = load("res://projectiles/aux_cannon_bolt.tscn").instantiate()
	system.base_damage = 13
	system.projectile_speed = 175.0
	system.call("_configure_projectile", projectile)
	_expect((projectile.get_node("HitboxComponent") as HitboxComponent).damage == 13, "cannon system owns damage")
	_expect(
		(projectile.get_node("MoveComponent") as MoveComponent).velocity == Vector2(0, -175),
		"cannon system owns projectile speed",
	)
	projectile.free()
	system.free()


func _test_homing_missile_configuration() -> void:
	var system := load("res://player_ship/weapons/homing_missile_weapon_system.tscn").instantiate() as HomingMissileWeaponSystem
	var projectile := load("res://projectiles/player_homing_missile.tscn").instantiate() as PlayerHomingMissile
	system.base_damage = 19
	system.projectile_speed = 140.0
	system.turn_rate = 4.2
	system.retarget_interval = 0.23
	system.call("_configure_projectile", projectile)
	_expect((projectile.get_node("HitboxComponent") as HitboxComponent).damage == 19, "missile system owns damage")
	_expect(is_equal_approx(projectile.speed, 140.0), "missile system owns projectile speed")
	_expect(is_equal_approx(projectile.turn_rate, 4.2), "missile system owns turn rate")
	_expect(is_equal_approx(projectile.retarget_interval, 0.23), "missile system owns retarget interval")
	projectile.free()
	system.free()


func _test_plasma_bomb_configuration() -> void:
	var system := load("res://player_ship/weapons/plasma_bomb_weapon_system.tscn").instantiate() as PlasmaBombWeaponSystem
	var projectile := load("res://projectiles/plasma_bomb_projectile.tscn").instantiate() as PlasmaBombProjectile
	system.base_damage = 31
	system.projectile_speed = 44.0
	system.fuse_time = 1.7
	system.blast_radius = 39.0
	system.damage_radius_margin = 7.0
	system.call("_configure_projectile", projectile)
	_expect(projectile.blast_damage == 31, "plasma bomb system owns damage")
	_expect(is_equal_approx(projectile.flight_speed, 44.0), "plasma bomb system owns projectile speed")
	_expect(is_equal_approx(projectile.fuse_time, 1.7), "plasma bomb system owns fuse time")
	_expect(is_equal_approx(projectile.blast_radius, 39.0), "plasma bomb system owns blast radius")
	_expect(is_equal_approx(projectile.damage_radius_margin, 7.0), "plasma bomb system owns damage radius margin")
	_expect(is_equal_approx(projectile.get_damage_radius(), 46.0), "plasma bomb adds margin to its damage radius")
	projectile.free()
	system.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
