extends SceneTree

## Space backdrop (docs/design/effects.md 「World」): the default BackdropTheme builds a
## nebula and optional silhouettes below the stars, plus a non-repeating orbital
## landmark. Theme changes, resize, pause and launch speed must preserve the contract.

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var background := (load("res://effects/space_background.tscn") as PackedScene).instantiate() as SpaceBackground
	root.add_child(background)
	await process_frame

	var theme := background.backdrop
	_expect(theme != null, "default scene carries a BackdropTheme")
	if theme == null:
		_finish()
		return
	_expect(theme.nebula_count() == 4 and theme.rock_count() == 0, "default theme keeps nebulae without foreground rocks")

	var nebula := background.get_nebula_layer()
	var rocks := background.get_rock_layer()
	_expect(nebula != null and rocks != null, "theme builds nebula and rock layers")
	if nebula == null or rocks == null:
		_finish()
		return
	_expect(nebula.get_node_or_null("BaseTint") is ColorRect, "nebula layer starts with the base tint")
	_expect(nebula.get_child_count() == 1 + theme.nebula_count(), "one disc per nebula entry")
	_expect(rocks.get_child_count() == 0, "default theme leaves the old silhouettes empty")
	var ring := background.get_orbital_ring()
	_expect(ring != null, "default theme creates the orbital landmark")
	if ring == null:
		_finish()
		return
	_expect(ring.get_index() > background.far_stars_layer.get_index(), "structure occludes distant stars")
	_expect(ring.get_index() > background.close_stars_layer.get_index(), "solid structure occludes both star layers")
	_expect(ring.mouse_filter == Control.MOUSE_FILTER_IGNORE, "background never intercepts menu input")
	var ring_material := ring.material as ShaderMaterial
	_expect(ring_material != null, "ring has its own shader material")

	var space_index := background.space_layer.get_index()
	_expect(nebula.get_index() == space_index + 1, "nebula sits right above the space layer")
	_expect(rocks.get_index() == space_index + 2, "rocks sit above the nebula")
	_expect(rocks.get_index() < background.far_stars_layer.get_index(), "rocks stay below the far stars")

	var viewport_size: Vector2 = background.get_viewport().get_visible_rect().size
	_expect(is_equal_approx(nebula.motion_mirroring.y, viewport_size.y), "nebula tiles with the viewport height")
	var base := nebula.get_node("BaseTint") as ColorRect
	_expect(base.size.is_equal_approx(viewport_size), "base tint covers the viewport")
	_expect(ring.size.is_equal_approx(viewport_size), "landmark covers the viewport without tiling")
	_expect((ring_material.get_shader_parameter("viewport_size") as Vector2).is_equal_approx(viewport_size), "shader receives viewport aspect")

	_expect(is_equal_approx(background.get_layer_speed(2), 160.0), "close star speed is unchanged")
	var nebula_before := nebula.motion_offset.y
	var rocks_before := rocks.motion_offset.y
	await process_frame
	await process_frame
	_expect(nebula.motion_offset.y > nebula_before, "nebula scrolls")
	_expect(rocks.motion_offset.y > rocks_before, "rocks scroll")
	_expect(
		rocks.motion_offset.y - rocks_before > nebula.motion_offset.y - nebula_before,
		"rocks scroll faster than the nebula",
	)

	background.speed_scale = 0.0
	nebula_before = nebula.motion_offset.y
	var ring_time: float = ring_material.get_shader_parameter("elapsed")
	await process_frame
	_expect(is_equal_approx(nebula.motion_offset.y, nebula_before), "speed_scale 0 stops the nebula")
	_expect(is_equal_approx(ring_material.get_shader_parameter("elapsed"), ring_time), "speed_scale 0 freezes orbital motion")
	background.speed_scale = 1.0
	paused = true
	await process_frame
	await process_frame
	_expect(is_equal_approx(ring_material.get_shader_parameter("elapsed"), ring_time), "pause freezes ring motion and heat")
	paused = false
	background.set_process(false)
	background.speed_scale = 3.0
	background._process(0.5)
	_expect(is_equal_approx(ring_material.get_shader_parameter("elapsed"), ring_time + 1.5), "launch speed drives the ring clock")
	ring_time = ring_material.get_shader_parameter("elapsed")
	background._resize_to_viewport()
	ring = background.get_orbital_ring()
	ring_material = ring.material as ShaderMaterial
	_expect(ring.size.is_equal_approx(viewport_size), "resize rebuilds a viewport-sized landmark")
	_expect(is_equal_approx(ring_material.get_shader_parameter("elapsed"), ring_time), "resize preserves orbital animation phase")

	var legacy_theme := BackdropTheme.new()
	legacy_theme.rock_positions = PackedVector2Array([Vector2(0.1, 0.2), Vector2(0.9, 0.7)])
	legacy_theme.rock_sizes = PackedFloat32Array([20.0, 30.0])
	background.backdrop = legacy_theme
	_expect(background.get_orbital_ring() == null, "legacy theme removes the orbital landmark")
	_expect(background.get_rock_layer().get_child_count() == 3, "legacy theme still builds rocks and a planet")
	_expect(background.get_rock_layer().get_node_or_null("Planet/Ring") is Line2D, "legacy planet keeps its ring")
	background.backdrop = theme
	_expect(background.get_orbital_ring() != null, "switching back restores the landmark")

	background.backdrop = null
	await process_frame
	_expect(background.get_nebula_layer() == null and background.get_rock_layer() == null, "clearing the theme removes both layers")
	_expect(background.get_node_or_null("NebulaLayer") == null, "no stale nebula node remains")
	_expect(background.get_orbital_ring() == null and background.get_node_or_null("OrbitalRing") == null, "clearing theme removes the orbital landmark")

	var resized_viewport := SubViewport.new()
	resized_viewport.size = Vector2i(300, 360)
	root.add_child(resized_viewport)
	var resized_background := (load("res://effects/space_background.tscn") as PackedScene).instantiate() as SpaceBackground
	resized_viewport.add_child(resized_background)
	await process_frame
	resized_viewport.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	var resized_ring := resized_background.get_orbital_ring()
	_expect(resized_ring.size.is_equal_approx(Vector2(640, 360)), "viewport resize rebuilds the landmark at menu dimensions")
	_expect((resized_ring.material as ShaderMaterial).get_shader_parameter("viewport_size") == Vector2(640, 360), "viewport resize updates shader aspect")
	_expect(resized_background.find_children("OrbitalRing", "ColorRect", false, false).size() == 1, "resize leaves exactly one landmark")
	resized_viewport.queue_free()

	background.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("space backdrop smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)
