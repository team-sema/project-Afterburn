class_name PlayerHomingMissile
extends Node2D

@export var enemy_group: StringName = &"enemies"

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent

var _velocity := Vector2(0, -1)
var _target: Node2D
var _retarget_cooldown := 0.0
var speed := 0.0
var turn_rate := 0.0
var retarget_interval := 0.0


func configure_motion(
	configured_speed: float,
	configured_turn_rate: float,
	configured_retarget_interval: float,
) -> void:
	speed = maxf(1.0, configured_speed)
	turn_rate = maxf(0.1, configured_turn_rate)
	retarget_interval = maxf(0.02, configured_retarget_interval)


func _ready() -> void:
	_velocity = Vector2(0, -speed)
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(queue_free.unbind(1))
	_acquire_target()


func _process(delta: float) -> void:
	_retarget_cooldown -= delta
	if _retarget_cooldown <= 0.0:
		_retarget_cooldown = retarget_interval
		_acquire_target()

	if _target != null and is_instance_valid(_target):
		var desired := global_position.direction_to(_target.global_position)
		if desired.length_squared() > 0.0001:
			var current_angle := _velocity.angle()
			var desired_angle := desired.angle()
			var delta_angle := wrapf(desired_angle - current_angle, -PI, PI)
			var max_turn := turn_rate * delta
			var new_angle := current_angle + clampf(delta_angle, -max_turn, max_turn)
			_velocity = Vector2.from_angle(new_angle) * speed
	else:
		_velocity = _velocity.normalized() * speed

	global_position += _velocity * delta
	rotation = _velocity.angle() + PI * 0.5


func _acquire_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	_target = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(enemy_group):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			_target = enemy
