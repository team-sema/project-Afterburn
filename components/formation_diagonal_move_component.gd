class_name FormationDiagonalMoveComponent
extends Node

## Formation member on a straight diagonal dive (shared clock + fixed offset).
## X is ping-ponged inside the playfield so the wave does not despawn off the sides.
## Y keeps descending until FreeOffscreen removes them at the bottom.

@export var actor: Node2D
@export var move_component: MoveComponent

@export_range(0.0, 400.0, 1.0) var forward_speed := 72.0
## Degrees from +Y toward ±X. Larger absolute value = shallower descent, more lateral travel.
@export_range(-80.0, 80.0, 0.5) var dive_angle_degrees := 50.0
@export var edge_margin := 8.0

var formation_origin := Vector2.ZERO
var formation_offset := Vector2.ZERO
var formation_start_time := 0.0
var _half_span := 48.0
var _active := false


func setup_formation(
	origin: Vector2,
	offset: Vector2,
	shared_start_time: float,
	movement_settings: Dictionary = {},
) -> void:
	formation_origin = origin
	formation_offset = offset
	formation_start_time = shared_start_time
	if movement_settings.has("forward_speed"):
		forward_speed = float(movement_settings["forward_speed"])
	if movement_settings.has("dive_angle_degrees"):
		dive_angle_degrees = float(movement_settings["dive_angle_degrees"])
	if movement_settings.has("half_span"):
		_half_span = float(movement_settings["half_span"])
	if movement_settings.has("edge_margin"):
		edge_margin = float(movement_settings["edge_margin"])
	_active = true
	if move_component != null:
		move_component.velocity = Vector2.ZERO
		move_component.set_process(false)
	# Spawner configure_before_add runs before add_child; viewport needs the tree.
	if actor != null and actor.is_inside_tree():
		_apply_position()
	else:
		call_deferred("_apply_position")


func _process(_delta: float) -> void:
	if not _active:
		return
	_apply_position()


func _apply_position() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if not actor.is_inside_tree():
		return
	var elapsed := maxf(0.0, (Time.get_ticks_msec() * 0.001) - formation_start_time)
	var speed_scale := 1.0
	if move_component != null:
		speed_scale = move_component.velocity_multiplier
	var angle := deg_to_rad(dive_angle_degrees)
	var distance := forward_speed * speed_scale * elapsed
	var lateral_travel := sin(angle) * distance
	var forward_travel := cos(angle) * distance

	var viewport_width := actor.get_viewport_rect().size.x
	var lo := edge_margin + _half_span
	var hi := viewport_width - edge_margin - _half_span
	var center_x := _ping_pong(formation_origin.x, lateral_travel, lo, hi)
	var center_y := formation_origin.y + forward_travel
	actor.global_position = Vector2(center_x, center_y) + formation_offset


func _ping_pong(start: float, delta: float, lo: float, hi: float) -> float:
	var span := hi - lo
	if span <= 0.0:
		return clampf(start, lo, hi)
	var relative := (start + delta) - lo
	var period := span * 2.0
	var m := fposmod(relative, period)
	if m <= span:
		return lo + m
	return hi - (m - span)
