class_name UniversalModuleSlotRack
extends Control

signal slot_hovered(slot_index: int)
signal slot_hover_exited

const COLUMN_COUNT := 5
const ROW_COUNT := 3
const SLOT_WIDTH := 28.0
const SLOT_HEIGHT := SLOT_WIDTH * 0.866025
const COLUMN_STEP := SLOT_WIDTH * 0.75
const GRID_WIDTH := SLOT_WIDTH + COLUMN_STEP * (COLUMN_COUNT - 1)
const GRID_HEIGHT := SLOT_HEIGHT * (ROW_COUNT + 0.5)
const BORDER_EMPTY := Color(0.25, 0.62, 0.82, 0.95)
const BORDER_FILLED := Color(0.72, 0.96, 1.0, 1.0)
const BORDER_HIGHLIGHT := Color(0.95, 1.0, 0.72, 1.0)
const FILL_EMPTY := Color(0.01, 0.035, 0.07, 0.98)
const FILL_FILLED := Color(0.08, 0.32, 0.45, 0.98)
const PREVIEW_COLOR := Color(0.38, 0.94, 1.0, 1.0)
const ICON_COLOR := Color(0.88, 0.98, 1.0, 1.0)

var _registry: PlayerAugmentRegistry
var _slots: Array = []
var _highlighted_tag: StringName = &""
var _expansion_preview := false
var _preview_alpha := 0.35
var _preview_tween: Tween
var _hovered_slot := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	mouse_exited.connect(_on_mouse_exited)


func set_registry(registry: PlayerAugmentRegistry) -> void:
	_registry = registry
	_refresh_tooltip()
	queue_redraw()


func set_slots(slots: Array) -> void:
	_slots = slots.duplicate()
	if _slots.size() >= PlayerAugmentRegistry.MAX_SLOT_CAPACITY:
		set_expansion_preview(false)
	_refresh_tooltip()
	queue_redraw()


func set_highlighted_tag(tag: StringName) -> void:
	_highlighted_tag = tag
	queue_redraw()


func set_expansion_preview(enabled: bool) -> void:
	enabled = enabled and _slots.size() < PlayerAugmentRegistry.MAX_SLOT_CAPACITY
	if _expansion_preview == enabled:
		return
	_expansion_preview = enabled
	if _preview_tween != null:
		_preview_tween.kill()
		_preview_tween = null
	_preview_alpha = 0.35
	if enabled:
		_preview_tween = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_preview_tween.tween_method(_set_preview_alpha, 0.35, 1.0, 0.45)
		_preview_tween.tween_method(_set_preview_alpha, 1.0, 0.35, 0.45)
	queue_redraw()


func has_expansion_preview() -> bool:
	return _expansion_preview


func get_preview_alpha() -> float:
	return _preview_alpha


func get_visible_slot_count() -> int:
	return _slots.size() + (1 if _expansion_preview else 0)


func get_slot_icon(index: int) -> Texture2D:
	if index < 0 or index >= _slots.size():
		return null
	var state := _slots[index] as PlayerAugmentModuleState
	if state == null:
		return null
	if _registry != null:
		var definition := _registry.get_facility_definition(state.augment.get_primary_module_tag())
		if definition != null and definition.icon != null:
			return definition.icon
	return state.augment.icon


func get_slot_rect(index: int) -> Rect2:
	var polygon := get_slot_polygon(index)
	if polygon.is_empty():
		return Rect2()
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func get_slot_polygon(index: int) -> PackedVector2Array:
	if index < 0 or index >= get_visible_slot_count():
		return PackedVector2Array()
	var row := floori(float(index) / float(COLUMN_COUNT))
	var column := index % COLUMN_COUNT
	var origin := Vector2(
		(size.x - GRID_WIDTH) * 0.5 + column * COLUMN_STEP,
		(size.y - GRID_HEIGHT) * 0.5 + row * SLOT_HEIGHT + (SLOT_HEIGHT * 0.5 if column % 2 == 1 else 0.0),
	)
	return PackedVector2Array([
		origin + Vector2(SLOT_WIDTH * 0.25, 0.0),
		origin + Vector2(SLOT_WIDTH * 0.75, 0.0),
		origin + Vector2(SLOT_WIDTH, SLOT_HEIGHT * 0.5),
		origin + Vector2(SLOT_WIDTH * 0.75, SLOT_HEIGHT),
		origin + Vector2(SLOT_WIDTH * 0.25, SLOT_HEIGHT),
		origin + Vector2(0.0, SLOT_HEIGHT * 0.5),
	])


func _draw() -> void:
	for index in get_visible_slot_count():
		var is_preview := index >= _slots.size()
		var state: PlayerAugmentModuleState = null
		if not is_preview:
			state = _slots[index] as PlayerAugmentModuleState
		var fill_color := FILL_EMPTY
		var border_color := BORDER_EMPTY
		if is_preview:
			fill_color = Color(PREVIEW_COLOR, _preview_alpha * 0.24)
			border_color = Color(PREVIEW_COLOR, _preview_alpha)
		elif state != null:
			fill_color = FILL_FILLED
			border_color = (
				BORDER_HIGHLIGHT
				if state.augment.has_module_tag(_highlighted_tag)
				else BORDER_FILLED
			)
		var polygon := get_slot_polygon(index)
		draw_colored_polygon(polygon, fill_color)
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, border_color, 1.25, true)
		var center := get_slot_rect(index).get_center()
		if is_preview:
			draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), border_color, 1.25)
			draw_line(center + Vector2(0.0, -3.0), center + Vector2(0.0, 3.0), border_color, 1.25)
			continue
		var icon := get_slot_icon(index)
		if icon != null:
			draw_texture_rect(icon, Rect2(center - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), false, ICON_COLOR)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	var next_hovered := _slot_at_position(motion.position)
	if next_hovered == _hovered_slot:
		return
	_hovered_slot = next_hovered
	if _hovered_slot >= 0 and _hovered_slot < _slots.size():
		slot_hovered.emit(_hovered_slot)
	else:
		slot_hover_exited.emit()


func _slot_at_position(local_position: Vector2) -> int:
	for index in get_visible_slot_count():
		if Geometry2D.is_point_in_polygon(local_position, get_slot_polygon(index)):
			return index
	return -1


func _on_mouse_exited() -> void:
	if _hovered_slot < 0:
		return
	_hovered_slot = -1
	slot_hover_exited.emit()


func _set_preview_alpha(alpha: float) -> void:
	_preview_alpha = alpha
	queue_redraw()


func _refresh_tooltip() -> void:
	var lines := PackedStringArray(["범용 모듈 슬롯 %d칸" % _slots.size()])
	for index in _slots.size():
		var state := _slots[index] as PlayerAugmentModuleState
		if state == null:
			lines.append("%d. 빈 슬롯" % (index + 1))
			continue
		var tag_name := String(state.augment.get_primary_module_tag())
		if _registry != null:
			var definition := _registry.get_facility_definition(state.augment.get_primary_module_tag())
			if definition != null:
				tag_name = definition.display_name
		lines.append("%d. %s · %s" % [index + 1, tag_name, state.augment.display_name])
	tooltip_text = "\n".join(lines)
