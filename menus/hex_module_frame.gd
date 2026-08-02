class_name HexModuleFrame
extends Control

## Flat-top hexagon frame used for loadout status modules.

const BASE_LABEL_SETTINGS := preload("res://fonts/hex_module_label_settings.tres")
## Flat-top hexagon: half-height and side slope relative to the drawn radius.
const HEX_HALF_HEIGHT_RATIO := 0.866025
const HEX_EDGE_SLOPE := 0.577350

@export var fill_color := Color(0.05, 0.12, 0.22, 0.92)
@export var border_color := Color(0.18, 0.78, 1.0, 0.95)
@export var border_width := 2.0
@export var icon_color := Color(0.88, 0.98, 1.0, 1.0):
	set(value):
		icon_color = value
		_apply_icon_modulate()
@export var dimmed := false:
	set(value):
		dimmed = value
		_apply_icon_modulate()
		queue_redraw()

var _title_settings: LabelSettings
var _body_settings: LabelSettings


@export var interactive := false:
	set(value):
		interactive = value
		mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE

signal module_hovered
signal module_clicked


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_title_settings = BASE_LABEL_SETTINGS.duplicate() as LabelSettings
	_body_settings = BASE_LABEL_SETTINGS.duplicate() as LabelSettings
	var title_label := _get_title_label()
	var body_label := _get_body_label()
	var icon_rect := _get_icon_rect()
	if title_label != null:
		title_label.label_settings = _title_settings
		title_label.clip_text = true
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_label != null:
		body_label.label_settings = _body_settings
		body_label.clip_text = true
		body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		body_label.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_rect != null:
		icon_rect.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_icon_modulate()
	resized.connect(_on_resized)
	_layout_children()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			module_clicked.emit()
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER and interactive:
		module_hovered.emit()


func set_module_text(title: String, body: String) -> void:
	var title_label := _get_title_label()
	var body_label := _get_body_label()
	if title_label != null:
		title_label.text = title
	if body_label != null:
		body_label.text = body
	_layout_children()


## The icon carries the weapon identity; pass null for empty or locked modules.
func set_module_icon(icon: Texture2D) -> void:
	var icon_rect := _get_icon_rect()
	if icon_rect == null:
		return
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	_layout_children()


func _on_resized() -> void:
	_layout_children()


func _layout_children() -> void:
	var title_font_size := clampi(int(size.y * 0.13), 5, 9)
	var body_font_size := clampi(int(size.y * 0.2), 8, 11)
	if _title_settings != null:
		_title_settings.font_size = title_font_size
		_title_settings.line_spacing = -2.0
	if _body_settings != null:
		_body_settings.font_size = body_font_size
		_body_settings.line_spacing = -2.0
		_body_settings.outline_size = 1
		_body_settings.outline_color = Color(0.01, 0.04, 0.08, 0.95)

	var band_height := maxf(10.0, size.y * 0.2)
	var content_top := size.y * 0.11
	var content_bottom := size.y * 0.89
	var icon_top := content_top
	var icon_bottom := content_bottom

	var title_label := _get_title_label()
	if title_label != null:
		_place_text_band(title_label, content_top, content_top + band_height)
		if not title_label.text.is_empty():
			icon_top = content_top + band_height
	var body_label := _get_body_label()
	if body_label != null:
		_place_text_band(body_label, content_bottom - band_height, content_bottom)
		if not body_label.text.is_empty():
			icon_bottom = content_bottom - band_height
	var icon_rect := _get_icon_rect()
	if icon_rect != null:
		if (
			icon_rect.visible
			and title_label != null
			and not title_label.text.is_empty()
			and (body_label == null or body_label.text.is_empty())
		):
			icon_bottom = content_bottom - band_height
		_place_icon(icon_rect, icon_top, icon_bottom)
	queue_redraw()


## Measure the hexagon at the band edge nearest the middle, where the label is widest.
func _place_text_band(label: Label, top: float, bottom: float) -> void:
	var center := size.y * 0.5
	var measured := minf(absf(top - center), absf(bottom - center))
	var half_width := maxf(4.0, _hex_half_width_at(measured) - border_width)
	label.offset_left = size.x * 0.5 - half_width
	label.offset_right = size.x * 0.5 + half_width
	label.offset_top = top
	label.offset_bottom = maxf(top + 1.0, bottom)


## Icons keep their aspect ratio, so reserve the largest centered square whose corners
## stay inside the slanted sides instead of the full band width.
func _place_icon(icon_rect: TextureRect, top: float, bottom: float) -> void:
	var band_center := (top + bottom) * 0.5
	var distance := absf(band_center - size.y * 0.5)
	var radius := minf(size.x, size.y) * 0.48 - border_width
	var half := (radius - HEX_EDGE_SLOPE * distance) / (1.0 + HEX_EDGE_SLOPE)
	half = maxf(2.0, minf(half, (bottom - top) * 0.5))
	icon_rect.offset_left = size.x * 0.5 - half
	icon_rect.offset_right = size.x * 0.5 + half
	icon_rect.offset_top = band_center - half
	icon_rect.offset_bottom = band_center + half


func _hex_half_width_at(offset_y: float) -> float:
	var radius := minf(size.x, size.y) * 0.48
	if absf(offset_y) >= radius * HEX_HALF_HEIGHT_RATIO:
		return 0.0
	return radius - HEX_EDGE_SLOPE * absf(offset_y)


func _apply_icon_modulate() -> void:
	var icon_rect := _get_icon_rect()
	if icon_rect == null:
		return
	if dimmed:
		icon_rect.modulate = Color(
			icon_color.r * 0.55,
			icon_color.g * 0.62,
			icon_color.b * 0.68,
			icon_color.a * 0.45,
		)
		return
	icon_rect.modulate = icon_color


func _get_title_label() -> Label:
	return get_node_or_null("TitleLabel") as Label


func _get_body_label() -> Label:
	return get_node_or_null("BodyLabel") as Label


func _get_icon_rect() -> TextureRect:
	return get_node_or_null("IconRect") as TextureRect


func _draw() -> void:
	var hex := _hex_points(size)
	if hex.size() < 6:
		return
	var fill := fill_color
	var border := border_color
	if dimmed:
		fill = Color(fill.r, fill.g, fill.b, fill.a * 0.45)
		border = Color(border.r, border.g, border.b, border.a * 0.4)
	draw_colored_polygon(hex, fill)
	for index in 6:
		var a := hex[index]
		var b := hex[(index + 1) % 6]
		draw_line(a, b, border, border_width, true)


func _hex_points(rect_size: Vector2) -> PackedVector2Array:
	var radius := minf(rect_size.x, rect_size.y) * 0.48
	if radius < 4.0:
		return PackedVector2Array()
	var center := rect_size * 0.5
	var points := PackedVector2Array()
	# Flat-top hexagon.
	for index in 6:
		var angle := TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
