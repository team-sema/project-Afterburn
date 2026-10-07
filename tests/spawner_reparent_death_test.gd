extends SceneTree

## Regression: a formation break reparents an enemy, and the hurtbox
## re-entering the tree fires the overlapping hitbox's area_entered
## synchronously, before later siblings (SpawnerComponent, drop components)
## have entered the tree. The resulting death chain used to crash with
## "Cannot call method 'get_first_node_in_group' on a null value".

var failures := PackedStringArray()
var registry: EnemyAugmentRegistry
var world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	registry = EnemyAugmentRegistry.new()
	registry.name = "SpawnerReparentTestRegistry"
	root.add_child(registry)
	world = Node2D.new()
	world.name = "GameplayWorld"
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.position = Vector2(200.0, 600.0)
	world.add_child(player)
	await process_frame

	await _test_spawn_while_spawner_is_outside_tree()
	await _test_enemy_killed_during_reparent_spawns_destroy_effect()

	world.queue_free()
	registry.queue_free()
	await process_frame

	if failures.is_empty():
		print("spawner_reparent_death_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("spawner_reparent_death_test: %s" % failure)
	quit(1)


## Minimal reproduction: SpawnerComponent is a later sibling of the hurtbox
## and spawn() is called from area_entered during the parent's reparent.
func _test_spawn_while_spawner_is_outside_tree() -> void:
	var hitbox := _make_area(true, 2)
	hitbox.name = "ProbeHitbox"
	world.add_child(hitbox)

	var actor := Node2D.new()
	actor.name = "ProbeActor"
	var hurtbox := _make_area(false, 0)
	hurtbox.name = "ProbeHurtbox"
	hurtbox.collision_layer = 2
	actor.add_child(hurtbox)
	var spawner := SpawnerComponent.new()
	spawner.name = "LaterSpawner"
	spawner.scene = load("res://effects/explosion_effect.tscn") as PackedScene
	actor.add_child(spawner)
	world.add_child(actor)

	var other_parent := Node2D.new()
	other_parent.name = "OtherParent"
	world.add_child(other_parent)

	var in_reparent := [false]
	var spawned: Array[Node] = []
	var spawner_in_tree_at_fire := [true]
	hitbox.area_entered.connect(func(_area: Area2D) -> void:
		if not in_reparent[0]:
			return
		spawner_in_tree_at_fire[0] = spawner.is_inside_tree()
		spawned.append(spawner.spawn(Vector2(123.0, 45.0)))
	)
	await physics_frame
	await physics_frame
	await physics_frame
	_expect(hitbox.get_overlapping_areas().has(hurtbox), "probe hitbox overlaps the hurtbox before reparent")

	in_reparent[0] = true
	actor.reparent(other_parent, true)
	in_reparent[0] = false

	_expect(spawned.size() == 1, "area_entered fires synchronously during reparent and reaches spawn()")
	_expect(not spawner_in_tree_at_fire[0], "spawner sibling is still outside the tree when the hit lands")
	if spawned.size() == 1:
		var effect := spawned[0]
		_expect(is_instance_valid(effect), "spawn() returns a live instance while outside the tree")
		_expect(effect.get_parent() == world, "spawn() falls back to the gameplay_world parent")
		_expect(
			(effect as Node2D).global_position.is_equal_approx(Vector2(123.0, 45.0)),
			"spawned instance keeps the requested global position",
		)
		effect.queue_free()

	hitbox.queue_free()
	actor.queue_free()
	other_parent.queue_free()
	await process_frame


## Full chain through the real enemy scene: an overlapping HitboxComponent
## kills the enemy during reparent; the destroy effect lands in the world
## and the enemy still dies cleanly.
func _test_enemy_killed_during_reparent_spawns_destroy_effect() -> void:
	var enemy := (load("res://enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.position = Vector2(200.0, 100.0)
	_add_circle_shape(enemy.get_node("HurtboxComponent") as Area2D)
	world.add_child(enemy)

	var hitbox := HitboxComponent.new()
	hitbox.name = "KillHitbox"
	hitbox.monitoring = true
	hitbox.monitorable = false
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.damage = 9999
	_add_circle_shape(hitbox)
	hitbox.position = enemy.position
	var armed := [false]
	hitbox.hit_filter = func(_hurtbox: HurtboxComponent) -> bool: return armed[0]
	world.add_child(hitbox)

	var release_parent := Node2D.new()
	release_parent.name = "ReleaseParent"
	world.add_child(release_parent)

	await physics_frame
	await physics_frame
	await physics_frame
	var hurtbox := enemy.get_node("HurtboxComponent") as HurtboxComponent
	_expect(hitbox.get_overlapping_areas().has(hurtbox), "kill hitbox overlaps the enemy hurtbox before reparent")
	_expect(is_instance_valid(enemy) and not bool(enemy.get("_is_dying")), "filtered hit leaves the enemy alive")

	var effects_before := _count_effects()
	armed[0] = true
	enemy.reparent(release_parent, true)

	_expect(bool(enemy.get("_is_dying")), "enemy dies from the hit delivered during reparent")
	_expect(
		_count_effects() == effects_before + 1,
		"destroy effect spawns into gameplay_world even though the spawner was outside the tree",
	)
	await process_frame
	_expect(not is_instance_valid(enemy), "enemy is freed after dying mid-reparent")

	for child in world.get_children():
		if child.scene_file_path == "res://effects/explosion_effect.tscn":
			child.queue_free()
	hitbox.queue_free()
	release_parent.queue_free()
	await process_frame


func _count_effects() -> int:
	var count := 0
	for child in world.get_children():
		if child.scene_file_path == "res://effects/explosion_effect.tscn":
			count += 1
	return count


func _make_area(monitoring: bool, mask: int) -> Area2D:
	var area := Area2D.new()
	area.monitoring = monitoring
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = mask
	_add_circle_shape(area)
	return area


func _add_circle_shape(area: Area2D) -> void:
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	area.add_child(shape)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
