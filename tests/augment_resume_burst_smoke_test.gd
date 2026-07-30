extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var gameplay: Node2D = world.get_node(
		"Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay"
	) as Node2D
	var offer_controller: AugmentOfferController = gameplay.get_node("AugmentOfferController")
	var ship: Node2D = gameplay.get_node("Ship") as Node2D

	var straight_scene := load("res://projectiles/base_enemy_projectile.tscn") as PackedScene
	var curve_scene := load("res://projectiles/curve_projectile.tscn") as PackedScene
	var player_scene := load("res://projectiles/player_blaster.tscn") as PackedScene
	var near_straight := _add_projectile(straight_scene, gameplay, ship.global_position + Vector2(10.0, 0.0))
	var near_curve := _add_projectile(curve_scene, gameplay, ship.global_position + Vector2(0.0, -20.0))
	var far_straight := _add_projectile(straight_scene, gameplay, ship.global_position + Vector2(50.0, 0.0))
	var player_projectile := _add_projectile(player_scene, gameplay, ship.global_position + Vector2(5.0, 0.0))

	_expect(near_straight.is_in_group("enemy_projectiles"), "straight enemy projectile is clearable")
	_expect(near_curve.is_in_group("enemy_projectiles"), "curved enemy projectile is clearable")
	var cleared_count := offer_controller.call("_trigger_player_resume_burst") as int
	_expect(cleared_count == 2, "resume burst clears only nearby enemy projectiles")
	await process_frame
	_expect(not is_instance_valid(near_straight), "nearby straight projectile is removed")
	_expect(not is_instance_valid(near_curve), "nearby curved projectile is removed")
	_expect(is_instance_valid(far_straight), "enemy projectile outside the radius remains")
	_expect(is_instance_valid(player_projectile), "player projectile inside the radius remains")
	_expect(gameplay.get_node_or_null("AugmentResumeBurst") != null, "resume burst effect is spawned")

	if failures.is_empty():
		print("augment resume burst smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("augment resume burst smoke test: %s" % failure)
	quit(1)


func _add_projectile(scene: PackedScene, parent: Node2D, position: Vector2) -> Node2D:
	var projectile := scene.instantiate() as Node2D
	projectile.global_position = position
	parent.add_child(projectile)
	return projectile


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
