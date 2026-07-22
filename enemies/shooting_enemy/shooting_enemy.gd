class_name PinkEnemy
extends Enemy

@onready var state_machine: StateMachineComponent = %StateMachine

@onready var move_down_state: TimedStateComponent = %MoveDownState
@onready var move_side_state: TimedStateComponent = %MoveSideState
@onready var pause_state: TimedStateComponent = %PauseState

@onready var projectile_spawner_component: SpawnerComponent = %ProjectileSpawnerComponent


func _ready() -> void:
	super()

	move_down_state.state_finished.connect(
		state_machine.change_state.bind(move_side_state)
	)
	move_side_state.state_finished.connect(_on_move_side_state_finished)
	pause_state.state_finished.connect(
		state_machine.change_state.bind(move_down_state)
	)

	state_machine.start(move_down_state)


func _on_move_side_state_finished() -> void:
	state_machine.change_state(pause_state)
	fire()


func fire() -> void:
	scale_component.tween_scale()
	projectile_spawner_component.spawn(global_position)
