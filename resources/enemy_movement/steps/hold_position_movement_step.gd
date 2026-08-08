class_name HoldPositionMovementStep
extends MovementStep

## Holds the actor in place forever (never finishes). Used after sniper entry.


func update_movement(
	_delta: float,
	_context: Dictionary,
	_state: Dictionary,
	intent: MovementIntent,
) -> void:
	intent.set_velocity(Vector2.ZERO)


func is_finished(_context: Dictionary, _state: Dictionary) -> bool:
	return false
