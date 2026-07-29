class_name PinkEnemy
extends Enemy

@onready var state_machine: StateMachineComponent = %StateMachine

@onready var move_down_state: TimedStateComponent = %MoveDownState
@onready var move_side_state: TimedStateComponent = %MoveSideState
@onready var pause_state: TimedStateComponent = %PauseState


func _ready() -> void:
	super()

	move_down_state.state_finished.connect(
		state_machine.change_state.bind(move_side_state)
	)
	move_side_state.state_finished.connect(
		state_machine.change_state.bind(pause_state)
	)
	pause_state.state_finished.connect(
		state_machine.change_state.bind(move_down_state)
	)

	state_machine.start(move_down_state)
	_tune_baseline_fire()


func _tune_baseline_fire() -> void:
	var shoot := get_node_or_null("EnemyShootComponent") as EnemyShootComponent
	if shoot != null:
		shoot.configure_baseline(1.6, 110.0)
