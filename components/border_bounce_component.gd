# Give the component a class name so it can be instanced as a custom node
class_name BorderBounceComponent
extends Node

# The margin is used to allow actors to bounce before reaching the edge of the border
@export var margin: = 8

# Export the actor that this component will operate on
@export var actor: Node2D

# We need to grab the move component of the actor in order to change its velocity when bouncing
@export var move_component: MoveComponent

func _process(_delta: float) -> void:
	var right_border := actor.get_viewport_rect().size.x
	var offset_x := 0.0
	var modifier := move_component.get_modifier_component()
	if modifier != null:
		offset_x = modifier.get_offset().x
	var base_x := actor.global_position.x - offset_x
	# If the actor's x position is less than the left border plus the margin,
	# bounce off the left side of the screen
	if base_x < margin:
		# Prevent the actor for going past the border + the margin
		actor.global_position.x = margin + offset_x
		# When bouncing we use the .bounce function which takes a wall normal
		# This wall normal is the direction of the face of the wall
		# (it's a bit counter intuitive but a wall on the left would have a wall face with a normal of RIGHT)
		move_component.velocity = move_component.velocity.bounce(Vector2.RIGHT)
	# If the actor's x position is greater than the right border plus the margin,
	# bounce off the right side of the screen
	elif base_x > right_border - margin:
		# Prevent the actor for going past the border + the margin
		actor.global_position.x = right_border - margin + offset_x
		# When bouncing we use the .bounce function which takes a wall normal
		# This wall normal is the direction of the face of the wall
		# (it's a bit counter intuitive but a wall on the right would have a wall face with a normal of LEFT)
		move_component.velocity = move_component.velocity.bounce(Vector2.LEFT)
	
