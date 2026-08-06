class_name BombBlastPreview
extends Node2D

@export var radius := 1.0
@export var fill_color := Color(1.0, 0.12, 0.08, 0.07)
@export var outline_color := Color(1.0, 0.22, 0.14, 0.24)
@export_range(0.5, 4.0, 0.5) var outline_width := 1.0


func set_preview_radius(value: float) -> void:
	radius = maxf(0.0, value)
	queue_redraw()


func _draw() -> void:
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, outline_color, outline_width, true)
