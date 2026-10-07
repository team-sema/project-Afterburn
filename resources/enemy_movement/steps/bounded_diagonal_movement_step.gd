class_name BoundedDiagonalMovementStep
extends MovementStep

## Constant diagonal zigzag for formations. The formation's occupied extent
## (left/right distance from the center to its outermost live member, supplied
## by FormationController every frame) reflects against VisibleRect minus
## `edge_margin`, so no member leaves the camera and the lane widens as wings
## die. See docs/design/formations/index.md 「편대 이동 경계」.
##
## A center that is already outside its lane (offscreen spawn, a lane that just
## shrank) is never snapped: it only heads inward until it is back inside.

@export_range(0.0, 1000.0, 1.0) var forward_speed := 72.0
@export_range(0.0, 80.0, 0.5) var angle_degrees := 50.0
## Gap kept between the outermost member's slot and the camera edge. Covers the
## member's own half-width (~8px for a Drone) plus a little air.
@export_range(0.0, 256.0, 1.0) var edge_margin := 12.0
@export_range(0.0, 60.0, 0.05) var duration := 0.0
@export var horizontal_direction_context_key: StringName = &"formation_direction"
## Distance from the formation center to its leftmost / rightmost live member.
@export var extent_left_context_key: StringName = &"formation_extent_left"
@export var extent_right_context_key: StringName = &"formation_extent_right"
## Fallback when no extents are supplied (symmetric span, legacy callers).
@export var half_span_context_key: StringName = &"formation_half_span"


func create_runtime_state() -> Dictionary:
	return {"elapsed": 0.0, "horizontal_sign": 1.0, "finished": false}


func start(context: Dictionary, state: Dictionary) -> void:
	var configured := context.get(horizontal_direction_context_key, Vector2.RIGHT) as Vector2
	var horizontal_sign := signf(configured.x)
	state["elapsed"] = 0.0
	state["horizontal_sign"] = horizontal_sign if not is_zero_approx(horizontal_sign) else 1.0
	state["finished"] = false


func update_movement(
	delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	var current := context.get("base_position", Vector2.ZERO) as Vector2
	var lane := get_lane(context)
	var left := lane.x
	var right := lane.y
	var horizontal_sign := float(state["horizontal_sign"])
	var angle := deg_to_rad(angle_degrees)
	var speed_multiplier := float(context.get("speed_multiplier", 1.0))

	if right <= left:
		# Formation wider than the camera: hold the lane center, keep descending.
		horizontal_sign = 0.0
	elif current.x < left:
		horizontal_sign = 1.0
	elif current.x > right:
		horizontal_sign = -1.0

	var base_velocity := Vector2(
		sin(angle) * horizontal_sign,
		cos(angle),
	) * forward_speed
	var target := current + base_velocity * speed_multiplier * delta
	if right <= left:
		target.x = (left + right) * 0.5
	elif current.x >= left and current.x <= right:
		for _reflection in 4:
			if target.x < left:
				target.x = left + (left - target.x)
				horizontal_sign = 1.0
			elif target.x > right:
				target.x = right - (target.x - right)
				horizontal_sign = -1.0
			else:
				break
		base_velocity.x = sin(angle) * horizontal_sign * forward_speed

	state["horizontal_sign"] = horizontal_sign if not is_zero_approx(horizontal_sign) else 1.0
	state["elapsed"] = float(state["elapsed"]) + delta
	if duration > 0.0 and float(state["elapsed"]) >= duration:
		state["finished"] = true
	intent.set_global_position(target, base_velocity)


## [left, right] bounds for the formation center this frame.
func get_lane(context: Dictionary) -> Vector2:
	var visible_rect := context.get("visible_rect", Rect2()) as Rect2
	var extent_left: float
	var extent_right: float
	if context.has(extent_left_context_key) or context.has(extent_right_context_key):
		extent_left = maxf(0.0, float(context.get(extent_left_context_key, 0.0)))
		extent_right = maxf(0.0, float(context.get(extent_right_context_key, 0.0)))
	else:
		var half_span := maxf(0.0, float(context.get(half_span_context_key, 0.0)))
		extent_left = half_span
		extent_right = half_span
	return Vector2(
		visible_rect.position.x + edge_margin + extent_left,
		visible_rect.end.x - edge_margin - extent_right,
	)


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return bool(state.get("finished", false))
