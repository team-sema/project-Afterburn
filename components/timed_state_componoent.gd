# Give the component a class name so it can be instanced as a custom node
class_name TimedStateComponent

# Extend the state
extends StateComponent

# This component emits state_finished after a duration so the state machine can
# decide which state comes next

# Export the duration for this state
@export var duration: float = 1.0

# Create a new timer
var timer := Timer.new()

func _ready() -> void:
	# Add the timer as a child so we can use it
	add_child(timer)
	timer.one_shot = true
	
	# Emit finished so the state machine can decide which state comes next
	timer.timeout.connect(state_finished.emit)
	
	# Read duration when the state starts so difficulty modifiers can change it.
	enabled.connect(_start_timer)
	disabled.connect(timer.stop)


func _start_timer() -> void:
	timer.start(duration)
