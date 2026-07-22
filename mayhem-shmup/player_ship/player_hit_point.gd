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


func _update_size() -> void:
	var size_ratio := radius / BASE_RADIUS
	var collision_shape := get_node_or_null("HurtboxComponent/CollisionShape2D") as CollisionShape2D
	var visual := get_node_or_null("Visual") as Node2D

	if collision_shape != null:
		collision_shape.scale = Vector2.ONE * size_ratio
	if visual != null:
		visual.scale = Vector2.ONE * size_ratio
