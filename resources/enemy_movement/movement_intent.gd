class_name MovementIntent
extends RefCounted

## Per-frame output calculated by a MovementStep. MoveComponent is the only
## class that applies this intent to an actor.

var velocity := Vector2.ZERO
var has_global_position := false
var global_position := Vector2.ZERO
var has_global_rotation := false
var global_rotation := 0.0
var is_valid := false


func reset() -> void:
	velocity = Vector2.ZERO
	has_global_position = false
	global_position = Vector2.ZERO
	has_global_rotation = false
	global_rotation = 0.0
	is_valid = false


func set_velocity(value: Vector2) -> void:
	velocity = value
	is_valid = true


func set_global_position(value: Vector2, target_velocity: Vector2 = Vector2.ZERO) -> void:
	global_position = value
	velocity = target_velocity
	has_global_position = true
	is_valid = true


func set_velocity_and_rotation(value: Vector2, target_global_rotation: float) -> void:
	velocity = value
	global_rotation = target_global_rotation
	has_global_rotation = true
	is_valid = true
