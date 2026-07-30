class_name CasterHoverComponent
extends Node

## Enter from above, then drift left/right in a top hover band. Never descends the map.

@export var actor: Node2D
@export var move_component: MoveComponent
@export_range(8.0, 200.0, 1.0) var hover_y := 56.0
@export_range(8.0, 120.0, 1.0) var enter_speed := 48.0
@export_range(8.0, 120.0, 1.0) var patrol_speed := 38.0
@export var edge_margin := 16.0

enum Phase { ENTER, PATROL }

var _phase: Phase = Phase.ENTER


func _ready() -> void:
	assert(actor != null, "CasterHoverComponent requires actor.")
	assert(move_component != null, "CasterHoverComponent requires MoveComponent.")
	move_component.velocity = Vector2(0.0, enter_speed)
	move_component.set_process(true)
	_phase = Phase.ENTER


func _process(_delta: float) -> void:
	if not is_instance_valid(actor):
		return
	match _phase:
		Phase.ENTER:
			if actor.global_position.y >= hover_y:
				actor.global_position.y = hover_y
				_begin_patrol()
		Phase.PATROL:
			actor.global_position.y = hover_y
			_bounce_horizontal()


func _begin_patrol() -> void:
	_phase = Phase.PATROL
	var lateral: float = [-patrol_speed, patrol_speed].pick_random()
	move_component.velocity = Vector2(lateral, 0.0)


func _bounce_horizontal() -> void:
	var width := actor.get_viewport_rect().size.x
	if actor.global_position.x < edge_margin:
		actor.global_position.x = edge_margin
		move_component.velocity.x = absf(patrol_speed)
	elif actor.global_position.x > width - edge_margin:
		actor.global_position.x = width - edge_margin
		move_component.velocity.x = -absf(patrol_speed)
