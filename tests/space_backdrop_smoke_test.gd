extends SceneTree

## Space backdrop (docs/design/effects.md 「World」): the default BackdropTheme builds a
## nebula layer (base tint + colour discs) and a rock layer (silhouettes + ringed planet)
## between the space and far-star layers, both scroll with speed_scale, the star-layer
## speeds are unchanged, and clearing the theme removes the layers.

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
	_expect(theme.nebula_count() == 4 and theme.rock_count() == 5, "default theme has 4 nebula discs and 5 rocks")

	var nebula := background.get_nebula_layer()
	var rocks := background.get_rock_layer()
	_expect(nebula != null and rocks != null, "theme builds nebula and rock layers")
	if nebula == null or rocks == null:
		_finish()
		return
	_expect(nebula.get_node_or_null("BaseTint") is ColorRect, "nebula layer starts with the base tint")
	_expect(nebula.get_child_count() == 1 + theme.nebula_count(), "one disc per nebula entry")
	_expect(rocks.get_child_count() == theme.rock_count() + 1, "one polygon per rock plus the planet")
	_expect(rocks.get_node_or_null("Planet/Ring") is Line2D, "planet carries its ring")

	var space_index := background.space_layer.get_index()
	_expect(nebula.get_index() == space_index + 1, "nebula sits right above the space layer")
	_expect(rocks.get_index() == space_index + 2, "rocks sit above the nebula")
	_expect(rocks.get_index() < background.far_stars_layer.get_index(), "rocks stay below the far stars")

	var viewport_size: Vector2 = background.get_viewport().get_visible_rect().size
	_expect(is_equal_approx(nebula.motion_mirroring.y, viewport_size.y), "nebula tiles with the viewport height")
	var base := nebula.get_node("BaseTint") as ColorRect
	_expect(base.size.is_equal_approx(viewport_size), "base tint covers the viewport")

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
	await process_frame
	_expect(is_equal_approx(nebula.motion_offset.y, nebula_before), "speed_scale 0 stops the nebula")

	background.backdrop = null
	await process_frame
	_expect(background.get_nebula_layer() == null and background.get_rock_layer() == null, "clearing the theme removes both layers")
	_expect(background.get_node_or_null("NebulaLayer") == null, "no stale nebula node remains")

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
