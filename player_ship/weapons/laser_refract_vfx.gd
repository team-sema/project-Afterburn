class_name LaserRefractVfx
extends Node2D

## Draws short-lived, world-anchored secondary beam segments without creating
## new nodes for every laser damage tick.

@export_range(0.01, 1.0, 0.01) var segment_lifetime := 0.13
@export_range(0.1, 20.0, 0.1) var glow_width := 6.0
@export_range(0.1, 10.0, 0.1) var core_width := 1.25
@export var glow_color := Color(0.1, 0.78, 1.0, 0.34)
@export var core_color := Color(0.86, 0.98, 1.0, 0.96)
@export_range(0.1, 12.0, 0.1) var impact_radius := 2.2

var _segments: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)


func flash_segment(from_global: Vector2, target_global: Vector2) -> bool:
	if from_global.distance_squared_to(target_global) <= 0.01:
		return false
	_segments.append({
		"from_global": from_global,
		"to_global": target_global,
		"remaining": segment_lifetime,
	})
	set_process(true)
	queue_redraw()
	return true


func clear_segments() -> void:
	_segments.clear()
	set_process(false)
	queue_redraw()


func get_active_segment_count() -> int:
	return _segments.size()


func _process(delta: float) -> void:
	for index in range(_segments.size() - 1, -1, -1):
		var remaining := float(_segments[index].get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			_segments.remove_at(index)
			continue
		_segments[index]["remaining"] = remaining
	if _segments.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var lifetime := maxf(segment_lifetime, 0.001)
	for segment in _segments:
		var from_local := to_local(segment.get("from_global", global_position))
		var to_local_point := to_local(segment.get("to_global", global_position))
		var intensity := clampf(float(segment.get("remaining", 0.0)) / lifetime, 0.0, 1.0)
		intensity *= intensity

		var faded_glow := glow_color
		faded_glow.a *= intensity
		draw_line(from_local, to_local_point, faded_glow, glow_width, true)
		draw_circle(to_local_point, impact_radius * 1.8, faded_glow, true, -1.0, true)

		var faded_core := core_color
		faded_core.a *= intensity
		draw_line(from_local, to_local_point, faded_core, core_width, true)
		draw_circle(to_local_point, impact_radius, faded_core, true, -1.0, true)
