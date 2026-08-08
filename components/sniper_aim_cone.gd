class_name SniperAimCone
extends Node2D

## Aim telegraph only — red shrinking cone, no bright center line.
## Scene child of the sniper (BombBlastPreview pattern).

@export var half_angle_degrees := 42.0
@export var cone_length := 420.0
@export var fill_color := Color(1.0, 0.1, 0.05, 0.16)
@export var edge_color := Color(1.0, 0.4, 0.2, 0.55)
@export_range(0.5, 4.0, 0.25) var edge_width := 1.5


func _ready() -> void:
	z_index = 10
	visible = false
	queue_redraw()


func set_half_angle_degrees(value: float) -> void:
	half_angle_degrees = maxf(0.05, value)
	queue_redraw()


func set_cone_length(value: float) -> void:
	cone_length = maxf(1.0, value)
	queue_redraw()


func show_telegraph() -> void:
	visible = true
	queue_redraw()


func hide_telegraph() -> void:
	visible = false


func _draw() -> void:
	if not visible or cone_length <= 0.0:
		return
	var half := deg_to_rad(half_angle_degrees)
	var tip := Vector2.ZERO
	var left := Vector2(-sin(half), cos(half)) * cone_length
	var right := Vector2(sin(half), cos(half)) * cone_length

	draw_colored_polygon(PackedVector2Array([tip, left, right]), fill_color)
	draw_line(tip, left, edge_color, edge_width, true)
	draw_line(tip, right, edge_color, edge_width, true)
	draw_arc(tip, cone_length, PI * 0.5 - half, PI * 0.5 + half, 28, edge_color, edge_width, true)
