extends SceneTree

## Field weapon pickups are retired; assert drops stay off and XP knobs remain data-driven.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := load("res://world.tscn").instantiate() as Control
	root.add_child(world)
	for _i in 3:
		await process_frame

	_expect(
		world.get_node_or_null("Layout/Playfield/WeaponPickupLabels") == null,
		"weapon pickup label host is removed",
	)

	var enemy := load("res://enemies/enemy.tscn").instantiate() as Node2D
	world.add_child(enemy)
	enemy.global_position = Vector2(80, 80)
	var weapon_drop := enemy.get_node("WeaponDropComponent") as WeaponDropComponent
	_expect(weapon_drop.enabled == false, "weapon drops disabled")
	var xp := enemy.get_node("ExperienceDropComponent") as ExperienceDropComponent
	_expect(xp.drop_chance > 0.5, "XP drop frequency slightly raised from legacy 0.5")
	_expect(xp.experience_amount == 1, "per-orb XP value unchanged on base enemy")

	# Killing should not spawn a WeaponPickup.
	var before := _count_pickups(world)
	var stats := enemy.get_node("StatsComponent") as StatsComponent
	stats.health = 0
	stats.no_health.emit()
	await process_frame
	await process_frame
	_expect(_count_pickups(world) == before, "no weapon pickup spawned on death")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon pickup physics test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon pickup physics test: %s" % failure)
	quit(1)


func _count_pickups(root: Node) -> int:
	var count := 0
	for node in root.get_tree().get_nodes_in_group(""):
		pass
	for child in root.get_children():
		count += _count_weapon_pickups_recursive(child)
	return count


func _count_weapon_pickups_recursive(node: Node) -> int:
	var count := 0
	if node is WeaponPickup:
		count += 1
	for child in node.get_children():
		count += _count_weapon_pickups_recursive(child)
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
