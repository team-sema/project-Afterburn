extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var lab := preload("res://labs/bosses/octagon/octagon_boss_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var boss: Node2D = lab.boss
	check(boss.parts.size() == 8, "Eight physical turret modules")
	check(boss.global_position.y < 0, "Rotation center remains above the playfield")
	for part in boss.parts:
		check(is_equal_approx(part.position.length(),240), "All modules share the ring radius")
	check(boss.parts[0].global_position.distance_to(Vector2(241.84,89.73)) < 1, "Right module occupies the intended cropped combat frame")
	check(boss.parts[1].global_position.distance_to(Vector2(58.16,89.73)) < 1, "Left module occupies the intended cropped combat frame")
	await create_timer(0.7).timeout
	check(boss.parts.filter(func(p): return p.active).size() == 2, "Only two aligned modules engage")
	var before: int = boss.health
	boss.parts[4].take_damage(9999)
	check(boss.health == before, "Offscreen modules reject damage")
	lab.ship.position = Vector2(242,280)
	await create_timer(1.5).timeout
	check(boss.health < before, "Actual ship blaster hits an exposed module")
	check(boss.parts[0].volleys > 0 and boss.parts[1].volleys > 0, "Both common weapons emit real volleys")
	var enemy_shot := BarrageShot.new()
	enemy_shot.appearance = preload("res://resources/projectiles/round.tres")
	enemy_shot.behavior = BulletBehavior.new()
	enemy_shot.spawn(lab.world,lab.ship.position+Vector2(0,-3),Vector2.DOWN,20)
	await create_timer(0.2).timeout
	check(lab.hits > 0, "Enemy projectiles record hits in survival training")
	lab.ship.position.x = 150
	boss.parts[0].take_damage(9999)
	var after: int = boss.health
	boss.parts[0].take_damage(9999)
	check(boss.health == after and not boss.parts[0].active, "Destroyed module rejects duplicate damage")
	check(is_instance_valid(boss.parts[0]) and boss.parts[0].get_parent() == boss.rotor, "Wreck remains mounted")
	boss.next_pair()
	await create_timer(0.55).timeout
	check(boss.parts.all(func(p): return not p.active), "All weapons disable during rotation")
	var frozen_angle: float = boss.rotor.rotation
	var frozen_age: float = boss.age
	lab.toggle_pause()
	await create_timer(0.2,true).timeout
	check(is_equal_approx(boss.rotor.rotation,frozen_angle) and is_equal_approx(boss.age,frozen_age), "Pause freezes turn and combat clock")
	lab.toggle_pause()
	await create_timer(2.5).timeout
	check(boss.pair_index == 1 and boss.parts[1].active and boss.parts[2].active, "One step keeps a neighbor and introduces the next module")
	check(is_equal_approx(boss.rotor.rotation,-PI/4), "Ring and mounted hardware rotate by 45 degrees")
	# Accelerate only the boss timeline to walk the whole circumference.
	boss.set_process(false)
	for cycle in 8:
		for index in boss.active_indices(): boss.parts[index].take_damage(9999)
		if boss.defeated: break
		boss.next_pair()
		boss._process(0.5)
		boss._process(4.0)
		boss._process(0.6)
	check(boss.defeated and boss.health == 0 and boss.parts.all(func(p): return not p.active), "Destroying all eight ends combat without respawning hardware")
	await process_frame
	check(EnemyBullets.get_all(lab.world).is_empty(), "Completion clears surviving enemy bullets")
	lab.toggle_pause()
	lab.restart()
	await process_frame
	await process_frame
	check(not paused and lab.boss.health == 1440 and lab.boss.parts.size() == 8, "Restart from pause restores eight fresh modules")
	check(lab.viewport.get_children().size() == 1, "Restart disposes the entire previous world")
	lab.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: Octagon Boss Lab")
	else: print("FAIL: Octagon Boss Lab: ",failures)
	quit(0 if failures.is_empty() else 1)
