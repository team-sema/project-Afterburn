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
	var hit_radius: float = ship.get_node("PlayerHitPoint/HurtboxComponent/CollisionShape2D").shape.radius
	check(clamp.margin == int(hit_radius) + 1, "clamp clearance is the hit point radius plus 1px")
	ship.position = Vector2(-100, 120)
	clamp._process(0.0)
	check(ship.position.x == float(clamp.margin), "hit point reaches the lane edge; hull may overlap the frame")
	var bleed: float = Bounds.FIELD_BLEED
	check(world.playfield_viewport.size == Vector2i(340 + int(bleed) * 2, 360) and ship.get_viewport_rect().size == Vector2(340, 360), "viewport renders bleed while the lane stays 340x360")
	check(world.playfield_viewport.global_canvas_transform.origin == Vector2(bleed, 0), "lane origin is shifted by the bleed")
	var background = world.gameplay.get_node("SpaceBackground")
	check(background.bleed == bleed and background.space.position.x == -bleed and background.space.size.x == 340 + bleed * 2, "star field covers the bleed")
	check(background.get_orbital_ring().position.x == -bleed and background.get_orbital_ring().size.x == 340 + bleed * 2, "orbital ring covers the bleed")
	var image := load("res://assets/ui/cockpit/pilot_visor_frame.png").get_image() as Image
	check(image.get_pixel(image.get_width()/2, image.get_height()/2).a < 0.01, "battle aperture is transparent")
	check(image.get_pixel(int(image.get_width()*0.1), int(image.get_height()*0.4)).a > 0.98, "side console is opaque UI")
	for y in [8.0, 25.0, 100.0, 226.0, 260.0, 300.0, 330.0, 352.0]:
		for x in [-100.0, 440.0]:
			ship.position = Vector2(x, y)
			clamp._process(0.0)
			check(ship.position.y == y, "side clamp preserves vertical travel")
			for offset in [Vector2(-hit_radius, 0), Vector2(hit_radius, 0), Vector2(0, -hit_radius), Vector2(0, hit_radius)]:
				var shell_point: Vector2 = ship.position + offset + Vector2(150, 0)
				var pixel: Vector2i = Vector2i(shell_point / Vector2(640, 360) * Vector2(image.get_size()))
				pixel = pixel.clamp(Vector2i.ZERO, image.get_size()-Vector2i.ONE)
				check(image.get_pixelv(pixel).a < 0.5, "hit point stays inside artwork at %s" % shell_point)
	check(world.status_ship_panel.slot_rack.get_visible_slot_count() == 5, "new run starts with five facilities, not expanded capacity")
	_check_instrument_fit(world)
	ship.position = Vector2(170, 216)
	launch.play()
	launch.set_process(false)
	check(cockpit.deployment_time == 0.0, "launch resets all panels before first frame")
	check(not clamp.enabled, "entry animation bypasses movement clamp")
	check(world.get_field_bleed() == Bounds.FIELD_LEFT, "launch renders the full shell width behind the deploying panels")
	for panel in cockpit.panels: check(panel.position.length() > 300, "panels start outside screen")
	launch.advance(0.65)
	check(cockpit.panels[0].position != cockpit.panels[2].position, "canopy and wing deploy separately")
	for item in cockpit.instruments:
		check(item.node.position.is_equal_approx(item.home + cockpit.panels[int(item.panel)].position), "instrument follows its own panel during deployment")
	var before: float = launch.elapsed
	world._set_manual_pause(true)
	launch.set_process(true)
	for i in 4: await process_frame
	check(launch.elapsed == before and cockpit.deployment_time == before, "pause freezes flight and deployment together")
	check(world.playfield_viewport.size.x == 640 and world.playfield_viewport.global_canvas_transform.origin.x == Bounds.FIELD_LEFT and background.bleed == Bounds.FIELD_LEFT, "full-width playfield while panels are still out")
	world._set_manual_pause(false)
	launch.set_process(false)
	launch.advance(1.16)
	check(clamp.enabled, "movement unlocks after panels settle")
	for panel in cockpit.panels: check(panel.position.is_zero_approx(), "all panels settled before control unlock")
	for item in cockpit.instruments: check(is_equal_approx(item.node.modulate.a, 1.0), "live instrument powered on")
	launch.advance(1.0)
	check(not launch.is_launching, "launch completes without extending original duration")
	await process_frame
	check(world.get_field_bleed() == bleed and world.playfield_viewport.size.x == 340 + int(bleed) * 2 and background.bleed == bleed, "bleed shrinks back once every panel has settled")
	var registry = world.gameplay.get_node("PlayerAugmentRegistry")
	for i in 10: registry.expand_slots()
	ship.get_node("PlayerWeaponLoadout").add_weapon_bays(1)
	for i in 4: await process_frame
	check(world.status_ship_panel.slot_rack._slots.size() == 15, "all fifteen facility slots retained")
	var hud = world.weapon_loadout_hud
	check(hud.bay_row.get_child_count() == 4, "four weapon bays retained")
	for bay in hud.bay_row.get_children():
		check(bay.size.is_equal_approx(Vector2(26,26)), "occupied and empty bays have equal compact size")
		check(hud.bay_row.get_global_rect().encloses(bay.get_global_rect()), "bay stays in its reserved screen")
	_check_instrument_fit(world)
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


