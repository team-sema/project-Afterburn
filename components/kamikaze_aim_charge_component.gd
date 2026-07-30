class_name KamikazeAimChargeComponent
extends Node

## Slow descend → hold and aim at player → charge at locked aim point.
## MoveComponent is the sole velocity/position writer.

enum Phase { DESCEND, AIM, CHARGE }

@export var actor: Node2D
@export var move_component: MoveComponent
@export var targeting_component: TargetingComponent
@export var visual_anchor: Node2D

@export_range(0.2, 10.0, 0.05) var descend_duration := 1.4
@export_range(1.0, 120.0, 1.0) var descend_speed := 42.0
@export_range(0.2, 10.0, 0.05) var aim_duration := 1.4
## Faster than player blaster (200) so the charge reads as a threat.
@export_range(40.0, 600.0, 1.0) var charge_speed := 280.0

var _phase: Phase = Phase.DESCEND
var _phase_elapsed := 0.0
var _charge_direction := Vector2.DOWN


func _ready() -> void:
	assert(actor != null, "KamikazeAimChargeComponent requires actor.")
	assert(move_component != null, "KamikazeAimChargeComponent requires MoveComponent.")
	_begin_descend()


func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	_phase_elapsed += delta
	match _phase:
		Phase.DESCEND:
			if _phase_elapsed >= descend_duration:
				_begin_aim()
		Phase.AIM:
			_face_toward(_aim_point())
			if _phase_elapsed >= aim_duration:
				_begin_charge()
		Phase.CHARGE:
			_face_toward(actor.global_position + _charge_direction)


func _begin_descend() -> void:
	_phase = Phase.DESCEND
	_phase_elapsed = 0.0
	move_component.velocity = Vector2(0.0, descend_speed)
	move_component.set_process(true)
	_face_toward(actor.global_position + Vector2.DOWN)


func _begin_aim() -> void:
	_phase = Phase.AIM
	_phase_elapsed = 0.0
	move_component.velocity = Vector2.ZERO
	_face_toward(_aim_point())


func _begin_charge() -> void:
	_phase = Phase.CHARGE
	_phase_elapsed = 0.0
	var target_point := _aim_point()
	var to_target := target_point - actor.global_position
	if to_target.length_squared() < 0.0001:
		_charge_direction = Vector2.DOWN
	else:
		_charge_direction = to_target.normalized()
	move_component.velocity = _charge_direction * charge_speed
	_face_toward(actor.global_position + _charge_direction)


func _aim_point() -> Vector2:
	if targeting_component == null:
		return actor.global_position + Vector2.DOWN * 64.0
	var target := targeting_component.get_target()
	if target == null or not is_instance_valid(target):
		return actor.global_position + Vector2.DOWN * 64.0
	return targeting_component.get_target_position()


func _face_toward(world_point: Vector2) -> void:
	if visual_anchor == null or not is_instance_valid(actor):
		return
	var direction := world_point - actor.global_position
	if direction.length_squared() < 0.0001:
		return
	# Sprite tip is local +Y; align that axis with the aim/charge direction.
	visual_anchor.rotation = direction.angle() - PI * 0.5
