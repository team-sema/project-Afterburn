extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	root.add_child(gameplay)
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	var reward := gameplay.get_node("BulletCancelRewardController") as BulletCancelRewardController
	var collector := gameplay.get_node("Ship/ExperienceCollector") as Area2D
	progression.set_process(false)
	gameplay.get_node("EnemyGenerator").spawn_timer.stop()

	var existing_orb := (load("res://pickups/experience_orb.tscn") as PackedScene).instantiate() as ExperienceOrb
	gameplay.add_child(existing_orb)
	existing_orb.setup(4, collector.global_position + Vector2(90.0, -80.0))

	var straight_enemy_bullet := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	var curved_enemy_bullet := (load("res://projectiles/curve_projectile.tscn") as PackedScene).instantiate() as Node2D
	var deferred_enemy_bullet := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	var player_bullet := (load("res://projectiles/player_blaster.tscn") as PackedScene).instantiate() as Node2D
	gameplay.add_child(straight_enemy_bullet)
	gameplay.add_child(curved_enemy_bullet)
	gameplay.add_child(player_bullet)
	straight_enemy_bullet.global_position = collector.global_position + Vector2(-70.0, -120.0)
	curved_enemy_bullet.global_position = collector.global_position + Vector2(80.0, -140.0)
	deferred_enemy_bullet.global_position = collector.global_position + Vector2(110.0, -100.0)
	player_bullet.global_position = collector.global_position + Vector2(0.0, -60.0)
	for preset in ["round", "orb"]:
		var foundation := (load("res://projectiles/foundation_bullet.tscn") as PackedScene).instantiate() as FoundationBullet
		foundation.appearance = load("res://resources/projectiles/%s.tres" % preset)
		foundation.behavior = load("res://resources/projectiles/wave_behavior.tres")
		gameplay.add_child(foundation)
		foundation.global_position = collector.global_position + Vector2(30, -100)
		foundation.launch(Vector2.DOWN, 95)

	var laser := (load("res://projectiles/curved_laser.tscn") as PackedScene).instantiate() as CurvedLaser
	gameplay.add_child(laser)
	laser.global_position = collector.global_position + Vector2(0, -120)
	laser.launch(Vector2.DOWN, 90)
	laser._physics_process(0.8)
	paused = true
	gameplay.add_child.call_deferred(deferred_enemy_bullet)
	var converted_count := await reward.collect_projectiles_and_vacuum()
	await process_frame

	_expect(converted_count == 6, "each projectile and whole curved laser becomes one XP orb")
	_expect(get_nodes_in_group("enemy_projectiles").is_empty(), "converted enemy projectiles are cleared")
	_expect(not is_instance_valid(deferred_enemy_bullet), "same-frame deferred enemy projectiles are cleared")
	_expect(is_instance_valid(player_bullet), "player projectiles are preserved")
	_expect(progression.current_experience == 10, "existing XP and converted bullets are collected")
	_expect(not reward.is_active, "reward sequence finishes after every attracted orb is collected")

	paused = false
	gameplay.queue_free()
	await process_frame
	if failures.is_empty():
		print("bullet cancel reward smoke test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("bullet cancel reward smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
