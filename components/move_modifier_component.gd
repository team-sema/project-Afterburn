class_name MoveModifierComponent
extends Node

## Additive movement caused by weapon traits. AI movement remains owned by MoveComponent
## or a formation controller; those owners advance this component and apply its offset.

@export_range(0.1, 30.0, 0.1) var velocity_damping := 7.0
@export_range(0.1, 30.0, 0.1) var offset_recovery := 2.5

var external_velocity := Vector2.ZERO
var _offset := Vector2.ZERO


func apply_impulse(impulse: Vector2) -> void:
	external_velocity += impulse


func advance(delta: float) -> Vector2:
	if delta <= 0.0:
		return Vector2.ZERO
	var previous_offset := _offset
	var velocity_factor := exp(-velocity_damping * delta)
	var recovery_factor := exp(-offset_recovery * delta)
	# Integrate a damped impulse while the accumulated offset recovers toward zero.
	if is_equal_approx(velocity_damping, offset_recovery):
		_offset = (_offset + external_velocity * delta) * recovery_factor
	else:
		var impulse_factor := (
			(velocity_factor - recovery_factor) / (offset_recovery - velocity_damping)
		)
		_offset = _offset * recovery_factor + external_velocity * impulse_factor
	external_velocity *= velocity_factor
	if external_velocity.length_squared() < 0.0001:
		external_velocity = Vector2.ZERO
	if _offset.length_squared() < 0.0001:
		_offset = Vector2.ZERO
	return _offset - previous_offset


func get_offset() -> Vector2:
	return _offset


func reset() -> void:
	external_velocity = Vector2.ZERO
	_offset = Vector2.ZERO
