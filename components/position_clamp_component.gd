# Give the component a class name so it can be instanced as a custom node
class_name PositionClampComponent
extends Node2D

# Export the actor who's position will be clamped
@export var actor: Node2D

# Export a margin for left and right (margin.x) and top and bottom (margin.y)
@export var margin: = 8

# Define the viewport borders used to keep the actor on screen.
var left_border = 0
var top_border = 0
var right_border = ProjectSettings.get_setting("display/window/size/viewport_width")
var bottom_border = ProjectSettings.get_setting("display/window/size/viewport_height")

func _process(_delta: float) -> void:
	actor.global_position = actor.global_position.clamp(
		Vector2(left_border + margin, top_border + margin),
		Vector2(right_border - margin, bottom_border - margin)
	)
