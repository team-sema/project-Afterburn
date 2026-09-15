class_name EncounterStepWarning
extends Node2D

## Compact center-screen blink telegraph for WAVE / ELITE / BOSS steps.
## Matches EntryWarningComponent's hard neon blink (no soft sine fade).

signal finished

@export_range(0.2, 3.0, 0.05, "suffix:s") var warning_duration := 0.8
@export var warning_color := Color(1.0, 0.16, 0.12, 0.95)

var _kind := EncounterSequenceStep.Kind.WAVE
var _elapsed := 0.0
var _active := true


static func present(
	host: Node,
	kind: EncounterSequenceStep.Kind,
	duration := 0.8,
) -> EncounterStepWarning:
	assert(host != null, "EncounterStepWarning requires a host node.")
	var warning := EncounterStepWarning.new()
	warning._kind = kind
	warning.warning_duration = duration
	warning.warning_color = _color_for_kind(kind)
	warning.z_index = 120
	host.add_child(warning)
	warning._pin_to_viewport_center()
	return warning


static func _color_for_kind(kind: EncounterSequenceStep.Kind) -> Color:
	# Shared hard red telegraph; kind still changes the mark shape.
	match kind:
		EncounterSequenceStep.Kind.WAVE, EncounterSequenceStep.Kind.ELITE, EncounterSequenceStep.Kind.BOSS:
			return Color(1.0, 0.16, 0.12, 0.95)
		_:
			return Color(1.0, 0.16, 0.12, 0.95)


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
	# Small diamond plate + exclamation. Stays readable under bloom.
	var plate := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(9.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-9.0, 0.0),
	])
	draw_colored_polygon(plate, Color(warning_color.r, warning_color.g, warning_color.b, 0.22))
	draw_polyline(plate + PackedVector2Array([plate[0]]), warning_color, 1.6, true)
	draw_line(Vector2(0.0, -4.5), Vector2(0.0, 1.5), warning_color, 2.0, true)
	draw_circle(Vector2(0.0, 4.5), 1.15, warning_color)
	match _kind:
		EncounterSequenceStep.Kind.WAVE:
			_draw_chevron_pair()
		EncounterSequenceStep.Kind.ELITE:
			draw_circle(Vector2(0.0, -13.5), 1.4, warning_color)
		EncounterSequenceStep.Kind.BOSS:
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, warning_color, 1.4, true)


func _draw_chevron_pair() -> void:
	var left := PackedVector2Array([
		Vector2(-14.0, -3.0),
		Vector2(-10.0, 0.0),
		Vector2(-14.0, 3.0),
	])
	var right := PackedVector2Array([
		Vector2(14.0, -3.0),
		Vector2(10.0, 0.0),
		Vector2(14.0, 3.0),
	])
	draw_polyline(left, warning_color, 1.5, true)
	draw_polyline(right, warning_color, 1.5, true)
