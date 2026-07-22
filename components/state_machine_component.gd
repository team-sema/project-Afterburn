class_name StateMachineComponent
extends Node

var current_state: StateComponent


func _ready() -> void:
	for child in get_children():
		if child is StateComponent:
			child.disable()


func start(initial_state: StateComponent) -> void:
	change_state(initial_state)


func change_state(next_state: StateComponent) -> void:
	if current_state:
		current_state.disable()

	current_state = next_state
	current_state.enable()
