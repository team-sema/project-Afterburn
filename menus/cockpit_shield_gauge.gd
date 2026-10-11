extends Control
## Twelve-segment shield arc. Segments that go dark on a hit flash first:
## white for a hit the shield survived, red across the whole arc when the
## shield broke. Rules: docs/design/scene-flow.md「실드 게이지 피격 반응」.
const ON_COLOR := Color(0.28, 0.7, 0.94)
const OFF_COLOR := Color(0.06, 0.14, 0.22)
const ABSORBED_FLASH := Color(1.0, 1.0, 1.0)
const BROKEN_FLASH := Color(0.95, 0.25, 0.25)
const ABSORBED_FLASH_DURATION := 0.25
const BROKEN_FLASH_DURATION := 0.3
var _last_value := -1.0
## Segment index range [from, to) that is flashing, and what is left of it.
var _flash_from := 0
var _flash_to := 0
var _flash_color := OFF_COLOR
var _flash_duration := 0.0
var _flash_left := 0.0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
func is_flashing() -> bool:
	return _flash_left > 0.0
func get_flash_color() -> Color:
	return _flash_color
func _process(delta: float) -> void:
	var bar := get_parent().get_node("ShieldBar") as ProgressBar
	var ratio := bar.value / maxf(1.0, bar.max_value)
	if ratio != _last_value:
		if _last_value >= 0.0 and ratio < _last_value:
			_start_flash(_last_value, ratio)
		_last_value = ratio
		queue_redraw()
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		queue_redraw()
func _start_flash(previous: float, current: float) -> void:
	if current <= 0.0:
		_flash_from = 0
		_flash_to = 12
		_flash_color = BROKEN_FLASH
		_flash_duration = BROKEN_FLASH_DURATION
	else:
		_flash_from = _segments_lit(current)
		_flash_to = _segments_lit(previous)
		_flash_color = ABSORBED_FLASH
		_flash_duration = ABSORBED_FLASH_DURATION
	_flash_left = _flash_duration
func _segments_lit(ratio: float) -> int:
	var lit := 0
	for i in 12:
		if float(i) / 12.0 < ratio:
			lit += 1
	return lit
func _draw() -> void:
	var lit := _segments_lit(_last_value)
	for i in 12:
		var start := PI + float(i) / 12.0 * PI
		var end := start + PI / 12.0 * 0.78
		var color := ON_COLOR if i < lit else OFF_COLOR
		if _flash_left > 0.0 and i >= _flash_from and i < _flash_to and i >= lit:
			color = OFF_COLOR.lerp(_flash_color, _flash_left / _flash_duration)
		var points := PackedVector2Array()
		for a in [start, end]:
			points.append(Vector2(48, 16) + Vector2(cos(a) * 48, sin(a) * 14))
		for a in [end, start]:
			points.append(Vector2(48, 16) + Vector2(cos(a) * 40, sin(a) * 8))
		draw_colored_polygon(points, color)
