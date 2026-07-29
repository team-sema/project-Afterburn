class_name HexModuleFrame
extends Control

## Flat-top hexagon frame used for loadout status modules.

const BASE_LABEL_SETTINGS := preload("res://fonts/hex_module_label_settings.tres")

@export var fill_color := Color(0.05, 0.12, 0.22, 0.92)
@export var border_color := Color(0.18, 0.78, 1.0, 0.95)
@export var border_width := 2.0
@export var dimmed := false:
	set(value):
		dimmed = value
		queue_redraw()

var _title_settings: LabelSettings
var _body_settings: LabelSettings


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_settings = BASE_LABEL_SETTINGS.duplicate() as LabelSettings
	_body_settings = BASE_LABEL_SETTINGS.duplicate() as LabelSettings
	var title_label := get_node_or_null("TitleLabel") as Label
	var body_label := get_node_or_null("BodyLabel") as Label
	if title_label != null:
		title_label.label_settings = _title_settings
		title_label.clip_text = true
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if body_label != null:
		body_label.label_settings = _body_settings
		body_label.clip_text = true
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_on_resized)
	_on_resized()


func set_module_text(title: String, body: String) -> void:
	var title_label := get_node_or_null("TitleLabel") as Label
	var body_label := get_node_or_null("BodyLabel") as Label
	if title_label != null:
		title_label.text = title
	if body_label != null:
		body_label.text = body


func _on_resized() -> void:
	var title_label := get_node_or_null("TitleLabel") as Label
	var body_label := get_node_or_null("BodyLabel") as Label
	var half_w := size.x * 0.5
	var font_size := clampi(int(size.y * 0.13), 5, 9)
	if _title_settings != null:
		_title_settings.font_size = font_size
		_title_settings.line_spacing = -2.0
	if _body_settings != null:
		_body_settings.font_size = font_size
		_body_settings.line_spacing = -2.0
	if title_label != null:
		var title_h := maxf(10.0, size.y * 0.2)
		var inset := maxf(3.0, size.x * 0.12)
		title_label.offset_left = -half_w + inset
		title_label.offset_right = half_w - inset
		title_label.offset_top = size.y * 0.12
		title_label.offset_bottom = title_label.offset_top + title_h
	if body_label != null:
		var inset := maxf(4.0, size.x * 0.14)
		var body_half_h := size.y * 0.2
		body_label.offset_left = -half_w + inset
		body_label.offset_right = half_w - inset
		body_label.offset_top = -body_half_h + size.y * 0.04
		body_label.offset_bottom = body_half_h + size.y * 0.08
	queue_redraw()


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
