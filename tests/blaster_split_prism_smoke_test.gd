extends SceneTree

## Prismatic split: a blaster shot splits into three fragments on its first hit,
## fragments skip every target their ancestors hit, and splitting stops after
## two steps. Targets A, B, C sit on the shot's straight path.

const BLASTER_SCENE := preload("res://projectiles/player_blaster.tscn")
const BLASTER_SCRIPT := preload("res://projectiles/player_blaster.gd")
const START := Vector2(100.0, 220.0)

var failures: PackedStringArray = []
var _hurt_counts: Dictionary = {}
var _spawned: Array[Node] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	world.child_entered_tree.connect(func(node: Node) -> void:
		if node.get_script() == BLASTER_SCRIPT:
			_spawned.append(node)
	)
	_make_enemy(world, "a", Vector2(100.0, 170.0))
	_make_enemy(world, "b", Vector2(100.0, 120.0))
	_make_enemy(world, "c", Vector2(100.0, 70.0))
	await physics_frame
	await physics_frame

	var shot := BLASTER_SCENE.instantiate()
	shot.call("configure_blaster_combat", null, 6, 0, 1.0, 0, [], 96.0)
	shot.call("configure_split", 3, 2, 90.0)
	(shot.get_node("MoveComponent") as MoveComponent).velocity = Vector2.UP * 200.0
	world.add_child(shot)
	shot.global_position = START

	for _i in 90:
		await physics_frame

	_expect(_hurt_counts["a"] == 1, "the shot hits A once (fragments skip A)")
	_expect(_hurt_counts["b"] == 1, "the middle fragment hits B once")
	_expect(_hurt_counts["c"] == 1, "the second-step middle fragment hits C")
	# 1 shot + 3 fragments at A + 3 fragments at B; the fragment that hits C does not split.
	_expect(_spawned.size() == 7, "two split steps spawn 6 fragments (got %d)" % (_spawned.size() - 1))

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("blaster_split_prism_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("blaster_split_prism_smoke_test: %s" % failure)
	quit(1)


func _make_enemy(world: Node2D, enemy_name: String, position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.name = enemy_name
	enemy.add_to_group("enemies")
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 1 << 1
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	hurtbox.add_child(shape)
	enemy.add_child(hurtbox)
	world.add_child(enemy)
	enemy.global_position = position
	_hurt_counts[enemy_name] = 0
	hurtbox.hurt.connect(func(_hitbox: Variant) -> void: _hurt_counts[enemy_name] += 1)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
