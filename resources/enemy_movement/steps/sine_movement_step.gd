class_name SineMovementStep
extends MovementStep

## The forward path advances at forward_speed while the perpendicular position
## follows amplitude * sin(TAU * elapsed / period).
@export var forward_direction := Vector2.DOWN
@export_range(0.0, 1000.0, 1.0) var forward_speed := 60.0
@export_range(0.0, 500.0, 1.0) var amplitude := 32.0
@export_range(0.05, 30.0, 0.05) var period := 1.5
## Zero means the step continues indefinitely.
@export_range(0.0, 60.0, 0.05) var duration := 0.0
@export var direction_context_key: StringName
## Optional numeric sign supplied by context so the same sequence can mirror.
@export var lateral_sign_context_key: StringName


func create_runtime_state() -> Dictionary:
	return {"elapsed": 0.0, "finished": false}


func start(_context: Dictionary, state: Dictionary) -> void:
	state["elapsed"] = 0.0
	state["finished"] = false


func update_movement(
	delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	var configured_direction := forward_direction
	if direction_context_key != &"" and context.has(direction_context_key):
		configured_direction = context[direction_context_key] as Vector2
	if configured_direction.is_zero_approx():
		configured_direction = Vector2.DOWN
	var forward := configured_direction.normalized()
	var lateral := Vector2(-forward.y, forward.x)
	if lateral_sign_context_key != &"":
		lateral *= signf(float(context.get(lateral_sign_context_key, 1.0)))
	var angular_speed := TAU / maxf(0.05, period)
	var elapsed := float(state["elapsed"])
	var lateral_speed := amplitude * angular_speed * cos(angular_speed * elapsed)
	intent.set_velocity(forward * forward_speed + lateral * lateral_speed)
	state["elapsed"] = elapsed + delta
	if duration > 0.0 and float(state["elapsed"]) >= duration:
		state["finished"] = true


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return bool(state.get("finished", false))
