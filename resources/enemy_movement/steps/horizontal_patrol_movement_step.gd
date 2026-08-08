class_name HorizontalPatrolMovementStep
extends MovementStep

## Explicit combat patrol. It reflects inside CombatArea rather than treating
## the visible camera edge as a universal movement wall.
@export_range(0.0, 1000.0, 1.0) var speed := 50.0
@export_range(0.0, 256.0, 1.0) var edge_margin := 8.0
@export var choose_random_initial_direction := true
@export var initial_direction := 1.0


func create_runtime_state() -> Dictionary:
	return {"direction": 1.0}


func start(context: Dictionary, state: Dictionary) -> void:
	var direction_sign := signf(initial_direction)
	if context.has("initial_direction"):
		var configured := context["initial_direction"] as Vector2
		if not is_zero_approx(configured.x):
			direction_sign = signf(configured.x)
	elif choose_random_initial_direction:
		direction_sign = -1.0 if randf() < 0.5 else 1.0
	state["direction"] = direction_sign if not is_zero_approx(direction_sign) else 1.0


func update_movement(
	_delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	var base_position := context.get("base_position", Vector2.ZERO) as Vector2
	var combat_area := context.get("combat_area", Rect2()) as Rect2
	var left := combat_area.position.x + edge_margin
	var right := combat_area.end.x - edge_margin
	var direction_sign := float(state["direction"])
	if base_position.x < left:
		direction_sign = 1.0
		base_position.x = left
		intent.set_global_position(base_position, Vector2(speed, 0.0))
	elif base_position.x > right:
		direction_sign = -1.0
		base_position.x = right
		intent.set_global_position(base_position, Vector2(-speed, 0.0))
	else:
		intent.set_velocity(Vector2(direction_sign * speed, 0.0))
	state["direction"] = direction_sign