func _check_instrument_fit(world: Control) -> void:
	var rack: UniversalModuleSlotRack = world.status_ship_panel.slot_rack
	for i in rack.get_visible_slot_count():
		var cell := rack.get_slot_rect(i)
		check(Rect2(Vector2.ZERO, rack.size).encloses(cell), "every facility cell fits its reserved display")
		check(rack._slot_at_position(cell.get_center()) == i, "each visible facility remains independently hoverable")
	var hud: WeaponLoadoutHud = world.weapon_loadout_hud
	var console := Rect2(514, 80, 112, 111)
	for bay: Control in hud.bay_row.get_children():
		for point in _hex_points(bay.get_node("%Core")):
			check(console.has_point(point), "weapon hex stays above lower metal seam")
	var left := world.get_node("Layout/LeftPanel/Margin/VBox")
	var shield := left.get_node("ShipStatusHud") as Control
	var xp := left.get_node("ProgressionHud/ExperienceLabel") as Label
	var bar := left.get_node("ProgressionHud/ExperienceBar") as Control
	check(shield.rotation > 0.1 and is_equal_approx(shield.rotation, xp.rotation) and is_equal_approx(xp.rotation, bar.rotation), "shield and XP share the console tilt")
	var xp_local: Vector2 = shield.get_global_transform().affine_inverse() * xp.global_position
	var arc := shield.get_node("ShieldArc") as Control
	var charge := shield.get_node("ShieldChargeBar") as Control
	check(xp_local.y > arc.position.y + arc.size.y and xp_local.y > charge.position.y + charge.size.y, "XP has clearance below the shield arc and charging bar")
	var selected := hud.get_node("%SelectedWeaponHex") as Control
	var up_axis := hud.modules_grid.get_global_transform().y.normalized()
	var modules_bottom := -INF
	for module: HexModuleFrame in hud.modules_grid.get_children():
		for point in _hex_points(module):
			modules_bottom = maxf(modules_bottom, up_axis.dot(point))
	var title_top := up_axis.dot(hud.detail_footer.global_position)
	var title_bottom := title_top + hud.detail_footer.size.y
	var selected_top := INF
	for point in _hex_points(selected):
		selected_top = minf(selected_top, up_axis.dot(point))
	check(title_top > modules_bottom and selected_top > title_bottom, "module row, weapon title and selected icon have distinct vertical space")
	var safe_left := PackedVector2Array([Vector2(37,239), Vector2(121,260), Vector2(162,330), Vector2(134,339), Vector2(12,307)])
	for control: Control in [shield.get_node("ShieldLabel"), shield.get_node("ShieldArc"), xp, bar]:
		_check_corners(control, safe_left)
	var safe_right := PackedVector2Array([Vector2(526,252), Vector2(610,232), Vector2(632,316), Vector2(610,328), Vector2(483,338)])
	_check_corners(hud.detail_footer, safe_right)
	for hex: HexModuleFrame in [selected] + hud.modules_grid.get_children():
		for point in _hex_points(hex):
			check(Geometry2D.is_point_in_polygon(point, safe_right), "enlarged hex stays within the instrument glass at %s" % point)
	var progress = left.get_node("ProgressionHud")
	progress._on_experience_changed(999, 5, 1)
	var font := xp.label_settings.font
	check(font.get_string_size(xp.text, HORIZONTAL_ALIGNMENT_LEFT, -1, xp.label_settings.font_size).x <= xp.size.x, "full augment-ready prompt fits without clipping")
	progress._on_experience_changed(0, 5, 1)

func _check_corners(control: Control, polygon: PackedVector2Array) -> void:
	for corner in [Vector2.ZERO, Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		var point: Vector2 = control.get_global_transform() * corner
		check(Geometry2D.is_point_in_polygon(point, polygon), "%s stays inside the slanted instrument glass at %s" % [control.name, point])


func _hex_points(hex: HexModuleFrame) -> PackedVector2Array:
	return hex.get_global_transform() * hex.get_hex_polygon()
