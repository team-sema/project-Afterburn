class_name LinearMovementStep
extends MovementStep

@export var direction := Vector2.DOWN
@export_range(0.0, 1000.0, 1.0) var speed := 40.0
## Zero means no time limit.
@export_range(0.0, 60.0, 0.05) var duration := 0.0
## Zero means no distance limit.
@export_range(0.0, 5000.0, 1.0) var max_distance := 0.0
## Optional Vector2 supplied by MovementController context.
@export var direction_context_key: StringName


func create_runtime_state() -> Dictionary:
	return {"elapsed": 0.0, "distance": 0.0, "finished": false}


func start(_context: Dictionary, state: Dictionary) -> void:
	state["elapsed"] = 0.0
	state["distance"] = 0.0
	state["finished"] = false


func update_movement(
	delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	var configured_direction := direction
	if direction_context_key != &"" and context.has(direction_context_key):
		configured_direction = context[direction_context_key] as Vector2
	if configured_direction.is_zero_approx():
		configured_direction = Vector2.DOWN
	var target_velocity := configured_direction.normalized() * speed
	intent.set_velocity(target_velocity)
	state["elapsed"] = float(state["elapsed"]) + delta
	state["distance"] = (
		float(state["distance"])
		+ target_velocity.length() * float(context.get("speed_multiplier", 1.0)) * delta
	)
	if duration > 0.0 and float(state["elapsed"]) >= duration:
		state["finished"] = true
	if max_distance > 0.0 and float(state["distance"]) >= max_distance:
		state["finished"] = true


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return bool(state.get("finished", false))
