extends SceneTree

## bomb_drone_diamond escorts home on the player only while their Bomb lives.
## Once the Bomb is gone (shot before arming, shot mid-fuse, or detonated) the
## surviving Drones must leave formation instead of chasing or hovering forever.

const PRESET_PATH := "res://resources/encounters/presets/bomb_drone_diamond.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := PackedStringArray()
	var world := Node2D.new()
	world.name = "TestWorld"
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var player := Node2D.new()
	player.name = "TestPlayer"
	player.add_to_group("player")
	root.add_child(player)
	var registry := EnemyAugmentRegistry.new()
	root.add_child(registry)
	var spawner := EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	root.add_child(spawner)

	var preset := load(PRESET_PATH) as EncounterPreset
	_expect(failures, preset != null and preset.validate(true), "bomb_drone_diamond preset is valid")
	if failures.is_empty():
		await _check_bomb_shot_before_arming(failures, spawner, preset, player)
		await _check_bomb_shot_mid_fuse(failures, spawner, preset, player)
		await _check_bomb_detonation(failures, spawner, preset, player)

	if is_instance_valid(spawner):
		spawner.queue_free()
	if is_instance_valid(registry):
		registry.queue_free()
	player.queue_free()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("bomb_drone_diamond_core_loss_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("bomb_drone_diamond_core_loss_test: FAIL")
	quit(1)


func _check_bomb_shot_before_arming(
	failures: PackedStringArray,
	spawner: EnemySpawner,
	preset: EncounterPreset,
	player: Node2D,
) -> void:
	var controller := spawner.spawn_encounter(preset)
	var bomb := _find_bomb(controller)
	_expect(failures, bomb != null, "before arming: encounter spawns a Bomb member")
	if bomb == null:
		_free_encounter(controller)
		return
	# Keep the player far outside the fuse radius so the Bomb never arms.
	player.global_position = controller.global_position + Vector2(0.0, 260.0)
	await create_timer(0.3).timeout
	var drones := _surviving_drones(controller, bomb)
	_expect(failures, drones.size() == 4, "before arming: four escort Drones are bound")
	for drone in drones:
		_expect(failures, drone.is_formation_member(), "before arming: Drone escorts in formation")

	bomb.stats_component.health = 0
	await create_timer(0.3).timeout
	await _expect_released(failures, drones, player, "bomb shot before arming")
	_free_encounter(controller, drones)
	await process_frame


func _check_bomb_shot_mid_fuse(
	failures: PackedStringArray,
	spawner: EnemySpawner,
	preset: EncounterPreset,
	player: Node2D,
) -> void:
	var controller := spawner.spawn_encounter(preset)
	var bomb := _find_bomb(controller)
	_expect(failures, bomb != null, "mid fuse: encounter spawns a Bomb member")
	if bomb == null:
		_free_encounter(controller)
		return
	var drones := _surviving_drones(controller, bomb)
	# Inside the fuse radius: the Bomb detaches and the wing freezes.
	player.global_position = bomb.global_position + Vector2(0.0, 40.0)
	await create_timer(0.4).timeout
	_expect(failures, not bomb.is_formation_member(), "mid fuse: arming Bomb detaches")
	for drone in drones:
		_expect(failures, drone.is_formation_member(), "mid fuse: Drones hold formation while Bomb arms")
	var arming_position := bomb.global_position
	await create_timer(0.2).timeout
	_expect(
		failures,
		bomb.global_position.distance_to(arming_position) < 0.5,
		"mid fuse: detached Bomb does not take the escort scatter path",
	)

	player.global_position = bomb.global_position + Vector2(0.0, 400.0)
	bomb.stats_component.health = 0
	await create_timer(0.3).timeout
	await _expect_released(failures, drones, player, "bomb shot mid fuse")
	_free_encounter(controller, drones)
	await process_frame


func _check_bomb_detonation(
	failures: PackedStringArray,
	spawner: EnemySpawner,
	preset: EncounterPreset,
	player: Node2D,
) -> void:
	var controller := spawner.spawn_encounter(preset)
	var bomb := _find_bomb(controller)
	_expect(failures, bomb != null, "detonation: encounter spawns a Bomb member")
	if bomb == null:
		_free_encounter(controller)
		return
	var drones := _surviving_drones(controller, bomb)
	var fuse := bomb.get_node("BombProximityFuseComponent") as BombProximityFuseComponent
	player.global_position = bomb.global_position + Vector2(0.0, 40.0)
	await create_timer(fuse.arm_duration + 0.5).timeout
	_expect(failures, not is_instance_valid(bomb), "detonation: Bomb self-destructs")
	for drone in drones:
		if is_instance_valid(drone):
			_expect(
				failures,
				not drone.is_formation_member(),
				"detonation: a Drone outside the blast leaves formation",
			)
	_free_encounter(controller, drones)
	await process_frame


func _expect_released(
	failures: PackedStringArray,
	drones: Array[Enemy],
	player: Node2D,
	label: String,
) -> void:
	var alive := 0
	for drone in drones:
		if not is_instance_valid(drone):
			continue
		alive += 1
		_expect(failures, not drone.is_formation_member(), "%s: Drone leaves formation" % label)
	_expect(failures, alive > 0, "%s: escorts survive the Bomb kill" % label)
	# Park the player above the wing: a homing escort would climb toward it,
	# a released one keeps scattering away (and does not hover in place).
	var top := INF
	for drone in drones:
		if is_instance_valid(drone):
			top = minf(top, drone.global_position.y)
	player.global_position = Vector2(player.global_position.x, top - 200.0)
	var start_positions := {}
	for drone in drones:
		if is_instance_valid(drone):
			start_positions[drone.get_instance_id()] = drone.global_position
	var before := _distances(drones, player)
	await create_timer(0.6).timeout
	var after := _distances(drones, player)
	for drone in drones:
		if not is_instance_valid(drone):
			continue
		var id := drone.get_instance_id()
		if not before.has(id):
			continue
		_expect(
			failures,
			float(after[id]) > float(before[id]) + 1.0,
			"%s: released Drone stops homing on the player" % label,
		)
		_expect(
			failures,
			drone.global_position.distance_to(start_positions[id] as Vector2) > 20.0,
			"%s: released Drone keeps moving instead of hovering" % label,
		)


func _distances(drones: Array[Enemy], player: Node2D) -> Dictionary:
	var result := {}
	for drone in drones:
		if is_instance_valid(drone):
			result[drone.get_instance_id()] = drone.global_position.distance_to(player.global_position)
	return result


func _find_bomb(controller: FormationController) -> Enemy:
	if controller == null:
		return null
	for member in controller.get_members():
		if member.get_node_or_null("BombProximityFuseComponent") != null:
			return member
	return null


func _surviving_drones(controller: FormationController, bomb: Enemy) -> Array[Enemy]:
	var drones: Array[Enemy] = []
	for member in controller.get_members():
		if member != bomb:
			drones.append(member)
	return drones


func _free_encounter(controller: Variant, drones: Array[Enemy] = []) -> void:
	for drone in drones:
		if is_instance_valid(drone):
			drone.queue_free()
	if is_instance_valid(controller):
		(controller as Node).queue_free()


func _expect(failures: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
