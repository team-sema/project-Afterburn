class_name SniperAimCone
extends Node2D

## Aim telegraph only — two faint red guide lines that close onto the shot path.
## Scene child of the sniper (BombBlastPreview pattern).

@export var half_angle_degrees := 14.0
@export var cone_length := 420.0
@export var line_color := Color(1.0, 0.18, 0.16, 1.0)
@export_range(0.0, 1.0, 0.005) var start_alpha := 0.01
@export_range(0.0, 1.0, 0.01) var focused_alpha := 0.36
@export_range(0.25, 3.0, 0.25) var line_width := 0.5

var _focus_progress := 0.0


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


func set_focus_progress(value: float) -> void:
	_focus_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func get_line_alpha() -> float:
	return lerpf(start_alpha, focused_alpha, _focus_progress)


func show_telegraph() -> void:
	visible = true
	queue_redraw()


func hide_telegraph() -> void:
	visible = false


func _draw() -> void:
	if not visible or cone_length <= 0.0:
		return
	var half := deg_to_rad(half_angle_degrees)
	var left := Vector2(-sin(half), cos(half)) * cone_length
	var right := Vector2(sin(half), cos(half)) * cone_length
	var current_color := line_color
	current_color.a = get_line_alpha()

	draw_line(Vector2.ZERO, left, current_color, line_width, true)
	draw_line(Vector2.ZERO, right, current_color, line_width, true)
