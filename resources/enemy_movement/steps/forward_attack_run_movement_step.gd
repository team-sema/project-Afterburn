class_name ForwardAttackRunMovementStep
extends MovementStep

## High-speed aircraft movement. Rotation is applied first, then velocity is
## derived exclusively from the actor's configured local forward axis. It does
## not clamp, bounce, strafe, or track a target after start().

@export var local_forward_direction := Vector2.DOWN
@export var target_direction := Vector2.DOWN
@export var direction_context_key: StringName = &"attack_run_direction"
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var speed := 210.0
@export_range(0.0, 1440.0, 1.0, "suffix:deg/s") var turn_speed_degrees := 360.0
@export var face_direction_on_start := true
## Zero means the run continues until normal DespawnArea cleanup.
@export_range(0.0, 60.0, 0.05, "suffix:s") var duration := 0.0


func create_runtime_state() -> Dictionary:
	return {
		"elapsed": 0.0,
		"distance": 0.0,
		"run_direction": Vector2.DOWN,
		"finished": false,
	}


func start(context: Dictionary, state: Dictionary) -> void:
	var run_direction := target_direction
	if direction_context_key != &"" and context.has(direction_context_key):
		run_direction = context[direction_context_key] as Vector2
	if run_direction.is_zero_approx():
		run_direction = Vector2.DOWN
	run_direction = run_direction.normalized()
	state["elapsed"] = 0.0
	state["distance"] = 0.0
	state["run_direction"] = run_direction
	state["finished"] = false
	if face_direction_on_start:
		var actor := context.get("actor") as Node2D
		if actor != null:
			actor.global_rotation = _rotation_for_direction(run_direction)


func update_movement(
	delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	var actor := context.get("actor") as Node2D
	if actor == null:
		push_error("ForwardAttackRunMovementStep requires a Node2D actor.")
		intent.set_velocity(Vector2.ZERO)
		return
	var run_direction := state.get("run_direction", Vector2.DOWN) as Vector2
	var desired_rotation := _rotation_for_direction(run_direction)
	var turn_step := deg_to_rad(turn_speed_degrees) * maxf(delta, 0.0)
	var next_rotation := rotate_toward(actor.global_rotation, desired_rotation, turn_step)
	var forward := _get_local_forward().rotated(next_rotation)
	var target_velocity := forward * speed
	intent.set_velocity_and_rotation(target_velocity, next_rotation)

	state["elapsed"] = float(state["elapsed"]) + delta
	state["distance"] = (
		float(state["distance"])
		+ target_velocity.length() * float(context.get("speed_multiplier", 1.0)) * delta
	)
	if duration > 0.0 and float(state["elapsed"]) >= duration:
		state["finished"] = true


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return bool(state.get("finished", false))


func _rotation_for_direction(direction: Vector2) -> float:
	return direction.angle() - _get_local_forward().angle()


func _get_local_forward() -> Vector2:
	return (
		local_forward_direction.normalized()
		if not local_forward_direction.is_zero_approx()
		else Vector2.DOWN
	)
