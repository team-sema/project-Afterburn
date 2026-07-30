class_name StrikerDivePatrolComponent
extends Node

## Descend straight down from spawn, stop near mid-screen, then patrol left/right.
## MoveComponent remains the sole position writer via velocity.

@export var actor: Node2D
@export var move_component: MoveComponent
@export_range(1.0, 200.0, 1.0) var descend_speed := 40.0
@export_range(1.0, 200.0, 1.0) var patrol_speed := 55.0
## Fraction of viewport height where vertical descent stops (0.5 ≈ center).
@export_range(0.2, 0.85, 0.01) var stop_viewport_y_ratio := 0.5

enum Phase { DESCEND, PATROL }

var _phase: Phase = Phase.DESCEND


func _ready() -> void:
	assert(actor != null, "StrikerDivePatrolComponent requires actor.")
	assert(move_component != null, "StrikerDivePatrolComponent requires MoveComponent.")
	_begin_descend()


func _process(_delta: float) -> void:
	if _phase != Phase.DESCEND:
		return
	if not is_instance_valid(actor):
		return
	var stop_y := actor.get_viewport_rect().size.y * stop_viewport_y_ratio
	if actor.global_position.y >= stop_y:
		_begin_patrol()


func _begin_descend() -> void:
	_phase = Phase.DESCEND
	move_component.velocity = Vector2(0.0, descend_speed)
	move_component.set_process(true)


func _begin_patrol() -> void:
	_phase = Phase.PATROL
	var lateral: float = [-patrol_speed, patrol_speed].pick_random()
	move_component.velocity = Vector2(lateral, 0.0)
