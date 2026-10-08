extends SceneTree

## Base Bomb falls straight. The Courier flies one big arc that passes beside
## the player, drops a stationary Bomb that is lit at once (also when shot
## down), and curves away out of the screen without twitching on jitter.

const BOMB_PAIR_PATH := "res://resources/encounters/presets/bomb_pair.tres"
const COURIER_PATH := "res://resources/encounters/presets/courier_single.tres"
const EPSILON := 0.5

var failures := PackedStringArray()
var world: Node2D
var player: Node2D
var spawner: EnemySpawner
var registry: EnemyAugmentRegistry


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.name = "TestWorld"
	world.add_to_group("gameplay_world")
	root.add_child(world)
	player = Node2D.new()
	player.name = "TestPlayer"
	player.add_to_group("player")
	root.add_child(player)
	registry = EnemyAugmentRegistry.new()
	root.add_child(registry)
	spawner = EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	root.add_child(spawner)

	await _test_bomb_pair()
	await _test_courier_arc_and_drop()
	await _test_courier_ignores_jitter()
	await _test_courier_shot_down_drops_lit_bomb()

	spawner.queue_free()
	registry.queue_free()
	player.queue_free()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("bomb_courier_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("bomb_courier_test: FAIL")
	quit(1)


func _test_bomb_pair() -> void:
	var preset := load(BOMB_PAIR_PATH) as EncounterPreset
	_expect(preset != null and preset.validate(true), "bomb_pair preset is valid")
	if preset == null:
		return
	player.global_position = Vector2(320.0, 340.0)
	spawner.spawn_encounter(preset)
	await process_frame
	await process_frame
	var bombs := _live_bombs()
	_expect(bombs.size() == 2, "bomb_pair spawns two Bombs")
	if bombs.size() != 2:
		_clear_enemies()
		return
	for bomb in bombs:
		_expect(not bomb.is_formation_member(), "bomb_pair releases each Bomb immediately")
	_expect(
		is_equal_approx(absf(bombs[0].global_position.x - bombs[1].global_position.x), 160.0),
		"bomb_pair Bombs are 160px apart",
	)
	var starts: Array[Vector2] = [bombs[0].global_position, bombs[1].global_position]
	await create_timer(0.5).timeout
	for index in bombs.size():
		var moved := bombs[index].global_position - starts[index]
		_expect(absf(moved.x) < EPSILON, "base Bomb falls straight down")
		_expect(moved.y > 17.0 and moved.y < 23.0, "base Bomb falls at 40px/s (moved %.1f)" % moved.y)
	_clear_enemies()
	await process_frame


func _test_courier_arc_and_drop() -> void:
	var preset := load(COURIER_PATH) as EncounterPreset
	_expect(preset != null and preset.validate(true), "courier_single preset is valid")
	if preset == null:
		return
	# The Courier enters from the top edge farther from the player.
	player.global_position = Vector2(480.0, 300.0)
	spawner.spawn_encounter(preset)
	await process_frame
	var courier := _find_courier()
	_expect(courier != null, "courier_single spawns a Courier")
	if courier == null:
		return
	_expect(courier.global_position.x < 100.0, "Courier enters on the side away from the player")
	var flight := await _fly_until_drop(courier, Callable())
	if not is_instance_valid(courier):
		_expect(false, "Courier survives until the drop")
		return
	var carrier := courier.get_node("BombCourierComponent") as BombCourierComponent
	_expect(carrier.has_dropped(), "Courier reaches the drop point")
	_expect(bool(flight["always_descending"]), "Courier never climbs on its approach")
	_expect(
		float(flight["max_turn_rate"]) <= deg_to_rad(120.0) * 1.15,
		"Courier turns no faster than 120 deg/s (%.0f)" % rad_to_deg(float(flight["max_turn_rate"])),
	)
	_expect(float(flight["reversal"]) < 0.02, "Courier bends one way on a clean arc")
	_expect(
		float(flight["sagitta"]) > 40.0,
		"approach reads as a big arc, not a line (%.0f px off the chord)" % float(flight["sagitta"]),
	)
	_expect(not (courier.get_node("Anchor/CarriedBomb") as Node2D).visible, "carried Bomb sprite hides")
	await process_frame
	var bombs := _live_bombs()
	_expect(bombs.size() == 1, "Courier drops exactly one Bomb")
	if bombs.size() == 1:
		var mine := bombs[0]
		var gap := mine.global_position.distance_to(player.global_position)
		_expect(gap <= 60.0, "Bomb lands within blast range of the player (%.0f px)" % gap)
		await process_frame
		_expect((mine.get_node("BlastRadiusPreview") as CanvasItem).visible, "dropped Bomb is lit at once")
	# Exit: curve away from the player and boost out without ramming them.
	var closest := INF
	var watch_time := 0.0
	var start_side := signf(courier.global_position.x - player.global_position.x)
	while is_instance_valid(courier) and watch_time < 0.6:
		await process_frame
		watch_time += root.get_process_delta_time()
		if is_instance_valid(courier):
			closest = minf(closest, courier.global_position.distance_to(player.global_position))
	_expect(closest > 20.0, "Courier passes the player at a distance (%.0f px)" % closest)
	if is_instance_valid(courier):
		var velocity := courier.move_component.velocity
		_expect(velocity.length() > 290.0, "Courier boosts out after the drop")
		_expect(signf(velocity.x) == start_side, "Courier curves away from the player")
		# Moving the player across must not pull it back.
		player.global_position.x = courier.global_position.x + start_side * 120.0
		await create_timer(0.15).timeout
		if is_instance_valid(courier):
			_expect(
				signf(courier.move_component.velocity.x) == start_side,
				"released Courier no longer chases the player",
			)
	_clear_enemies()
	await process_frame


func _test_courier_ignores_jitter() -> void:
	var preset := load(COURIER_PATH) as EncounterPreset
	var base := Vector2(320.0, 300.0)
	player.global_position = base
	spawner.spawn_encounter(preset)
	await process_frame
	var courier := _find_courier()
	if courier == null:
		_expect(false, "jitter Courier spawns")
		return
	# The player shakes left and right 30px at 3Hz all the way in.
	var shake := func(t: float) -> void:
		player.global_position = base + Vector2(sin(t * TAU * 3.0) * 30.0, 0.0)
	var flight := await _fly_until_drop(courier, shake)
	_expect(
		float(flight["max_turn_rate"]) <= deg_to_rad(120.0) * 1.15,
		"jitter does not whip the nose around (%.0f deg/s)" % rad_to_deg(float(flight["max_turn_rate"])),
	)
	_expect(
		float(flight["reversal"]) < 0.02,
		"jitter does not make the nose nod (%.3f rad of back-turning)" % float(flight["reversal"]),
	)
	_clear_enemies()
	await process_frame


## Flies the Courier until it drops, sampling its heading. `drive` gets the
## elapsed time each frame (to move the player).
func _fly_until_drop(courier: Enemy, drive: Callable) -> Dictionary:
	var carrier := courier.get_node("BombCourierComponent") as BombCourierComponent
	var start := courier.global_position
	var points: Array[Vector2] = []
	var always_descending := true
	var max_turn_rate := 0.0
	var turn_sum := 0.0
	var reversal := 0.0
	var last_angle := NAN
	var elapsed := 0.0
	while is_instance_valid(courier) and not carrier.has_dropped() and elapsed < 8.0:
		await process_frame
		var delta := root.get_process_delta_time()
		elapsed += delta
		if drive.is_valid():
			drive.call(elapsed)
		if not is_instance_valid(courier) or carrier.has_dropped():
			break
		var velocity := courier.move_component.velocity
		if velocity.y <= 0.0:
			always_descending = false
		points.append(courier.global_position)
		var angle := Vector2.DOWN.angle_to(velocity)
		if not is_nan(last_angle) and delta > 0.0:
			var step := angle_difference(last_angle, angle)
			max_turn_rate = maxf(max_turn_rate, absf(step) / delta)
			turn_sum += step
			if not is_zero_approx(step) and signf(step) != signf(turn_sum):
				reversal += absf(step)
		last_angle = angle
	var sagitta := 0.0
	if points.size() > 1:
		var chord := points[-1] - start
		if chord.length() > 0.0:
			for point in points:
				sagitta = maxf(sagitta, absf(chord.normalized().cross(point - start)))
	return {
		"always_descending": always_descending,
		"max_turn_rate": max_turn_rate,
		"reversal": reversal,
		"sagitta": sagitta,
	}


func _test_courier_shot_down_drops_lit_bomb() -> void:
	var preset := load(COURIER_PATH) as EncounterPreset
	player.global_position = Vector2(320.0, 340.0)
	spawner.spawn_encounter(preset)
	await process_frame
	var courier := _find_courier()
	_expect(courier != null, "second Courier spawns")
	if courier == null:
		return
	await create_timer(0.6).timeout
	var carrier := courier.get_node("BombCourierComponent") as BombCourierComponent
	_expect(not carrier.has_dropped(), "Courier has not dropped before passing the player")
	var death_position := (courier.get_node("Anchor/CarriedBomb") as Node2D).global_position
	courier.stats_component.health = 0
	await process_frame
	await process_frame
	var bombs := _live_bombs()
	_expect(bombs.size() == 1, "shot-down Courier drops its Bomb")
	if bombs.size() != 1:
		_clear_enemies()
		return
	var mine := bombs[0]
	_expect(
		mine.global_position.distance_to(death_position) < 2.0,
		"Bomb drops from the Courier's tail where it was shot down",
	)
	_expect(
		(mine.get_node("BlastRadiusPreview") as CanvasItem).visible,
		"Bomb from a shot-down Courier is lit at once",
	)
	var mine_start := mine.global_position
	await create_timer(0.5).timeout
	_expect(
		is_instance_valid(mine) and mine.global_position.distance_to(mine_start) < EPSILON,
		"dropped Bomb holds its position",
	)
	await create_timer(2.8).timeout
	_expect(not is_instance_valid(mine), "dropped Bomb self-destructs after its 3s fuse")
	_clear_enemies()
	await process_frame


func _live_bombs() -> Array[Enemy]:
	var bombs: Array[Enemy] = []
	for node in get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if (
			enemy != null
			and not enemy.is_queued_for_deletion()
			and enemy.get_node_or_null("BombProximityFuseComponent") != null
		):
			bombs.append(enemy)
	return bombs


func _find_courier() -> Enemy:
	for node in get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.get_node_or_null("BombCourierComponent") != null:
			return enemy
	return null


func _clear_enemies() -> void:
	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	for child in world.get_children():
		child.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
