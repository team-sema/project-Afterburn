extends SceneTree


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	_test_trait_lifetime_multipliers(world)
	_test_lifetime_is_position_independent(world)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("shotgun pellet lifetime test: PASS")
		quit()
		return
	for failure in failures:
		push_error("shotgun pellet lifetime test: %s" % failure)
	quit(1)


func _test_trait_lifetime_multipliers(world: Node2D) -> void:
	var loadout := MockLoadout.new()
	world.add_child(loadout)
	var system := load("res://player_ship/weapons/shotgun_weapon_system.tscn").instantiate() as ShotgunWeaponSystem
	system.base_fire_interval = 100.0
	system.base_pellet_lifetime = 0.5
	world.add_child(system)
	system.setup_weapon(null, loadout, 0, &"main_shotgun")

	loadout.traits = {&"shotgun_choke": 1}
	var choke_pellet: Node = load("res://projectiles/player_shotgun_pellet.tscn").instantiate()
	system.call("_configure_projectile", choke_pellet, Vector2.UP)
	_expect(
		is_equal_approx(float(choke_pellet.get("_max_lifetime")), 0.7),
		"choke range modifier extends pellet lifetime",
	)
	choke_pellet.free()

	loadout.traits = {&"shotgun_cut_barrel": 1}
	var cut_pellet: Node = load("res://projectiles/player_shotgun_pellet.tscn").instantiate()
	system.call("_configure_projectile", cut_pellet, Vector2.UP)
	_expect(
		is_equal_approx(float(cut_pellet.get("_max_lifetime")), 0.425),
		"cut barrel range modifier shortens pellet lifetime",
	)
	cut_pellet.free()
	system.free()
	loadout.free()


func _test_lifetime_is_position_independent(world: Node2D) -> void:
	var spawner := SpawnerComponent.new()
	spawner.scene = load("res://projectiles/player_shotgun_pellet.tscn") as PackedScene
	world.add_child(spawner)
	var pellet := spawner.spawn(
		Vector2(400.0, 216.0),
		world,
		func(projectile: Node) -> void:
			projectile.call(
				"configure_shotgun_combat",
				null,
				4,
				Vector2(400.0, 216.0),
				0.5,
				1.0,
				80.0,
			),
	)
	pellet.set_process(false)
	pellet.call("_process", 0.0)
	_expect(not pellet.is_queued_for_deletion(), "far-away spawn survives its first frame")
	pellet.global_position = Vector2(1000.0, 1000.0)
	pellet.call("_process", 0.49)
	_expect(not pellet.is_queued_for_deletion(), "distance traveled does not consume pellet lifetime")
	pellet.call("_process", 0.02)
	_expect(pellet.is_queued_for_deletion(), "pellet expires after its configured lifetime")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
