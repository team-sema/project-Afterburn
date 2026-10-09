extends SceneTree
const Bounds := preload("res://menus/cockpit_geometry.gd")
var failures := PackedStringArray()
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func run() -> void:
	GameSettings.instance.save_enabled = false
	var world := load("res://world.tscn").instantiate() as Control
	root.add_child(world)
	for i in 5: await process_frame
	var cockpit = world.get_node("Layout/CockpitHud")
	var launch = world.gameplay.get_node("LaunchSequence")
	var ship = world.gameplay.get_node("Ship")
	var clamp = ship.get_node("PositionClampComponent")
	check(cockpit.panels.size() == 6, "six independently deployed panels")
	check(cockpit.deployment_time == 2.6, "idle scene shows complete HUD")
	check(clamp.cockpit_boundary, "main game enables cockpit boundary")
	var image := load("res://assets/ui/cockpit/pilot_visor_frame.png").get_image() as Image
	check(image.get_pixel(image.get_width()/2, image.get_height()/2).a < 0.01, "battle aperture is transparent")
	check(image.get_pixel(int(image.get_width()*0.1), int(image.get_height()*0.4)).a > 0.98, "side console is opaque UI")
	for y in [8.0, 25.0, 100.0, 226.0, 260.0, 300.0, 330.0, 352.0]:
		for x in [-100.0, 440.0]:
			ship.position = Vector2(x, y)
			clamp._process(0.0)
			check(ship.position.y == y, "side clamp preserves vertical travel")
			for offset in [Vector2(-8, 0), Vector2(8, 0), Vector2(0, -8), Vector2(0, 8)]:
				var shell_point: Vector2 = ship.position + offset + Vector2(150, 0)
				var pixel: Vector2i = Vector2i(shell_point / Vector2(640, 360) * Vector2(image.get_size()))
				pixel = pixel.clamp(Vector2i.ZERO, image.get_size()-Vector2i.ONE)
				check(image.get_pixelv(pixel).a < 0.5, "ship clearance stays inside artwork at %s" % shell_point)
	ship.position = Vector2(170, 216)
	launch.play()
	launch.set_process(false)
	check(cockpit.deployment_time == 0.0, "launch resets all panels before first frame")
	check(not clamp.enabled, "entry animation bypasses movement clamp")
	for panel in cockpit.panels: check(panel.position.length() > 300, "panels start outside screen")
	launch.advance(0.65)
	check(cockpit.panels[0].position != cockpit.panels[2].position, "canopy and wing deploy separately")
	var before: float = launch.elapsed
	world._set_manual_pause(true)
	launch.set_process(true)
	for i in 4: await process_frame
	check(launch.elapsed == before and cockpit.deployment_time == before, "pause freezes flight and deployment together")
	world._set_manual_pause(false)
	launch.set_process(false)
	launch.advance(1.16)
	check(clamp.enabled, "movement unlocks after panels settle")
	for panel in cockpit.panels: check(panel.position.is_zero_approx(), "all panels settled before control unlock")
	for item in cockpit.instruments: check(is_equal_approx(item.node.modulate.a, 1.0), "live instrument powered on")
	launch.advance(1.0)
	check(not launch.is_launching, "launch completes without extending original duration")
	var registry = world.gameplay.get_node("PlayerAugmentRegistry")
	for i in 10: registry.expand_slots()
	ship.get_node("PlayerWeaponLoadout").add_weapon_bays(1)
	for i in 4: await process_frame
	check(world.status_ship_panel.slot_rack._slots.size() == 15, "all fifteen facility slots retained")
	var hud = world.weapon_loadout_hud
	check(hud.bay_row.get_child_count() == 4, "four weapon bays retained")
	for bay in hud.bay_row.get_children():
		check(bay.size.is_equal_approx(Vector2(32,32)), "occupied and empty bays have equal compact size")
		check(hud.bay_row.get_global_rect().encloses(bay.get_global_rect()), "bay stays in its reserved screen")
	check(Rect2(Vector2.ZERO, Vector2(640,360)).encloses(hud.detail_footer.get_global_rect()), "weapon explanation stays on screen")
	world.queue_free()
	await process_frame
	var next := load("res://world.tscn").instantiate() as Control
	root.add_child(next)
	for i in 2: await process_frame
	next.gameplay.get_node("LaunchSequence").play()
	check(next.get_node("Layout/CockpitHud").deployment_time == 0.0, "new run deploys again")
	next.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS cockpit_hud_test")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: ", failure)
		quit(1)
