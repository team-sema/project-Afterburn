extends SceneTree
var failures := PackedStringArray()

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func settle() -> void:
	# Let the OS deliver resize events even when readback stalls rendering.
	await create_timer(0.15).timeout
	for frame in 5:
		await process_frame

func run() -> void:
	GameSettings.instance.save_enabled = false
	# Custom SceneTree scripts must explicitly mirror the application HDR setting.
	root.use_hdr_2d = ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)
	var original_scale_size := root.content_scale_size
	# Reproduce a 1280x720 project viewport, not just a physical window resize.
	root.content_scale_size = Vector2i(1280, 720)
	var original_aspect := root.content_scale_aspect
	var original_size := root.size
	var world := load("res://world.tscn").instantiate() as Control
	root.add_child(world)
	await settle()
	check(root.content_scale_size == Vector2i(640, 360), "World normalizes the configured viewport to cockpit coordinates")
	var fill := world.get_node("WindowSideFill")
	var layout := world.get_node("Layout") as Control
	var overlay := world.get_node("AugmentSelectionOverlay") as AugmentSelectionOverlay
	var field := world.get_node("Layout/Playfield") as Control
	var left := world.get_node("Layout/LeftPanel") as Control
	var right := world.get_node("Layout/RightPanel") as Control
	var background := world.gameplay.get_node("SpaceBackground") as SpaceBackground
	var field_home := field.position
	var right_home := right.position
	for dimensions in [Vector2i(1280, 720), Vector2i(1906, 992), Vector2i(1680, 720), Vector2i(1920, 540), Vector2i(960, 720), Vector2i(1280, 720)]:
		root.size = dimensions
		await settle()
		var margin := maxf(0.0, (world.size.x - 640.0) * 0.5)
		check(is_equal_approx(layout.position.x, margin), "cockpit centered at %s" % dimensions)
		check(layout.size == Vector2(640, 360), "fixed cockpit size at %s" % dimensions)
		check(field.position == field_home and right.position == right_home, "HUD and field relative positions preserved")
		check(world.gameplay.get_node("Ship").get_viewport_rect().size == Vector2(340, 360), "gameplay viewport remains fixed")
		check(fill.visible == (dimensions.x * 9 > dimensions.y * 16), "fill visibility matches aspect at %s" % dimensions)
		check(is_equal_approx(overlay.stage.position.x, left.get_global_rect().position.x), "offer starts at cockpit edge")
		check(is_equal_approx(overlay.stage.size.x, 490.0), "offer width remains 490")
		check(is_equal_approx(overlay.stage.get_global_rect().end.x, right.get_global_rect().position.x), "offer leaves status visible")
		check(overlay.stage.size == Vector2(490, 360), "offer keeps original logical size")
		check(overlay.stage.position.y == layout.position.y, "offer follows cockpit vertical centering")
		check(fill.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decoration ignores input")
		for rect in fill.sides:
			check(rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "side ignores input")
			check(is_equal_approx(rect.size.x, (world.size.x - 640.0) * 0.5) and is_equal_approx(rect.size.y, 360), "side fills margin")
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.godot/side-fill-captures")
			var capture := capture_srgb()
			capture.save_png("res://.godot/side-fill-captures/%dx%d.png" % [dimensions.x, dimensions.y])
			if dimensions == Vector2i(1906, 992):
				var side_width := int((dimensions.x - dimensions.y * 640.0 / 360.0) * 0.5)
				for side in 2:
					var total := 0.0
					var count := 0
					for y in range(0, dimensions.y, 4):
						for x in range(2, side_width - 2, 2):
							var pixel := capture.get_pixel(x if side == 0 else dimensions.x - 1 - x, y)
							total += pixel.get_luminance()
							count += 1
					var average := total / count
					print("1906x992 side %d mean sRGB luminance: %.4f" % [side, average])
					check(average <= 0.035, "HDR side fill stays dark")
	root.size = Vector2i(1680, 720)
	await settle()
	background.speed_scale = 7.0
	fill.set_process(false)
	var before: float = fill.elapsed
	fill._process(0.5)
	check(is_equal_approx(fill.elapsed - before, 3.5), "side stars follow launch acceleration")
	fill.set_process(true)
	world._set_manual_pause(true)
	before = fill.elapsed
	await settle()
	check(fill.elapsed == before, "pause freezes side stars")
	root.size = Vector2i(1920, 540)
	await settle()
	check(is_equal_approx(layout.position.x, 320.0), "resize updates while paused")
	check(fill.elapsed == before, "resize does not resume stars")
	world._set_manual_pause(false)
	await settle()
	check(fill.elapsed > before, "resume restarts stars")
	paused = true
	var card := load("res://resources/player_augments/weapon/trait_barrier_fast_orbit.tres")
	await overlay.open_choices("시설 선택", [card, card, card], Color.CYAN)
	check(overlay.choice_buttons[0].has_focus(), "offer focuses first card in wide window")
	root.size = Vector2i(1680, 720)
	await settle()
	check(is_equal_approx(overlay.stage.size.x, 490.0), "open offer preserves its width on resize")
	for button in overlay.choice_buttons:
		check(overlay.stage.get_global_rect().encloses(button.get_global_rect()), "card remains inside shifted offer stage")
	var motion := InputEventMouseMotion.new()
	motion.position = overlay.choice_buttons[1].get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await settle()
	check(overlay.choice_buttons[1].has_focus(), "mouse targets shifted card correctly")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/side-fill-captures/offer-21x9.png")
	overlay.hide_choices()
	paused = false
	world.queue_free()
	await settle()
	check(root.content_scale_aspect == original_aspect, "leaving World restores menu aspect policy")
	check(root.content_scale_size == Vector2i(1280, 720), "leaving World restores configured viewport size")
	root.content_scale_size = original_scale_size
	root.size = original_size
	if failures.is_empty():
		print("PASS window_side_fill_test")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

# HDR viewport readback is linear; PNG previews must be encoded as sRGB.
func capture_srgb() -> Image:
	var raw := root.get_texture().get_image()
	if not root.use_hdr_2d:
		return raw
	var encoded := Image.create(raw.get_width(), raw.get_height(), false, Image.FORMAT_RGB8)
	for y in raw.get_height():
		for x in raw.get_width():
			encoded.set_pixel(x, y, raw.get_pixel(x, y).linear_to_srgb())
	return encoded
