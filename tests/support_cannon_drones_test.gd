extends SceneTree

class FakeLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}

	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits.duplicate()


var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)

	var loadout := FakeLoadout.new()
	world.add_child(loadout)
	var system := load(
		"res://player_ship/weapons/auxiliary_cannon_weapon_system.tscn"
	).instantiate() as AuxiliaryCannonWeaponSystem
	world.add_child(system)
	system.setup_weapon(null, loadout, 0, &"aux_test_cannon")
	await process_frame
	(system.get_node("FireRateTimer") as Timer).stop()
	system.set_process(false)
	_expect(
		is_equal_approx(system.drone_distance_speed_gain_percent, 15.0),
		"distance speed gain loads as 15%% (actual %.3f)"
		% system.drone_distance_speed_gain_percent,
	)
	_expect(
		is_equal_approx(system.drone_max_distance_speed_bonus, 50.0),
		"distance speed cap loads as 50 (actual %.3f)" % system.drone_max_distance_speed_bonus,
	)

	_expect(system.get_support_drone_count() == 2, "base formation has two support drones")
	_expect_formation(
		system.get_support_drone_positions(),
		[Vector2(-18, 0), Vector2(18, 0)],
		"base formation",
	)

	system.global_position = Vector2(60, 0)
	var left_start := (system.get_node("SupportDrone1") as Node2D).global_position
	var right_start := (system.get_node("SupportDrone2") as Node2D).global_position
	system.call("_process", 0.1)
	_expect_formation(
		system.get_support_drone_positions(),
		[Vector2(-6.83, 0), Vector2(28.63, 0)],
		"during delayed follow",
	)
	var moved_positions := system.get_support_drone_positions()
	_expect(
		left_start.distance_to(moved_positions[0]) > right_start.distance_to(moved_positions[1]),
		"opposite-side drone moves faster when the player moves right (left %.3f, right %.3f)"
		% [
			left_start.distance_to(moved_positions[0]),
			right_start.distance_to(moved_positions[1]),
		],
	)
	system.call("_process", 1.0)
	_expect_formation(
		system.get_support_drone_positions(),
		[Vector2(42, 0), Vector2(78, 0)],
		"restored base formation",
	)

	var near_drone := system.get_node("SupportDrone1") as Node2D
	var far_drone := system.get_node("SupportDrone2") as Node2D
	near_drone.global_position = Vector2(22, 0)
	far_drone.global_position = Vector2(-282, 0)
	var near_start := near_drone.global_position
	var far_start := far_drone.global_position
	system.call("_process", 0.1)
	var near_travel := near_start.distance_to(near_drone.global_position)
	var far_travel := far_start.distance_to(far_drone.global_position)
	_expect(
		far_travel > near_travel,
		"drone farther from the player receives a larger speed bonus (far %.3f, near %.3f)"
		% [far_travel, near_travel],
	)
	_expect(is_equal_approx(far_travel, 15.0), "distance speed bonus respects its maximum")
	system.call("_process", 3.0)

	system.fire()
	var base_projectiles := _collect_projectiles(world)
	_expect(base_projectiles.size() == 2, "both base support drones fire")
	_expect_projectiles_fly_forward(base_projectiles, 190.0, "base formation")
	_free_projectiles(base_projectiles)
	await process_frame

	loadout.traits[&"aux_heavy_barrel"] = 1
	loadout.weapon_trait_changed.emit(&"aux_test_cannon", &"aux_heavy_barrel", 1)
	await process_frame
	_expect(system.get_support_drone_count() == 4, "formation frame adds two support drones")
	_expect_formation(
		system.get_support_drone_positions(),
		[
			Vector2(42, 0),
			Vector2(78, 0),
			Vector2(31, 5),
			Vector2(89, 5),
		],
		"expanded formation",
	)

	system.fire()
	var expanded_projectiles := _collect_projectiles(world)
	_expect(expanded_projectiles.size() == 4, "all expanded support drones fire")
	_expect_projectiles_fly_forward(expanded_projectiles, 190.0, "expanded formation")
	for projectile in expanded_projectiles:
		var hitbox := projectile.get_node("HitboxComponent") as HitboxComponent
		_expect(hitbox.damage == 6, "formation frame applies per-drone damage multiplier")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("support cannon drones test: PASS")
		quit()
		return
	for failure in failures:
		push_error("support cannon drones test: %s" % failure)
	quit(1)


func _collect_projectiles(world: Node) -> Array[Node]:
	var projectiles: Array[Node] = []
	for child in world.get_children():
		if child.get_node_or_null("MoveComponent") == null:
			continue
		if child.get_node_or_null("HitboxComponent") == null:
			continue
		projectiles.append(child)
	return projectiles


func _free_projectiles(projectiles: Array[Node]) -> void:
	for projectile in projectiles:
		projectile.queue_free()


func _expect_formation(actual: Array[Vector2], expected: Array, label: String) -> void:
	_expect(actual.size() == expected.size(), "%s drone count matches" % label)
	if actual.size() != expected.size():
		return
	for index in actual.size():
		_expect(
			actual[index].is_equal_approx(expected[index]),
			"%s position %d matches (%s vs %s)" % [label, index, actual[index], expected[index]],
		)


func _expect_projectiles_fly_forward(
	projectiles: Array[Node],
	expected_speed: float,
	label: String,
) -> void:
	for projectile in projectiles:
		var move := projectile.get_node("MoveComponent") as MoveComponent
		_expect(
			move.velocity.is_equal_approx(Vector2.UP * expected_speed),
			"%s projectile flies straight forward" % label,
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
