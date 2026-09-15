class_name ThreatHistoryGraph
extends Control

var values := PackedFloat32Array()


func set_values(new_values: PackedFloat32Array) -> void:
	values = new_values
	queue_redraw()


func _draw() -> void:
	var chart_rect := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
	var grid_color := Color(0.2, 0.45, 0.62, 0.28)
	var line_color := Color(1.0, 0.25, 0.52, 0.95)
	for index in 5:
		var ratio := float(index) / 4.0
		var y := lerpf(chart_rect.position.y, chart_rect.end.y, ratio)
		draw_line(Vector2(chart_rect.position.x, y), Vector2(chart_rect.end.x, y), grid_color, 1.0)
	if values.size() < 2:
		return
	var points := PackedVector2Array()
	for index in values.size():
		var x_ratio := float(index) / float(values.size() - 1)
		var y_ratio := clampf(values[index] / 100.0, 0.0, 1.0)
		points.append(Vector2(
			lerpf(chart_rect.position.x, chart_rect.end.x, x_ratio),
			lerpf(chart_rect.end.y, chart_rect.position.y, y_ratio),
		))
	draw_polyline(points, line_color, 2.0, true)
