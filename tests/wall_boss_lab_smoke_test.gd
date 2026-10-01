extends SceneTree
## RECYCLER Lab: intake, crusher bulkheads, cutter array, maw press, link severance and the shutdown reveal.
const Beam = preload("res://labs/bosses/wall/wall_beam.gd")
const Bulkhead = preload("res://labs/bosses/wall/wall_bulkhead.gd")
var failures: Array[String] = []
var lab: Control


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func enemy_bullets() -> Array:
	return get_nodes_in_group("enemy_projectiles").filter(func(node): return lab.world.is_ancestor_of(node))


func quiet(boss: Node2D) -> void:
	# Drop live bullets and let player iframes lapse so contact checks count only the bay.
	for bulkhead in boss.bulkheads: bulkhead.stop_fire()
	for bullet in enemy_bullets(): bullet.queue_free()
	await wait(0.75)


func run() -> void:
	lab = preload("res://labs/bosses/wall/wall_boss_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	await process_frame
	var boss: Node2D = lab.boss
	var left: Node2D = boss.bulkheads[0]
	var right: Node2D = boss.bulkheads[1]
	check(boss.health == 850 and lab.bar.max_value == 850, "Encounter HP sums covers, optics and links")
	check(boss.phase == -1 and lab.phase_label.text.begins_with("INTAKE"), "Fight opens at the intake")
	left.cover.take_damage(50)
	boss.optics[0].take_damage(50)
	boss.links[0].take_damage(50)
	check(boss.health == 850, "No part takes damage during entry")
	await wait(2.9)
	check(boss.phase == 0 and not boss.transitioning, "Entry hands over to 01 / CRUSHER BULKHEADS")
	check(is_equal_approx(boss.ceiling_y, 64.0), "Ceiling armor settles at y=64")
	check(absf(left.inset - 30.0) < 9.0 and absf(right.inset - 30.0) < 9.0 and left.breathing, "Bulkheads settle at rest and start breathing")
	check(lab.hits == 0, "Entry never hits the ship")
	check(is_equal_approx(lab.background.speed_scale, 0.0), "Starfield halts behind the bay")
	check(not left.optic.visible and not boss.optics[0].visible and not boss.links[0].visible and not boss.core.visible, "Defense optics, press links and core stay hidden while the bay looks like plain facility walls")
	check(not left.casing_breached, "Drive machinery stays behind the casing at first")
	boss.lunge_clock = 999.0

	# Covers start closed: out of play like any inactive part, so real shots fly past them to the ceiling.
	check(not left.cover.active and left.cover.hurtbox.is_invincible and not left.cover.hurtbox.blocks_pierce, "Closed covers are out of play")
	var highest := INF
	var watched := 0.0
	while watched < 1.6:
		lab.ship.position = Vector2(left.cover.global_position.x, 200)
		await physics_frame
		watched += 1.0 / 60.0
		for node in lab.world.get_children():
			if node.get_script() == preload("res://projectiles/player_blaster.gd") and absf(node.global_position.x - left.cover.global_position.x) < 9.0:
				highest = minf(highest, node.global_position.y)
	check(left.cover.health == 150 and boss.health == 850, "Closed cover shrugs off real shots")
	check(highest < left.cover.global_position.y - 10.0, "Shots fly past a closed cover up to the ceiling")
	# A lunge opens only the lunging wall's cover, for COVER_OPEN seconds from the landing.
	lab.ship.position = Vector2(170, 250)
	boss.lunge_side = 0
	boss.lunge_clock = 0.0
	await physics_frame
	await physics_frame
	boss.lunge_clock = 999.0
	await wait(1.3)
	check(left.inset > 90.0 and left.cover.active and not right.cover.active, "Lunge opens only the lunging wall's cover")
	lab.ship.position = Vector2(left.face_x() + 12.0, 140)
	await wait(0.6)
	check(left.cover.health < 150 and boss.health < 850, "Player's actual blaster damages the opened cover")
	check(lab.bar.value == boss.health, "HP bar follows the remaining part total")
	lab.ship.position = Vector2(150, 300)
	await wait(1.0)
	check(left.inset > 90.0 and left.cover.active, "Lunged wall holds its reach with the cover open")
	await wait(2.7)
	check(left.inset < 50.0 and left.cover.active, "Cover stays open after the wall is back at rest")
	await wait(1.8)
	check(not left.cover.active and left.cover.hurtbox.is_invincible and left.cover.health > 0, "Cover closes COVER_OPEN seconds after the landing")
	# Ceiling armor absorbs shots that miss every part.
	lab.ship.position = Vector2(150, 300)
	await wait(0.9)
	var before_armor: int = boss.health
	await wait(1.5)
	var leaked: Array = lab.world.get_children().filter(func(node): return node.get_script() == preload("res://projectiles/player_blaster.gd") and node.global_position.y < boss.ceiling_y - 6.0)
	check(boss.health == before_armor and leaked.is_empty(), "Armor stops player shots without taking damage")

	# Contact: breathing and repositioning only shove; a telegraphed lunge pushes and hits once.
	await quiet(boss)
	var hits_before: int = lab.hits
	left.breathing = true
	left.breathe_t = 0.0
	lab.ship.position = Vector2(0, 250)
	await wait(1.5)
	check(absf(lab.ship.position.x - (left.face_x() + 7.0)) < 1.0 and left.inset > 38.0 and lab.hits == hits_before, "Breathing wall shoves the ship without a hit")
	left.breathing = false
	right.breathing = false
	left.move_to(left.inset + 20.0, 0.5)
	await wait(0.7)
	check(absf(lab.ship.position.x - (left.face_x() + 7.0)) < 1.0 and lab.hits == hits_before, "Untelegraphed repositioning shoves without a hit")
	left.move_to(30.0, 0.2)
	await wait(0.6)
	hits_before = lab.hits
	lab.ship.position = Vector2(0, 250)
	await process_frame
	await process_frame
	check(is_equal_approx(lab.ship.position.x, left.face_x() + 7.0), "Still wall clamps the ship to its face")
	check(lab.hits == hits_before, "Resting against a still wall is not a hit")
	# Hugging a still wall, the outer gun's stream grazes the face and flies on instead of dying at the muzzle.
	lab.ship.position = Vector2(left.face_x() + 7.0, 250)
	var flush_top := INF
	var flush_watch := 0.0
	while flush_watch < 1.2:
		await physics_frame
		flush_watch += 1.0 / 60.0
		for node in lab.world.get_children():
			if node.get_script() == preload("res://projectiles/player_blaster.gd") and node.global_position.x < left.face_x() + 4.0:
				flush_top = minf(flush_top, node.global_position.y)
	check(flush_top < 150.0, "Wall-side stream grazes a still wall instead of dying at the muzzle")
	# Keep the cover shut here so the pinned ship cannot chew through it.
	left.cover_window = false
	left.lunge(96.0, 0.3, 0.4)
	await wait(0.7)
	check(left.inset > 90.0, "Lunge slams the bulkhead inward")
	check(lab.ship.position.x >= left.face_x() + 7.0 - 0.01, "Lunging bulkhead pushes the ship inward")
	check(lab.hits == hits_before + 1, "Being shoved by a lunging bulkhead is exactly one hit")
	await wait(1.8)
	left.cover_window = true

	# Covers: bolts, breach, overkill, out-of-section parts.
	right.open_cover()
	right.cover.take_damage(105)
	check(right.cover.damage_stage == 2 and not get_nodes_in_group("wall_debris").is_empty(), "Worn cover sheds two bolts with sparks and chips")
	right.seal_cover()
	left.open_cover()
	var cover_hp: int = left.cover.health
	var total: int = boss.health
	var drive_before: float = left.drive_phase
	left.cover.take_damage(9999)
	left.cover.take_damage(9999)
	check(boss.health == total - cover_hp, "Overkill and repeat kills only remove the cover's remaining HP")
	check(left.casing_breached and not left.cover.visible and not left.fire_enabled, "Breached cover tears the casing off and silences its vents")
	check(is_equal_approx(left.armor_shape.position.x, left.side * (Bulkhead.WIDTH * 0.5 + Bulkhead.BAY_FACE + Bulkhead.SHOT_GRAZE)), "Breached wall stops shots at its exposed drive bay face")
	check(lab.phase_label.text.ends_with("DRIVE EXPOSED"), "First breach announces the exposed drive")
	check(not get_nodes_in_group("wall_debris").is_empty(), "Breach sheds casing plates and sparks")
	await wait(0.3)
	check(absf(left.drive_phase - drive_before) > 15.0, "Exposed drive turns as the wall recoils")
	boss.optics[0].take_damage(50)
	boss.links[0].take_damage(50)
	check(boss.health == total - cover_hp, "Later-section parts ignore damage")
	right.open_cover()
	right.cover.take_damage(9999)
	await process_frame
	await process_frame
	check(boss.transitioning and lab.phase_label.text.begins_with("CASING BREACH"), "Both covers down wakes the internal defenses")
	await wait(2.0)
	check(boss.phase == 1 and not boss.transitioning, "Section 02 starts")
	check(boss.optics[0].visible and left.optic.visible and boss.optics[0].active and left.optic.active, "Optics drop from the ceiling and unfold from the exposed drive bays")

	# Ceiling optics track, freeze, then fire a V of real beams that never move; wall carriages step down.
	# Park the ship outside every optic cone so the beams do not converge on it when they lock.
	lab.ship.position = Vector2(263, 90)
	boss.band_clock = [99.0, 99.0]
	await quiet(boss)
	boss.optic_cycle = boss.OpticCycle.REST
	boss.optic_clock = 0.0
	await physics_frame
	await physics_frame
	check(boss.optic_beams[0].state == Beam.State.WARN and boss.optic_beams[0].shape.disabled, "Optic warning shows a guide with no hitbox")
	# Inside the lock window the guide stops tracking, so the shot can be read and stepped out of.
	boss.optic_clock = boss.AIM_LOCK - 0.05
	var frozen_aim: float = boss.optics[0].aim_angle
	lab.ship.position = Vector2(40, 300)
	await physics_frame
	await physics_frame
	await physics_frame
	check(is_equal_approx(boss.optics[0].aim_angle, frozen_aim), "Aim freezes in the last moments before the shot")
	boss.optic_clock = 0.0
	await physics_frame
	await physics_frame
	check(boss.optic_beams[0].is_blocking() and not boss.optic_beams[0].shape.disabled, "Locked beam enables its hitbox")
	check(absf(boss.optics[0].aim_angle) <= deg_to_rad(55.01), "Optic aim stays within its cone")
	var fired_rotation: float = boss.optic_beams[0].rotation
	lab.ship.position = Vector2(263, 300)
	await wait(0.4)
	check(boss.optic_beams[0].is_blocking() and is_equal_approx(boss.optic_beams[0].rotation, fired_rotation), "A firing V beam holds its line while the ship moves")
	for bullet in enemy_bullets(): bullet.queue_free()
	hits_before = lab.hits
	var beam_point: Vector2 = boss.optic_beams[0].global_position + Vector2.DOWN.rotated(boss.optic_beams[0].rotation) * 120.0
	lab.ship.position = beam_point
	await wait(0.2)
	check(lab.hits > hits_before, "Touching a live beam hits the ship")
	lab.ship.position = Vector2(150, 300)
	await wait(0.9)
	var optic_total: int = boss.health
	boss.optics[0].take_damage(9999)
	check(boss.health == optic_total - 70, "Optic carries 70 HP")
	check(boss.optic_beams[0].state == Beam.State.OFF, "Destroyed optic kills its beam for good")
	# Wall carriage: stop, warn, fire a still bar, then travel to the next stop with the bar off.
	boss.band_clock[0] = 0.0
	boss.band_state[0] = boss.Scan.REST
	lab.ship.position = Vector2(150, 330)
	await wait(0.35)
	check(left.beam.state == Beam.State.WARN and is_equal_approx(left.optic.position.y, boss.SCAN_STOPS[0]), "Wall carriage reaches its first stop, then warns its bar")
	check(absf(left.optic.position.x) > 11.9, "Wall carriage stands clear of the face")
	await wait(0.5)
	check(left.beam.is_blocking(), "Scan bar fires after its warning")
	var bar_position: Vector2 = left.beam.global_position
	var bar_length: float = left.beam.length
	await wait(0.4)
	check(left.beam.is_blocking() and left.beam.global_position.is_equal_approx(bar_position) and is_equal_approx(left.beam.length, bar_length), "A firing scan bar holds still")
	await wait(0.25)
	check(left.beam.state == Beam.State.OFF and left.optic.position.y > boss.SCAN_STOPS[0] + 1.0 and left.optic.position.y < boss.SCAN_STOPS[1], "Carriage travels to its next stop only with the bar off")
	for optic in boss.optics: optic.take_damage(9999)
	for bulkhead in boss.bulkheads: bulkhead.optic.take_damage(9999)
	await process_frame
	await process_frame
	check(boss.transitioning and lab.phase_label.text == "SYSTEM FAULT", "All optics down faults the control system")
	await wait(1.0)
	check(boss.glimpse > 0.2 and boss.armor_split > 0.5, "Fault splits the ceiling armor and glimpses the core's scanner")
	await wait(2.8)
	check(boss.phase == 2 and not boss.transitioning, "Section 03 starts")
	check(is_equal_approx(boss.upper_y, 96.0) and is_equal_approx(boss.lower_y, 340.0) and boss.ceiling_y < 30.0, "Maw press engages top and bottom while the split armor lifts clear")
	check(boss.links[0].visible and boss.links[0].active, "Control links hang under the upper press")

	# Maw press: a closing platen pushes and hits; the command loop is parked so the checks own the press.
	boss.contraction_run += 1
	if boss.motion != null and boss.motion.is_valid(): boss.motion.kill()
	await quiet(boss)
	boss.spit_barrage.stop()
	hits_before = lab.hits
	lab.ship.position = Vector2(150, boss.upper_y + 10.0)
	var close: Tween = boss._press_tween()
	close.tween_property(boss, "upper_y", 150.0, 0.6)
	await wait(0.7)
	check(lab.ship.position.y >= boss.upper_y + 10.0 - 0.01, "Descending press keeps the ship below it")
	check(lab.hits > hits_before, "Descending press pushing the ship is a hit")
	await quiet(boss)
	hits_before = lab.hits
	lab.ship.position = Vector2(150, boss.lower_y - 10.0)
	var rise: Tween = boss._press_tween()
	rise.tween_property(boss, "lower_y", 260.0, 0.6)
	await wait(0.7)
	check(lab.ship.position.y <= boss.lower_y - 10.0 + 0.01, "Rising press keeps the ship above it")
	check(lab.hits > hits_before, "Rising press pushing the ship is a hit")
	var link_total: int = boss.health
	var link_hp: int = boss.links[0].health
	var cut_before: int = boss.links_cut
	boss.links[0].take_damage(9999)
	check(link_hp == 90 and boss.health == link_total - 90 and boss.links_cut == cut_before + 1, "Cut link removes 90 HP and is counted")

	lab.toggle_pause()
	var frozen_upper: float = boss.upper_y
	var frozen_age: float = boss.age
	await create_timer(0.3, true).timeout
	check(paused and boss.upper_y == frozen_upper and boss.age == frozen_age, "Pause freezes the press and its clocks")
	lab.toggle_pause()

	# Last link cut ends the fight: freeze, lights die, hydraulics let go, the core hangs exposed, then burns out.
	lab.ship.position = Vector2(150, 200)
	for link in boss.links: link.take_damage(9999)
	await process_frame
	await process_frame
	check(boss.defeated and boss.health == 0 and lab.bar.value == 0, "Last link cut ends the fight with an empty bar")
	check(lab.phase_label.text == "LINK SEVERED", "Link severance title shows")
	check(enemy_bullets().all(func(bullet): return bullet.is_queued_for_deletion()), "Link severance clears live bullets")
	var clock: float = lab.elapsed
	await wait(1.5)
	check(is_equal_approx(lab.elapsed, clock), "Fight clock stops at the last link")
	check(boss.power < 0.05 and lab.phase_label.text == "POWER DOWN", "Bay lights die, then the hydraulics let go")
	await wait(2.0)
	check(is_equal_approx(left.inset, Bulkhead.PARKED) and is_equal_approx(boss.upper_y, 26.0) and boss.ceiling_y < 20.0, "Machinery retracts and the bulkheads park off screen")
	check(boss.core.visible and lab.phase_label.text == "CORE EXPOSED" and boss.link_alpha > 0.5, "The control core hangs exposed with its command links to the dead machinery")
	check(not boss.core.active, "The exposed core never fights")
	await wait(0.9)
	check(lab.phase_label.text == "CORE / OVERLOAD" and not boss.core.visible, "Core overloads and blows")
	check(not get_nodes_in_group("carrier_destruction_effects").is_empty(), "Overload spawns the shared explosions")
	await wait(1.6)
	check(boss.upper_y < 10.0 and lab.background.speed_scale > 1.5, "Dead machinery falls away and the starfield surges through")
	await wait(2.0)
	check(boss.destruction_complete and lab.phase_label.text == "RECYCLER / SHUTDOWN", "Shutdown completes as RECYCLER / SHUTDOWN")
	check(get_nodes_in_group("carrier_destruction_effects").is_empty() and get_nodes_in_group("wall_debris").is_empty(), "Explosions, wreckage and sparks clean themselves up")
	check(absf(lab.background.speed_scale - 1.0) < 0.05, "Starfield returns to cruise speed")

	# Restart during the shutdown leaves nothing behind.
	lab.restart()
	await process_frame
	await process_frame
	boss = lab.boss
	await wait(2.9)
	for bulkhead in boss.bulkheads:
		bulkhead.open_cover()
		bulkhead.cover.take_damage(9999)
	await wait(2.0)
	for optic in boss.optics: optic.take_damage(9999)
	for bulkhead in boss.bulkheads: bulkhead.optic.take_damage(9999)
	await wait(3.8)
	for link in boss.links: link.take_damage(9999)
	await wait(4.4)
	check(boss.defeated and not get_nodes_in_group("carrier_destruction_effects").is_empty(), "Shutdown is mid-overload before restart")
	lab.restart()
	await process_frame
	await process_frame
	await process_frame
	check(get_nodes_in_group("carrier_destruction_effects").is_empty() and get_nodes_in_group("wall_debris").is_empty(), "Restart during the shutdown clears its effects")
	check(lab.boss != boss and lab.boss.health == 850 and lab.hits == 0 and lab.elapsed < 0.1, "Restart spawns a fresh bay and clears stats")

	lab.return_to_hub()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://lab_hub.tscn", "Back button returns to hub")
	if failures.is_empty():
		print("PASS: wall_boss_lab_smoke_test")
		quit(0)
	else:
		for failure in failures: print("FAIL: ", failure)
		quit(1)
