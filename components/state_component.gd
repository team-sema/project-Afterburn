# Give the component a class name so it can be instanced as a custom node
class_name StateComponent
extends Node

# Create some signals for the state
signal entering() # Emit when the state is entering (can surely do something before enabling the state)
signal enabled() # Emit when the state has been enabled
signal disabled() # Emit when the state has been disabled
signal state_finished() # Emit when the state is finished (not always the same as disabling it)

var is_active: bool = false

# This function is used to disable the state (and all its children)
func disable() -> void:
	# We can set the process mode to disabled to disable the node and its children
	process_mode = Node.PROCESS_MODE_DISABLED

	if not is_active:
		return

	is_active = false
	disabled.emit()

# This function is used to enable the state (and all its children)
func enable() -> void:
	if is_active:
		return

	entering.emit()

	# We can set the process mode to inherit to enable the node and its children
	# We use inherit so this node will still pause if the game is paused or a parent is disabled
	process_mode = Node.PROCESS_MODE_INHERIT
	is_active = true
	enabled.emit()
