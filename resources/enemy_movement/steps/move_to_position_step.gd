class_name MoveToPositionStep
extends MovementStep

@export var target_position := Vector2.ZERO
## Interpret target_position as a 0..1 position inside the current viewport.
@export var target_position_is_viewport_ratio := false
@export var target_context_key: StringName
@export_range(0.0, 1000.0, 1.0) var speed := 60.0
@export_range(0.01, 20.0, 0.01) var arrival_tolerance := 0.5
@export var affect_x := true
@export var affect_y := true


func create_runtime_state() -> Dictionary:
	return {"target": Vector2.ZERO, "finished": false}


func start(context: Dictionary, state: Dictionary) -> void:
	var target := target_position
	if target_position_is_viewport_ratio:
		var viewport_rect := context.get("viewport_rect", Rect2()) as Rect2
		target = viewport_rect.position + viewport_rect.size * target_position
	elif target_context_key != &"" and context.has(target_context_key):
		target = context[target_context_key] as Vector2
	var current := context.get("base_position", Vector2.ZERO) as Vector2
	if not affect_x:
		target.x = current.x
	if not affect_y:
		target.y = current.y
	state["target"] = target
	state["finished"] = current.distance_to(target) <= arrival_tolerance


func update_movement(
	delta: float,
	context: Dictionary,
	state: Dictionary,
	intent: MovementIntent,
) -> void:
	var current := context.get("base_position", Vector2.ZERO) as Vector2
	var target := state["target"] as Vector2
	var distance := current.distance_to(target)
	var effective_speed := speed * float(context.get("speed_multiplier", 1.0))
	if distance <= maxf(arrival_tolerance, effective_speed * delta):
		intent.set_global_position(target)
		state["finished"] = true
		return
	if speed <= 0.0:
		intent.set_velocity(Vector2.ZERO)
		return
	intent.set_velocity(current.direction_to(target) * speed)


func is_finished(_context: Dictionary, state: Dictionary) -> bool:
	return bool(state.get("finished", false))
