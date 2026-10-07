@tool
class_name PlayerHitPoint
extends Node2D

const BASE_RADIUS := 3.0

@export_range(0.5, 16.0, 0.25, "suffix:px") var radius := BASE_RADIUS:
	set(value):
		radius = maxf(value, 0.5)
		_update_size()


func _ready() -> void:
	_update_size()


## Scales the hurtbox and the glow layers by the radius ratio. The drawn core
## marker is redrawn at the new radius instead, with the parent scale cancelled,
## so its outline stays one pixel wide at any radius.
func _update_size() -> void:
	var size_ratio := radius / BASE_RADIUS
	var collision_shape := get_node_or_null("HurtboxComponent/CollisionShape2D") as CollisionShape2D
	var visual := get_node_or_null("Visual") as Node2D
	var core := get_node_or_null("Visual/Core") as PlayerHitPointCore

	if collision_shape != null:
		collision_shape.scale = Vector2.ONE * size_ratio
	if visual != null:
		visual.scale = Vector2.ONE * size_ratio
	if core != null:
		core.scale = Vector2.ONE / size_ratio
		core.radius = radius
