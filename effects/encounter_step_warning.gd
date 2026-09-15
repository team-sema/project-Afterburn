class_name EncounterStepWarning
extends Node2D

## WAVE / ELITE / BOSS 직전 맵 중앙에 "WARNING" 텍스트 점멸.

signal finished

@export_range(0.2, 3.0, 0.05, "suffix:s") var warning_duration := 0.8
@export var warning_color := Color(1.0, 0.16, 0.12, 0.95)

var _elapsed := 0.0
var _active := true


static func present(
	host: Node,
	_kind: EncounterSequenceStep.Kind,
	duration := 0.8,
) -> EncounterStepWarning:
	assert(host != null, "EncounterStepWarning requires a host node.")
	var warning := EncounterStepWarning.new()
	warning.warning_duration = duration
	warning.warning_color = Color(1.0, 0.16, 0.12, 0.95)
	warning.z_index = 120
	warning.top_level = true
	host.add_child(warning)
	warning._pin_to_viewport_center()
	return warning


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= warning_duration:
		_active = false
		hide()
		finished.emit()
		queue_free()
		return
	_pin_to_viewport_center()
	modulate.a = 1.0 if int(_elapsed * 10.0) % 2 == 0 else 0.35
	queue_redraw()


func _pin_to_viewport_center() -> void:
	global_position = get_viewport_rect().get_center()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size := 28
	var label := "WARNING"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	draw_string(
		font,
		text_pos + Vector2(1.5, 1.5),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0.0, 0.0, 0.0, 0.65),
	)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, warning_color)
