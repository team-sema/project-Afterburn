class_name WaitMovementStep
extends MovementStep

@export_range(0.0, 60.0, 0.05) var duration := 1.0


func create_runtime_state() -> Dictionary:
	return {"elapsed": 0.0}


func start(_context: Dictionary, state: Dictionary) -> void:
	state["elapsed"] = 0.0


func update_movement(
	delta: float,
	_context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	state["elapsed"] = float(state["elapsed"]) + delta
	intent.set_velocity(Vector2.ZERO)


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return float(state.get("elapsed", 0.0)) >= duration
