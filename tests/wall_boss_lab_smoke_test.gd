extends SceneTree
## Boss Wall Lab: real wall + real ship, HUD, pause, defeat, restart, hub return.
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var lab := preload("res://labs/bosses/wall/wall_boss_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	await process_frame
	var boss: Enemy = lab.boss
	check(boss is BossWallEnemy and boss.is_in_group("bosses"), "Lab spawns the in-game wall as a boss")
	check(lab.max_health == 900 and lab.bar.max_value == 900, "HP bar uses the wall scene HP")
	check(lab.phase_label.text.ends_with("진입"), "Phase label starts at entry")
	await create_timer(1.8).timeout
	check(is_equal_approx(boss.global_position.y, 32.0), "Wall settles at the in-game band y=32")
	var phase: StringName = lab.cycle.get("_phase")
	check(phase != &"entry" and lab.phase_label.text.ends_with(lab.PHASE_TITLES[phase]), "Phase label follows the running turret cycle")
	# The ship's real blaster chips the wall body.
	lab.ship.position = Vector2(60,200)
	await create_timer(1.5).timeout
	check(boss.stats_component.health < 900, "Player's actual blaster damages the wall")
	check(lab.bar.value == boss.stats_component.health, "HP bar follows boss HP")
	lab.toggle_pause()
	var paused_time: float = lab.elapsed
	await create_timer(0.3).timeout
	check(paused and is_equal_approx(lab.elapsed, paused_time), "Pause freezes the fight clock")
	lab.toggle_pause()
	boss.stats_component.health = 0
	await process_frame
	await process_frame
	check(lab.defeated and lab.phase_label.text.ends_with("격파") and lab.bar.value == 0, "Defeat shows 격파 with an empty bar")
	var defeat_time: float = lab.elapsed
	await create_timer(0.3).timeout
	check(is_equal_approx(lab.elapsed, defeat_time), "Clock stops after defeat")
	lab.restart()
	await process_frame
	await process_frame
	check(is_instance_valid(lab.boss) and lab.boss != boss and lab.boss.stats_component.health == 900, "Restart spawns a fresh wall")
	check(not lab.defeated and lab.hits == 0 and lab.elapsed < 0.1, "Restart clears defeat, hits and clock")
	lab.return_to_hub()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://lab_hub.tscn", "Back button returns to hub")
	if failures.is_empty():
		print("PASS: wall_boss_lab_smoke_test")
		quit(0)
	else:
		quit(1)
