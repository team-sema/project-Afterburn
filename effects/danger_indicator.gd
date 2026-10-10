class_name DangerIndicator
extends Node2D
## Shared visual only: directions are in this indicator's local coordinate system.
@export var warning_color := Color("35ffe1")
@export_range(0.25, 3.0, 0.05) var warning_scale := 1.0
@export_range(0.1, 3.0, 0.05) var warning_duration := 0.9
@export var inward_direction := Vector2.RIGHT
@export var trajectory_direction := Vector2.ZERO
@export var auto_advance := true
var elapsed := 0.0

func _ready() -> void:
	z_index = 100

func _process(delta: float) -> void:
	if auto_advance:
		elapsed += delta
		if elapsed >= warning_duration:
			hide()
			queue_free()
			return
	queue_redraw()

func set_preview_time(time: float) -> void:
	elapsed = maxf(0.0, time)
	visible = elapsed < warning_duration
	queue_redraw()

func is_warning_active() -> bool:
	return elapsed < warning_duration and not is_queued_for_deletion()

func local_trajectory() -> Vector2:
	var direction := trajectory_direction if not trajectory_direction.is_zero_approx() else inward_direction
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	return direction.normalized().rotated(-inward_direction.angle())

func _color(alpha: float) -> Color:
	return Color(warning_color, warning_color.a * alpha)

func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	# Transform both geometry and strokes without modifying the caller's Node2D.
	var angle := inward_direction.angle()
	draw_line(a.rotated(angle) * warning_scale, b.rotated(angle) * warning_scale, color, width * warning_scale, true)

func _draw() -> void:
	if not is_warning_active(): return
	var progress := clampf(elapsed / maxf(warning_duration, 0.001), 0.0, 1.0)
	var pulse := 0.55 + 0.45 * pow(sin(progress * PI * 3.0), 2.0)
	# Retain the original acquiring animation, compacted to 2/3 size.
	var contact := Vector2.ZERO
	var acquiring_radius := 20.0 + 8.0 * (1.0 - progress)
	var contact_color := _color(pulse)
	for i in 13:
		var angle := deg_to_rad(-75.0 + i * 12.5)
		var ray := Vector2.from_angle(angle)
		var tick_length := 4.5 if i % 3 == 0 else 2.0
		_line(contact + ray * acquiring_radius, contact + ray * (acquiring_radius + tick_length), contact_color, 1.2)
	for sign_y in [-1.0, 1.0]:
		var bracket_y: float = contact.y + sign_y * (12.0 + 7.0 * (1.0 - progress))
		_line(Vector2(2, bracket_y), Vector2(12, bracket_y), contact_color, 1.2)
		_line(Vector2(12, bracket_y), Vector2(12, bracket_y - sign_y * 4.0), contact_color, 1.2)
	_line(contact - Vector2(2, 0), contact + Vector2(7, 0), contact_color, 1.8)
	# One instrument: animate a trajectory arrow inside the existing ticks.
	# Direction stays accurate while its length deploys and light pulses.
	var deploy := 1.0 - pow(1.0 - clampf(elapsed / 0.18, 0.0, 1.0), 3.0)
	var bearing := local_trajectory()
	var tip := contact + bearing * lerpf(5.0, 24.0, deploy)
	var bright := _color((0.8 + pulse * 0.2) * deploy)
	_line(contact, tip, _color(0.14 * deploy), 4.0)
	_line(contact, tip, bright, 1.5)
	for sign_y in [-1.0, 1.0]:
		_line(tip, tip - bearing * 4.0 + bearing.orthogonal() * sign_y * 2.5, bright, 1.2)
