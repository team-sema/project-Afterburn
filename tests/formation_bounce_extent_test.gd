extends SceneTree

## Formation wall reflection uses the formation's live occupied extent against
## VisibleRect (docs/design/formations/index.md 「편대 이동 경계」):
## - BoundedDiagonalMovementStep reflects [center - extent_left, center + extent_right]
##   inside VisibleRect minus edge_margin, and only heads inward when already outside.
## - FormationController publishes extents every frame; they shrink as members die.
## - A zigzag formation never puts a member outside the camera, and the lane widens
##   after a wing dies.

const CONTROLLER_SCENE := preload("res://formations/formation_controller.tscn")
const HORIZONTAL_LAYOUT := preload("res://formations/layouts/horizontal_formation.tscn")
const ZIGZAG := preload("res://resources/enemy_movement/sequences/zigzag.tres")
const ENEMY_RADIUS := 8.0

var failures := PackedStringArray()
var registry: EnemyAugmentRegistry


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	registry = EnemyAugmentRegistry.new()
	registry.name = "FormationBounceTestRegistry"
	root.add_child(registry)
	_test_step_reflects_occupied_extent()
	_test_step_outside_lane_heads_inward_without_snapping()
	await _test_controller_publishes_live_extents()
	await _test_zigzag_formation_stays_on_camera_and_widens()
	registry.queue_free()
	await process_frame
	if failures.is_empty():
		print("formation_bounce_extent_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("formation_bounce_extent_test: %s" % failure)
	quit(1)


func _make_context(x: float, extent_left: float, extent_right: float) -> Dictionary:
	return {
		"base_position": Vector2(x, 100.0),
		"global_position": Vector2(x, 100.0),
		"visible_rect": Rect2(0.0, 0.0, 640.0, 360.0),
		"movement_area": Rect2(-128.0, -72.0, 896.0, 522.0),
		"speed_multiplier": 1.0,
		"formation_extent_left": extent_left,
		"formation_extent_right": extent_right,
		"formation_direction": Vector2.RIGHT,
	}


func _test_step_reflects_occupied_extent() -> void:
	var step := BoundedDiagonalMovementStep.new()
	step.forward_speed = 72.0
	step.angle_degrees = 50.0
	step.edge_margin = 12.0
	var lane := step.get_lane(_make_context(0.0, 48.0, 24.0))
	_expect(is_equal_approx(lane.x, 60.0) and is_equal_approx(lane.y, 604.0), "lane = VisibleRect inset by margin + extents (%s)" % lane)

	var state := step.create_runtime_state()
	var context := _make_context(600.0, 48.0, 24.0)
	step.start(context, state)
	var intent := MovementIntent.new()
	step.update_movement(0.5, context, state, intent)
	var dx := sin(deg_to_rad(50.0)) * 72.0 * 0.5
	var expected_x := 604.0 - ((600.0 + dx) - 604.0)
	_expect(
		is_equal_approx(intent.global_position.x, expected_x),
		"overshoot past the right lane edge is mirrored back (%f vs %f)" % [intent.global_position.x, expected_x],
	)
	_expect(float(state["horizontal_sign"]) < 0.0, "reflection flips the horizontal sign")
	_expect(intent.velocity.x < 0.0, "reported velocity points inward after the turn")

	# Symmetric fallback when only the legacy half-span is present.
	var legacy := _make_context(0.0, 0.0, 0.0)
	legacy.erase("formation_extent_left")
	legacy.erase("formation_extent_right")
	legacy["formation_half_span"] = 30.0
	var legacy_lane := step.get_lane(legacy)
	_expect(is_equal_approx(legacy_lane.x, 42.0) and is_equal_approx(legacy_lane.y, 598.0), "half_span fallback keeps a symmetric lane")

	# Formation wider than the camera: hold the lane center.
	var wide := _make_context(100.0, 400.0, 400.0)
	var wide_state := step.create_runtime_state()
	step.start(wide, wide_state)
	var wide_intent := MovementIntent.new()
	step.update_movement(0.1, wide, wide_state, wide_intent)
	_expect(is_equal_approx(wide_intent.global_position.x, 320.0), "over-wide formation holds the lane center")


func _test_step_outside_lane_heads_inward_without_snapping() -> void:
	var step := BoundedDiagonalMovementStep.new()
	step.forward_speed = 72.0
	step.angle_degrees = 50.0
	step.edge_margin = 12.0
	var state := step.create_runtime_state()
	# Offscreen spawn on the left, authored to travel left: must turn right, no snap.
	var context := _make_context(-100.0, 48.0, 48.0)
	context["formation_direction"] = Vector2.LEFT
	step.start(context, state)
	var intent := MovementIntent.new()
	step.update_movement(0.1, context, state, intent)
	var travel := sin(deg_to_rad(50.0)) * 72.0 * 0.1
	_expect(
		is_equal_approx(intent.global_position.x, -100.0 + travel),
		"outside the lane the formation only heads inward at its normal speed (%f)" % intent.global_position.x,
	)
	# A lane that shrank around the center (late wing spawn): same rule from the right side.
	var shrunk_state := step.create_runtime_state()
	var shrunk := _make_context(610.0, 48.0, 48.0)
	step.start(shrunk, shrunk_state)
	var shrunk_intent := MovementIntent.new()
	step.update_movement(0.1, shrunk, shrunk_state, shrunk_intent)
	_expect(
		is_equal_approx(shrunk_intent.global_position.x, 610.0 - travel),
		"a center caught outside a shrunken lane walks back in without a jump",
	)


func _make_controller(sequence: MovementSequence, mirrored: bool, pending: int) -> FormationController:
	var controller := CONTROLLER_SCENE.instantiate() as FormationController
	controller.formation_layout_scene = HORIZONTAL_LAYOUT
	controller.formation_movement_sequence = sequence
	controller.mirrored = mirrored
	controller.set_pending_member_count(pending)
	root.add_child(controller)
	return controller


func _make_enemy() -> Enemy:
	var enemy := (load("res://enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.augment_registry = registry
	return enemy


func _stationary() -> MovementSequence:
	var step := LinearMovementStep.new()
	step.direction = Vector2.DOWN
	step.speed = 0.0
	var sequence := MovementSequence.new()
	sequence.steps.append(step)
	return sequence


func _test_controller_publishes_live_extents() -> void:
	var controller := _make_controller(_stationary(), false, 2)
	controller.global_position = Vector2(320.0, 60.0)
	# One member bound, one still pending: every authored slot counts.
	var left := _make_enemy()
	controller.add_member(left, 0)
	var pending_extents := controller.get_active_extents()
	_expect(
		is_equal_approx(pending_extents.x, 48.0) and is_equal_approx(pending_extents.y, 48.0),
		"pending spawns keep the full authored span (%s)" % pending_extents,
	)
	var right := _make_enemy()
	controller.add_member(right, 3)
	var bound_extents := controller.get_active_extents()
	_expect(
		is_equal_approx(bound_extents.x, 48.0) and is_equal_approx(bound_extents.y, 24.0),
		"bound slots 0 and 3 give extents 48 / 24 (%s)" % bound_extents,
	)
	controller.start_formation()
	var context := controller.center_movement_controller.get_context()
	_expect(
		is_equal_approx(float(context.get("formation_extent_left", -1.0)), 48.0)
		and is_equal_approx(float(context.get("formation_extent_right", -1.0)), 24.0),
		"start_formation seeds the center context with both extents",
	)
	left.queue_free()
	await process_frame
	await process_frame
	var after := controller.get_active_extents()
	_expect(is_equal_approx(after.x, 0.0) and is_equal_approx(after.y, 24.0), "a dead left wing drops the left extent to 0 (%s)" % after)
	context = controller.center_movement_controller.get_context()
	_expect(
		is_equal_approx(float(context.get("formation_extent_left", -1.0)), 0.0),
		"the center MovementController sees the shrunken extent on the next frame",
	)
	controller.queue_free()
	await process_frame

	# Mirrored: authored -48 becomes +48 on the right.
	var mirrored := _make_controller(_stationary(), true, 1)
	mirrored.add_member(_make_enemy(), 0)
	var mirrored_extents := mirrored.get_active_extents()
	_expect(
		is_equal_approx(mirrored_extents.x, 0.0) and is_equal_approx(mirrored_extents.y, 48.0),
		"mirroring swaps the extents (%s)" % mirrored_extents,
	)
	mirrored.queue_free()
	await process_frame


func _test_zigzag_formation_stays_on_camera_and_widens() -> void:
	var controller := _make_controller(ZIGZAG, false, 2)
	var visible := controller.get_viewport_rect()
	controller.global_position = Vector2(visible.get_center().x, 40.0)
	var left := _make_enemy()
	var right := _make_enemy()
	controller.add_member(left, 0)
	controller.add_member(right, 4)
	controller.start_formation()
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var step := ZIGZAG.steps[0] as BoundedDiagonalMovementStep
	var min_member_x := INF
	var max_member_x := -INF
	var min_center_x := INF
	var dt := 1.0 / 60.0
	for _frame in 1500:
		controller.center_movement_controller.update_movement(dt)
		# Keep the formation on camera vertically so FreeOffscreenComponent never
		# removes members during the engine frames awaited below.
		controller.global_position.y = 40.0
		controller._process(dt)
		for member in [left, right]:
			min_member_x = minf(min_member_x, member.global_position.x)
			max_member_x = maxf(max_member_x, member.global_position.x)
		min_center_x = minf(min_center_x, controller.global_position.x)
	_expect(min_member_x >= visible.position.x + step.edge_margin - 0.01, "leftmost member never leaves the camera (%f)" % min_member_x)
	_expect(max_member_x <= visible.end.x - step.edge_margin + 0.01, "rightmost member never leaves the camera (%f)" % max_member_x)
	_expect(min_member_x < visible.position.x + step.edge_margin + 2.0, "formation actually reaches the left edge (%f)" % min_member_x)
	_expect(max_member_x > visible.end.x - step.edge_margin - 2.0, "formation actually reaches the right edge (%f)" % max_member_x)
	var lane_left := visible.position.x + step.edge_margin + 48.0
	_expect(
		min_center_x >= lane_left - 0.01 and min_center_x < lane_left + 2.0,
		"center stops 48px short of the left edge while the left wing lives (%f)" % min_center_x,
	)

	# Kill the left wing: the lane widens so the center can travel further left.
	left.queue_free()
	await process_frame
	_expect(is_instance_valid(controller) and is_instance_valid(right), "formation survives the left wing's death")
	if not is_instance_valid(controller):
		return
	var widened_min_center_x := INF
	var widened_max_right_x := -INF
	for _frame in 1500:
		controller.center_movement_controller.update_movement(dt)
		controller.global_position.y = 40.0
		controller._process(dt)
		widened_min_center_x = minf(widened_min_center_x, controller.global_position.x)
		widened_max_right_x = maxf(widened_max_right_x, right.global_position.x)
	_expect(
		widened_min_center_x < min_center_x - 40.0,
		"after the left wing dies the center reaches further left (%f < %f)" % [widened_min_center_x, min_center_x],
	)
	_expect(widened_max_right_x <= visible.end.x - step.edge_margin + 0.01, "surviving right wing still never leaves the camera (%f)" % widened_max_right_x)
	controller.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
