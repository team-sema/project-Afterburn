# Give the component a class name so it can be instanced as a custom node
class_name PositionClampComponent
extends Node2D

# Export the actor who's position will be clamped
@export var actor: Node2D

# Export a margin for left and right (margin.x) and top and bottom (margin.y)
@export var margin: = 8

func _process(_delta: float) -> void:
	var viewport_size := actor.get_viewport_rect().size
	actor.global_position = actor.global_position.clamp(
		Vector2.ONE * margin,
		viewport_size - Vector2.ONE * margin
	)
