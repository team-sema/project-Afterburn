class_name EntryWarningComponent
extends Node2D

## Minimal edge telegraph for a fast offscreen entry. The marker is rendered at
## the first VisibleRect boundary crossed by entry_direction and never moves the actor.

@export var actor: Node2D
@export var entry_direction := Vector2.DOWN
@export_range(0.1, 3.0, 0.05, "suffix:s") var warning_duration := 0.55
@export_range(0.0, 32.0, 1.0, "suffix:px") var edge_inset := 9.0
@export var warning_color := Color(1.0, 0.32, 0.12, 0.95)

var _elapsed := 0.0
var _active := true


func _ready() -> void:
	assert(actor != null, "EntryWarningComponent requires an actor.")
	assert(not entry_direction.is_zero_approx(), "EntryWarningComponent requires entry_direction.")
	top_level = true
	z_index = 100
	_update_edge_transform()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active or actor == null or not is_instance_valid(actor):
		return
	_elapsed += delta
	if _elapsed >= warning_duration:
		_active = false
		hide()
		queue_free()
		return
	_update_edge_transform()
	# A hard neon blink reads clearly without suggesting sine-wave motion.
	modulate.a = 1.0 if int(_elapsed * 10.0) % 2 == 0 else 0.38


func is_warning_active() -> bool:
	return _active


func _draw() -> void:
	var chevron := PackedVector2Array([
		Vector2(-9.0, -5.0),
		Vector2.ZERO,
		Vector2(9.0, -5.0),
	])
	draw_polyline(chevron, warning_color, 2.5, true)
	draw_line(Vector2(0.0, -12.0), Vector2.ZERO, warning_color, 2.0, true)
	draw_circle(Vector2(0.0, -15.0), 1.75, warning_color)


func _update_edge_transform() -> void:
	var direction := entry_direction.normalized()
	var visible_rect := actor.get_viewport_rect()
	global_position = _find_forward_rect_entry(actor.global_position, direction, visible_rect)
	global_position += direction * edge_inset
	global_rotation = direction.angle() - Vector2.DOWN.angle()


func _find_forward_rect_entry(origin: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	if rect.has_point(origin):
		return Vector2(
			clampf(origin.x, rect.position.x, rect.end.x),
			clampf(origin.y, rect.position.y, rect.end.y),
		)
	var best_time := INF
	var best_point := rect.get_center()
	if not is_zero_approx(direction.x):
		for boundary_value in [rect.position.x, rect.end.x]:
			var boundary_x := float(boundary_value)
			var time_x: float = (boundary_x - origin.x) / direction.x
			var candidate_y: float = origin.y + direction.y * time_x
			if (
				time_x >= 0.0
				and time_x < best_time
				and candidate_y >= rect.position.y
				and candidate_y <= rect.end.y
			):
				best_time = time_x
				best_point = Vector2(boundary_x, candidate_y)
	if not is_zero_approx(direction.y):
		for boundary_value in [rect.position.y, rect.end.y]:
			var boundary_y := float(boundary_value)
			var time_y: float = (boundary_y - origin.y) / direction.y
			var candidate_x: float = origin.x + direction.x * time_y
			if (
				time_y >= 0.0
				and time_y < best_time
				and candidate_x >= rect.position.x
				and candidate_x <= rect.end.x
			):
				best_time = time_y
				best_point = Vector2(candidate_x, boundary_y)
	return best_point
