# Give the component a class name so it can be instanced as a custom node
class_name ScaleComponent
extends Node

# Export the sprite that this component will be scaling
@export var sprite: Node2D

# Export the scale amount (as a vector)
@export var scale_amount = Vector2(1.5, 1.5)

# Export the scale duration
@export var scale_duration: = 0.4

var scale_tween: Tween
var base_scale: Vector2


func _ready() -> void:
	base_scale = sprite.scale

# This is the function that will activate this component
func tween_scale() -> void:
	if scale_tween != null and scale_tween.is_valid():
		scale_tween.kill()

	# We are going to scale the sprite using a tween (so we can make is smooth)
	# First we create the tween and set it's transition type and easing type
	scale_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Next we scale the sprite from its current scale to the scale amount (in 1/10th of the scale duration)
	var target_scale: Vector2 = base_scale * scale_amount
	scale_tween.tween_property(sprite, "scale", target_scale, scale_duration * 0.1).from_current()
	# Finally, return to the visual's authored scale for the rest of the duration.
	scale_tween.tween_property(sprite, "scale", base_scale, scale_duration * 0.9).from(target_scale)
