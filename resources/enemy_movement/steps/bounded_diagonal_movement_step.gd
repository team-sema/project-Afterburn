class_name BoundedDiagonalMovementStep
extends MovementStep

## Moves forward on a diagonal while reflecting the actor's base position
## between viewport bounds. Used by a formation center, so the path is
## calculated once regardless of member count.

@export_range(0.0, 1000.0, 1.0) var forward_speed := 72.0
@export_range(0.0, 80.0, 0.5) var angle_degrees := 50.0
@export_range(0.0, 256.0, 1.0) var edge_margin := 8.0
@export_range(0.0, 60.0, 0.05) var duration := 0.0
@export var horizontal_direction_context_key: StringName = &"formation_direction"
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
	var viewport_rect := context.get("viewport_rect", Rect2()) as Rect2
	var half_span := maxf(0.0, float(context.get(half_span_context_key, 0.0)))
	var left := viewport_rect.position.x + edge_margin + half_span
	var right := viewport_rect.end.x - edge_margin - half_span
	var horizontal_sign := float(state["horizontal_sign"])
	var angle := deg_to_rad(angle_degrees)
	var base_velocity := Vector2(
		sin(angle) * horizontal_sign,
		cos(angle),
	) * forward_speed
	var speed_multiplier := float(context.get("speed_multiplier", 1.0))
	var target := current + base_velocity * speed_multiplier * delta

	if right <= left:
		target.x = clampf(target.x, left, right)
	else:
		for _reflection in 4:
			if target.x < left:
				target.x = left + (left - target.x)
				horizontal_sign = 1.0
			elif target.x > right:
				target.x = right - (target.x - right)
				horizontal_sign = -1.0
			else:
				break

	state["horizontal_sign"] = horizontal_sign
	state["elapsed"] = float(state["elapsed"]) + delta
	if duration > 0.0 and float(state["elapsed"]) >= duration:
		state["finished"] = true
	intent.set_global_position(target, base_velocity)


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return bool(state.get("finished", false))
