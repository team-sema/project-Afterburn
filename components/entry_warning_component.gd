class_name EntryWarningComponent
extends DangerIndicator
## Places a shared danger indicator at the actor's entry edge.
@export var actor: Node2D
@export var entry_direction := Vector2.DOWN
@export_range(0.0, 32.0, 1.0, "suffix:px") var edge_inset := 4.0

func _ready() -> void:
	super._ready()
	assert(actor != null, "EntryWarningComponent requires an actor.")
	assert(not entry_direction.is_zero_approx(), "EntryWarningComponent requires entry_direction.")
	top_level = true
	_refresh_edge_marker.call_deferred()

func _refresh_edge_marker() -> void:
	if not is_instance_valid(actor):
		queue_free()
		return
	_update_edge_transform()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		queue_free()
		return
	super._process(delta)
	if is_warning_active(): _update_edge_transform()

func _update_edge_transform() -> void:
	inward_direction = entry_direction.normalized()
	global_position = _find_forward_rect_entry(actor.global_position, inward_direction, actor.get_viewport_rect())
	global_position += inward_direction * edge_inset
	global_rotation = 0.0


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
