class_name HexHoneycombContainer
extends Container

const HEX_HALF_HEIGHT_RATIO := 0.866025
const FRAME_INSET := 3.0

@export_range(12.0, 96.0, 1.0) var hex_side := 28.0:
	set(value):
		hex_side = value
		update_minimum_size()
		queue_sort()


func _get_minimum_size() -> Vector2:
	var count := _visible_child_count()
	if count <= 0:
		return Vector2.ZERO
	var diameter := maxf(4.0, hex_side - FRAME_INSET * 2.0)
	var horizontal_step := diameter * 0.75
	var vertical_stagger := diameter * HEX_HALF_HEIGHT_RATIO * 0.5
	return Vector2(
		hex_side + horizontal_step * float(count - 1),
		hex_side + (vertical_stagger if count > 1 else 0.0),
	)


func get_horizontal_step() -> float:
	return maxf(4.0, hex_side - FRAME_INSET * 2.0) * 0.75


func get_vertical_stagger() -> float:
	return maxf(4.0, hex_side - FRAME_INSET * 2.0) * HEX_HALF_HEIGHT_RATIO * 0.5


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var content_size := _get_minimum_size()
	var origin := (size - content_size) * 0.5
	var visible_index := 0
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var child_position := origin + Vector2(
			get_horizontal_step() * visible_index,
			get_vertical_stagger() if visible_index % 2 == 1 else 0.0,
		)
		fit_child_in_rect(control, Rect2(child_position, Vector2(hex_side, hex_side)))
		visible_index += 1


func _visible_child_count() -> int:
	var count := 0
	for child in get_children():
		var control := child as Control
		if control != null and control.visible:
			count += 1
	return count
