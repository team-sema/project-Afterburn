extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var projectile_scene: PackedScene = load("res://projectiles/base_enemy_projectile.tscn")
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	root.add_child(projectile)
	var hitbox: Area2D = projectile.get_node("HitboxComponent") as Area2D
	var move: MoveComponent = projectile.get_node("MoveComponent") as MoveComponent

	_expect(hitbox.collision_mask == 1, "base enemy projectile targets the player hurtbox layer")
	projectile.call("launch", Vector2.RIGHT, 120.0)
	_expect(move.velocity.is_equal_approx(Vector2(120.0, 0.0)), "launch sets straight velocity")
	var start_position := projectile.position
	move.call("_process", 0.5)
	_expect(projectile.position.x > start_position.x, "projectile moves in its launch direction")
	_expect(is_equal_approx(projectile.position.y, start_position.y), "projectile does not curve")

	var default_shoot_scene := load("res://components/enemy_shoot_component.tscn") as PackedScene
	var default_shoot := default_shoot_scene.instantiate() as EnemyShootComponent
	_expect(
		default_shoot.projectile_scene.resource_path == "res://projectiles/base_enemy_projectile.tscn",
		"base enemies use the straight projectile",
	)
	var shooting_enemy_scene := load("res://enemies/shooting_enemy/shooting_enemy.tscn") as PackedScene
	var shooting_enemy := shooting_enemy_scene.instantiate() as Node2D
	var shooting_enemy_fire: Node = shooting_enemy.get_node("EnemyShootComponent")
	_expect(
		shooting_enemy_fire.projectile_scene.resource_path == "res://projectiles/curve_projectile.tscn",
		"shooting enemy keeps its curved projectile",
	)
	projectile.queue_free()
	default_shoot.free()
	shooting_enemy.free()
	await process_frame

	if failures.is_empty():
		print("base enemy projectile smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("base enemy projectile smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
