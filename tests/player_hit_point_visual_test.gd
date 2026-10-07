extends SceneTree

## The player's hit point marker must be a hard-edged disc drawn at exactly the
## hurtbox radius, so the visual tells the truth about the judgement area and
## does not appear to drift while the ship moves at sub-pixel positions.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hit_point_scene := load("res://player_ship/player_hit_point.tscn") as PackedScene
	var hit_point := hit_point_scene.instantiate() as PlayerHitPoint
	root.add_child(hit_point)
	await process_frame

	var visual := hit_point.get_node_or_null("Visual") as Node2D
	var core := hit_point.get_node_or_null("Visual/Core") as PlayerHitPointCore
	var shape_node := hit_point.get_node_or_null("HurtboxComponent/CollisionShape2D") as CollisionShape2D
	_expect(visual != null, "hit point has a Visual container")
	_expect(core != null, "hit point core is a PlayerHitPointCore drawn node, not a glow sprite")
	_expect(shape_node != null and shape_node.shape is CircleShape2D, "hurtbox uses a circle shape")
	if core == null or shape_node == null or visual == null:
		_finish()
		return

	var shape := shape_node.shape as CircleShape2D
	_expect(is_equal_approx(core.radius, shape.radius), "core outer radius equals the hurtbox radius")
	_expect(core.outline_width > 0.0, "core keeps a dark outline so the edge stays readable")
	_expect(core.outline_width < core.radius, "outline is drawn inside the outer radius, never beyond the hurtbox")
	_expect(core.material == null, "core is drawn without an additive glow material")
	_expect(visual.get_child(visual.get_child_count() - 1) == core, "core is drawn on top of the glow layers")

	hit_point.radius = PlayerHitPoint.BASE_RADIUS * 2.0
	_expect(visual.scale.is_equal_approx(Vector2.ONE * 2.0), "glow layers scale with the hit point radius")
	_expect(shape_node.scale.is_equal_approx(Vector2.ONE * 2.0), "hurtbox scales with the hit point radius")
	_expect(is_equal_approx(core.radius, hit_point.radius), "core is redrawn at the new radius")
	_expect(
		(core.scale * visual.scale).is_equal_approx(Vector2.ONE),
		"core cancels the visual scale so its outline stays one pixel wide",
	)
	_expect(
		is_equal_approx(core.radius, shape.radius * shape_node.scale.x),
		"core outer radius still equals the scaled hurtbox radius",
	)

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("player hit point visual test: PASS")
		quit()
		return
	for failure in failures:
		push_error("player hit point visual test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
