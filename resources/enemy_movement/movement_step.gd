class_name MovementStep
extends Resource

## Configuration-only movement unit. Every runtime value must live in the
## Dictionary returned by create_runtime_state().


func create_runtime_state() -> Dictionary:
	return {}


func start(_context: Dictionary, _state: Dictionary) -> void:
	pass


func update_movement(
	_delta: float,
	_context: Dictionary,
	_state: Dictionary,
	intent: MovementIntent,
) -> void:
	push_error("%s must implement update_movement()." % resource_path)


func is_finished(_context: Dictionary, _state: Dictionary) -> bool:
	return false


func stop(_context: Dictionary, _state: Dictionary) -> void:
	pass
