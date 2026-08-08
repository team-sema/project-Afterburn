class_name MovementSequence
extends Resource

@export var steps: Array[MovementStep] = []
@export var loop := false


func validate() -> bool:
	if steps.is_empty():
		push_error("MovementSequence has no steps: %s" % resource_path)
		return false
	for index in steps.size():
		if steps[index] == null:
			push_error("MovementSequence step %d is null: %s" % [index, resource_path])
			return false
		if steps[index].get_script() == MovementStep:
			push_error("MovementSequence step %d uses the abstract base MovementStep." % index)
			return false
	return true
