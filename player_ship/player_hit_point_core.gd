@tool
class_name PlayerHitPointCore
extends Node2D

## Hard-edged marker for the player's hit point.
##
## The outer edge of the marker sits exactly at the hurtbox radius so it shows
## the judgement area and nothing more; the dark outline is drawn inside that
## edge and gives the eye a fixed ring to lock onto. A soft glow blob has no
## edge, so sub-pixel resampling while the ship moves makes its centre appear
## to drift; a crisp ring does not.

## Outer radius of the marker; keep it equal to the hurtbox radius.
@export_range(0.5, 16.0, 0.25, "suffix:px") var radius := 3.0:
	set(value):
		radius = maxf(value, 0.5)
		queue_redraw()

## Width of the dark ring drawn inside [member radius]; 0 hides it.
@export_range(0.0, 4.0, 0.25, "suffix:px") var outline_width := 1.0:
	set(value):
		outline_width = maxf(value, 0.0)
		queue_redraw()

@export var outline_color := Color(0.12, 0.02, 0.05, 0.95):
	set(value):
		outline_color = value
		queue_redraw()

@export var fill_color := Color(0.98, 0.23, 0.26, 1.0):
	set(value):
		fill_color = value
		queue_redraw()

@export var center_color := Color(1.0, 0.96, 0.94, 1.0):
	set(value):
		center_color = value
		queue_redraw()

## Radius of the bright centre dot as a fraction of [member radius]; 0 hides it.
@export_range(0.0, 1.0, 0.05) var center_ratio := 0.45:
	set(value):
		center_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var fill_radius := radius
	if outline_width > 0.0:
		draw_circle(Vector2.ZERO, radius, outline_color, true, -1.0, true)
		fill_radius = maxf(radius - outline_width, 0.0)
	if fill_radius > 0.0:
		draw_circle(Vector2.ZERO, fill_radius, fill_color, true, -1.0, true)
	if center_ratio > 0.0:
		draw_circle(Vector2.ZERO, minf(radius * center_ratio, fill_radius), center_color, true, -1.0, true)
