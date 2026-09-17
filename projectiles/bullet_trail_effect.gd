class_name BulletTrailEffect
extends Resource
## Optional visual effect. Sizes are in pixels; spacing is distance, not FPS.
@export var texture: Texture2D
@export var spacing := 2.0
@export var lifetime := 0.22
@export var size := 0.8
@export var end_size := 0.1
@export var speed_min := 8.0
@export var speed_max := 14.0
@export var spread_degrees := 6.0
@export var color := Color(1, 0.18, 0.58, 0.65)
@export var end_color := Color(0.65, 0.04, 0.3, 0)

func is_valid() -> bool:
	return texture != null and is_finite(spacing) and spacing >= 0.25 and is_finite(lifetime) and lifetime > 0 and lifetime <= 5 and is_finite(size) and size > 0 and size <= 128 and is_finite(end_size) and end_size >= 0 and end_size <= 128 and is_finite(speed_min) and is_finite(speed_max) and speed_min >= 0 and speed_max >= speed_min and speed_max <= 1000 and is_finite(spread_degrees) and spread_degrees >= 0 and spread_degrees <= 180 and _finite_color(color) and _finite_color(end_color)

func _finite_color(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
