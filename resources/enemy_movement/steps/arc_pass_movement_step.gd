class_name ArcPassMovementStep
extends MovementStep

## Flies one large arc that passes beside the target: the arc is the circle
## through the actor whose lowest-reach point (heading straight down) is the
## pass point next to the target. The target is low-pass filtered, the turn
## rate is capped, and on the approach the nose only ever turns one way (the
## arc's own bend): when the target would ask it to unbend, it flies straight.
## So the path is always a single arc and the nose never nods. Once released it keeps curving the same way, away
## from the target, until it points exit_heading_degrees off straight down on
## the far side, and accelerates out. It never climbs.

@export_range(1.0, 1000.0, 1.0) var approach_speed := 170.0
@export_range(1.0, 2000.0, 1.0) var released_speed := 300.0
@export_range(0.0, 5000.0, 1.0) var released_acceleration := 400.0
## Pass point relative to the target: x is the sideways gap (applied on the
## side the actor comes from), y the height (negative = above the target).
@export var pass_offset := Vector2(36.0, -14.0)
@export_range(0.01, 5.0, 0.01) var target_smoothing_time := 0.4
@export_range(1.0, 1080.0, 1.0) var max_turn_rate_degrees := 120.0
## Heading never tilts further than this from straight down.
@export_range(0.0, 89.0, 1.0) var max_heading_degrees := 80.0
@export_range(10.0, 2000.0, 1.0) var min_exit_radius := 100.0
@export_range(10.0, 2000.0, 1.0) var max_exit_radius := 160.0
@export_range(0.0, 80.0, 1.0) var exit_heading_degrees := 35.0
@export var target_context_key: StringName = &"player_position"
@export var release_context_key: StringName = &"steer_released"


func create_runtime_state() -> Dictionary:
	return {
		"heading": Vector2.DOWN,
		"speed": approach_speed,
		"side": 1.0,
		"smoothed_target": Vector2.ZERO,
		"arc_radius": max_exit_radius,
		"exit_side": 0.0,
	}


func start(context: Dictionary, state: Dictionary) -> void:
	var position := context.get("base_position", Vector2.ZERO) as Vector2
	var target := _read_target(context, position)
	var side := signf(position.x - target.x)
	if is_zero_approx(side):
		var visible_rect := context.get("visible_rect", Rect2()) as Rect2
		side = -1.0 if position.x < visible_rect.get_center().x else 1.0
	state["side"] = side
	state["smoothed_target"] = target
	state["speed"] = approach_speed
	state["arc_radius"] = max_exit_radius
	state["exit_side"] = 0.0
	state["heading"] = _clamp_heading(_arc_heading(position, _pass_point(target, side), state))


func update_movement(
	delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	var position := context.get("base_position", Vector2.ZERO) as Vector2
	var heading := state["heading"] as Vector2
	var side := float(state["side"])
	var speed := float(state["speed"])
	if bool(context.get(release_context_key, false)):
		speed = move_toward(speed, released_speed, released_acceleration * delta)
		# Curve away from where the target is now (it may have crossed to our
		# side), then dive out along the exit heading.
		var exit_side := float(state["exit_side"])
		if is_zero_approx(exit_side):
			var target := _read_target(context, position)
			exit_side = signf(position.x - target.x) if absf(position.x - target.x) > 4.0 else side
			state["exit_side"] = exit_side
		var exit_heading := Vector2.DOWN.rotated(-exit_side * deg_to_rad(exit_heading_degrees))
		var max_step := speed / float(state["arc_radius"]) * delta
		heading = heading.rotated(clampf(heading.angle_to(exit_heading), -max_step, max_step))
	else:
		var target := _read_target(context, position)
		var smoothed := state["smoothed_target"] as Vector2
		smoothed = smoothed.lerp(target, 1.0 - exp(-delta / target_smoothing_time))
		state["smoothed_target"] = smoothed
		var desired := _arc_heading(position, _pass_point(smoothed, side), state)
		var max_step := deg_to_rad(max_turn_rate_degrees) * delta
		# Approaching from side -1 the arc bends with increasing angle, from +1
		# with decreasing; never turn the other way.
		var bend := -side
		var angle := clampf(heading.angle_to(desired) * bend, 0.0, max_step) * bend
		heading = heading.rotated(angle)
	heading = _clamp_heading(heading)
	state["heading"] = heading
	state["speed"] = speed
	intent.set_velocity(heading * speed)


func is_finished(_context: Dictionary, _state: Dictionary) -> bool:
	return false


func _read_target(context: Dictionary, position: Vector2) -> Vector2:
	if context.has(target_context_key):
		return context[target_context_key] as Vector2
	var visible_rect := context.get("visible_rect", Rect2()) as Rect2
	return Vector2(position.x, visible_rect.end.y - 60.0)


func _pass_point(target: Vector2, side: float) -> Vector2:
	return target + Vector2(side * pass_offset.x, pass_offset.y)


## Tangent of the circle through `position` that reaches `pass_point` heading
## straight down (its centre lies level with the pass point), travelled from
## the actor's side over the top toward the pass point. Records the radius so
## the exit can keep the same curvature.
func _arc_heading(position: Vector2, pass_point: Vector2, state: Dictionary) -> Vector2:
	var offset := position - pass_point
	if offset.y >= 0.0 or absf(offset.x) < 0.5:
		return Vector2.DOWN
	var side := float(state["side"])
	if signf(offset.x) != side:
		# The target moved over to our side: no outside arc exists any more, so
		# head for the pass point directly (still turn-rate limited).
		return -offset.normalized()
	var k := offset.length_squared() / (2.0 * offset.x)
	if absf(offset.x) > 8.0:
		state["arc_radius"] = clampf(absf(k), min_exit_radius, max_exit_radius)
	var center := Vector2(pass_point.x + k, pass_point.y)
	var radial := position - center
	# Coming from the left (side -1) the arc turns clockwise on screen, from the
	# right counter-clockwise. On the far half of a wide circle this points
	# upward; _clamp_heading flattens it into a shallow descent instead.
	var tangent := Vector2(side * radial.y, -side * radial.x)
	return tangent.normalized() if not tangent.is_zero_approx() else Vector2.DOWN


func _clamp_heading(heading: Vector2) -> Vector2:
	var limit := deg_to_rad(max_heading_degrees)
	var angle := clampf(Vector2.DOWN.angle_to(heading), -limit, limit)
	return Vector2.DOWN.rotated(angle)
