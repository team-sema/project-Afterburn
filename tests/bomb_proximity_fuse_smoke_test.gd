extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var scene: PackedScene = load("res://enemies/bomb_enemy.tscn")
	var enemy: Node2D = scene.instantiate() as Node2D
	enemy.set("augment_registry", EnemyAugmentRegistry.new())

	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(100, 80)
	world.add_child(player)
	world.add_child(enemy)
	enemy.global_position = Vector2(100, 40)

	var stats: StatsComponent = enemy.get_node("StatsComponent") as StatsComponent
	var move: MoveComponent = enemy.get_node("MoveComponent") as MoveComponent
	var fuse := enemy.get_node("BombProximityFuseComponent") as BombProximityFuseComponent
	var preview := enemy.get_node("BlastRadiusPreview") as BombBlastPreview
	if stats.health < 100:
		failures.append("bomb should have high health")
	if move.velocity.y > 25.0:
		failures.append("bomb should move slowly")
	if enemy.get_node_or_null("EnemyShootComponent") != null:
		failures.append("bomb should not shoot")
	var blast_radius := fuse.get_blast_radius()
	if blast_radius <= 0.0:
		failures.append("bomb damage radius should be positive")
	if not is_equal_approx(preview.radius, blast_radius):
		failures.append("blast preview radius should match damage radius")
	if preview.fill_color.a <= 0.0 or preview.fill_color.a >= 0.15:
		failures.append("blast preview should use a faint translucent fill")
	if preview.visible:
		failures.append("blast preview should stay hidden before the fuse arms")
	fuse.call("_spawn_blast_vfx")
	var effect := world.get_node_or_null("ExplosionEffect")
	if effect == null or not effect.has_method("get_effect_radius"):
		failures.append("bomb should spawn a measurable explosion VFX")
	elif not is_equal_approx(float(effect.call("get_effect_radius")), blast_radius):
		failures.append("explosion VFX radius should match damage radius")
	if effect != null:
		effect.free()

	# Trigger arming
	fuse.set("_armed", false)
	fuse.call("_start_arming")
	if move.velocity != Vector2.ZERO:
		failures.append("armed bomb should stop moving")
	if not preview.visible:
		failures.append("blast preview should appear when the fuse starts flashing")

	# Skip waits: call detonate path after forcing armed state
	fuse.call("_detonate")
	await process_frame
	if is_instance_valid(enemy) and stats.health > 0:
		failures.append("detonate should zero health")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("bomb_proximity_fuse_smoke_test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("bomb_proximity_fuse_smoke_test: FAIL")
		quit(1)
