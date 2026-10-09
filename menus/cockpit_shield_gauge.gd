extends Control
var _last_value := -1.0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	var bar := get_parent().get_node("ShieldBar") as ProgressBar
	var ratio := bar.value / maxf(1.0, bar.max_value)
	if ratio != _last_value:
		_last_value = ratio
		queue_redraw()
func _draw() -> void:
	for i in 12:
		var start := PI + float(i) / 12.0 * PI
		var end := start + PI / 12.0 * 0.78
		var color := Color(0.28, 0.7, 0.94) if float(i) / 12.0 < _last_value else Color(0.06, 0.14, 0.22)
		var points := PackedVector2Array()
		for a in [start, end]:
			points.append(Vector2(48, 16) + Vector2(cos(a) * 48, sin(a) * 14))
		for a in [end, start]:
			points.append(Vector2(48, 16) + Vector2(cos(a) * 40, sin(a) * 8))
		draw_colored_polygon(points, color)
