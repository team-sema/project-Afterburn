class_name PlayerHomingMissile
extends Node2D

const ENEMY_HURTBOX_MASK := 1 << 1

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

var _weapon: WeaponSystem
var _base_damage := 1
var _aoe_radius := 0.0
var _aoe_mult := 1.0
var _terminal_min := 0.0
var _terminal_max := 0.0
var _terminal_full_time := 2.5
var _flight_time := 0.0
var _pending_configure := false


func configure_motion(
	configured_speed: float,
	configured_turn_rate: float,
	configured_retarget_interval: float,
) -> void:
	speed = maxf(1.0, configured_speed)
	turn_rate = maxf(0.1, configured_turn_rate)
	retarget_interval = maxf(0.02, configured_retarget_interval)


func configure_missile_combat(
	weapon: WeaponSystem,
	base_damage: int,
	aoe_radius: float,
	aoe_mult: float,
	terminal_min: float,
	terminal_max: float,
	terminal_full_time: float,
) -> void:
	_weapon = weapon
	_base_damage = maxi(1, base_damage)
	_aoe_radius = maxf(0.0, aoe_radius)
	_aoe_mult = maxf(0.0, aoe_mult)
	_terminal_min = maxf(0.0, terminal_min)
	_terminal_max = maxf(0.0, terminal_max)
	_terminal_full_time = maxf(0.05, terminal_full_time)
	_pending_configure = true
	if is_node_ready():
		_apply_damage_resolver()


func _ready() -> void:
	_velocity = Vector2(0, -speed)
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(_on_hit_hurtbox)
	_acquire_target()
	if _pending_configure or _weapon != null:
		_apply_damage_resolver()


func _process(delta: float) -> void:
	_flight_time += delta
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


func _hitbox() -> HitboxComponent:
	if hitbox_component != null:
		return hitbox_component
	return get_node_or_null("HitboxComponent") as HitboxComponent


func _terminal_mult() -> float:
	if _terminal_max <= 0.0 and _terminal_min <= 0.0:
		return 1.0
	var t := clampf(_flight_time / _terminal_full_time, 0.0, 1.0)
	var bonus := lerpf(_terminal_min, _terminal_max, t)
	return 1.0 + bonus


func _apply_damage_resolver() -> void:
	var hitbox := _hitbox()
	if hitbox == null:
		return
	hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
		var raw := maxi(1, roundi(float(_base_damage) * _terminal_mult()))
		if _weapon != null:
			return _weapon.resolve_hit_damage(raw, hurtbox)
		return raw
	hitbox.damage = maxi(1, roundi(float(_base_damage) * _terminal_mult()))
	_pending_configure = false


func _on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	if _aoe_radius > 0.0:
		_deal_aoe(hurtbox)
	queue_free()


func _deal_aoe(exclude_hurtbox: HurtboxComponent) -> void:
	var world := get_world_2d()
	if world == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = _aoe_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var aoe_damage := maxi(1, roundi(float(_base_damage) * _terminal_mult() * _aoe_mult))
	var hitbox := HitboxComponent.new()
	for result in world.direct_space_state.intersect_shape(query, 64):
		var collider: Variant = result.get("collider")
		if not collider is HurtboxComponent:
			continue
		var other := collider as HurtboxComponent
		if other == exclude_hurtbox or other.is_invincible:
			continue
		if _weapon != null:
			hitbox.damage = _weapon.resolve_hit_damage(aoe_damage, other)
		else:
			hitbox.damage = aoe_damage
		other.hurt.emit(hitbox)
	hitbox.free()


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
