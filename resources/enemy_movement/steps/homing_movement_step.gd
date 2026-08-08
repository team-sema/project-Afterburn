class_name HomingMovementStep
extends MovementStep

@export_range(0.0, 1000.0, 1.0) var speed := 100.0
@export_range(0.0, 60.0, 0.05) var duration := 0.0
@export_range(0.0, 100.0, 0.5) var stop_distance := 0.0
@export var target_context_key: StringName = &"player_position"


func create_runtime_state() -> Dictionary:
	return {"elapsed": 0.0, "finished": false, "warned_missing_target": false}


func start(_context: Dictionary, state: Dictionary) -> void:
	state["elapsed"] = 0.0
	state["finished"] = false
	state["warned_missing_target"] = false


func update_movement(
	delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	state["elapsed"] = float(state["elapsed"]) + delta
	if duration > 0.0 and float(state["elapsed"]) >= duration:
		state["finished"] = true
	if not context.has(target_context_key):
		if not bool(state["warned_missing_target"]):
			push_warning("HomingMovementStep is missing context '%s'." % target_context_key)
			state["warned_missing_target"] = true
		intent.set_velocity(Vector2.ZERO)
		return
	var current := context.get("base_position", Vector2.ZERO) as Vector2
	var target := context[target_context_key] as Vector2
	if stop_distance > 0.0 and current.distance_to(target) <= stop_distance:
		state["finished"] = true
		intent.set_velocity(Vector2.ZERO)
		return
	intent.set_velocity(current.direction_to(target) * speed)


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return bool(state.get("finished", false))
