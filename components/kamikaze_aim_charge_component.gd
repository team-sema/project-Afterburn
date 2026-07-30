class_name KamikazeAimChargeComponent
extends Node

## Descend/aim keep a shared V (origin + offset).
## On charge start, unlock formation and each member flies independently
## toward the locked player point from its own position (original charge style).

enum Phase { DESCEND, AIM, CHARGE }

@export var actor: Node2D
@export var move_component: MoveComponent
@export var targeting_component: TargetingComponent
@export var visual_anchor: Node2D

@export_range(0.2, 10.0, 0.05) var descend_duration := 1.4
@export_range(1.0, 120.0, 1.0) var descend_speed := 42.0
@export_range(0.2, 10.0, 0.05) var aim_duration := 1.4
@export_range(40.0, 600.0, 1.0) var charge_speed := 280.0

var formation_origin := Vector2.ZERO
var formation_offset := Vector2.ZERO
var formation_start_time := 0.0
var _active := false
var _phase: Phase = Phase.DESCEND
var _charge_direction := Vector2.DOWN


func setup_formation(
	origin: Vector2,
	offset: Vector2,
	shared_start_time: float,
	movement_settings: Dictionary = {},
) -> void:
	formation_origin = origin
	formation_offset = offset
	formation_start_time = shared_start_time
	if movement_settings.has("descend_duration"):
		descend_duration = float(movement_settings["descend_duration"])
	if movement_settings.has("descend_speed"):
		descend_speed = float(movement_settings["descend_speed"])
	if movement_settings.has("aim_duration"):
		aim_duration = float(movement_settings["aim_duration"])
	if movement_settings.has("charge_speed"):
		charge_speed = float(movement_settings["charge_speed"])
	_active = true
	_phase = Phase.DESCEND
	if move_component != null:
		move_component.velocity = Vector2.ZERO
		move_component.set_process(false)
	_apply_formation_position()


func _ready() -> void:
	assert(actor != null, "KamikazeAimChargeComponent requires actor.")
	assert(move_component != null, "KamikazeAimChargeComponent requires MoveComponent.")
	if not _active:
		setup_formation(
			actor.global_position,
			Vector2.ZERO,
			Time.get_ticks_msec() * 0.001,
			{},
		)


func _process(delta: float) -> void:
	if not _active or not is_instance_valid(actor):
		return

	if _phase == Phase.CHARGE:
		_face_toward(actor.global_position + _charge_direction)
		return

	var elapsed := maxf(0.0, (Time.get_ticks_msec() * 0.001) - formation_start_time)
	var speed_scale := 1.0
	if move_component != null:
		speed_scale = move_component.velocity_multiplier

	if elapsed < descend_duration:
		_phase = Phase.DESCEND
		_apply_formation_position()
		_face_toward(actor.global_position + Vector2.DOWN)
	elif elapsed < descend_duration + aim_duration:
		_phase = Phase.AIM
		_apply_formation_position()
		_face_toward(_aim_point())
	else:
		_begin_independent_charge(speed_scale)


func _apply_formation_position() -> void:
	var elapsed := maxf(0.0, (Time.get_ticks_msec() * 0.001) - formation_start_time)
	var speed_scale := 1.0
	if move_component != null:
		speed_scale = move_component.velocity_multiplier
	var descend_elapsed := minf(elapsed, descend_duration)
	var center := formation_origin + Vector2(0.0, descend_speed * speed_scale * descend_elapsed)
	actor.global_position = center + formation_offset


func _begin_independent_charge(speed_scale: float) -> void:
	# Snap to final V slot, then each flies on its own toward the locked aim point.
	_apply_formation_position()
	_phase = Phase.CHARGE
	var target_point := _aim_point()
	var to_target := target_point - actor.global_position
	if to_target.length_squared() < 0.0001:
		_charge_direction = Vector2.DOWN
	else:
		_charge_direction = to_target.normalized()
	move_component.velocity = _charge_direction * charge_speed * speed_scale
	move_component.set_process(true)
	_face_toward(actor.global_position + _charge_direction)


func _aim_point() -> Vector2:
	if targeting_component == null:
		return actor.global_position + Vector2.DOWN * 200.0
	var target := targeting_component.get_target()
	if target == null or not is_instance_valid(target):
		return actor.global_position + Vector2.DOWN * 200.0
	return targeting_component.get_target_position()


func _face_toward(world_point: Vector2) -> void:
	if visual_anchor == null or not is_instance_valid(actor):
		return
	var direction := world_point - actor.global_position
	if direction.length_squared() < 0.0001:
		return
	visual_anchor.rotation = direction.angle() - PI * 0.5
