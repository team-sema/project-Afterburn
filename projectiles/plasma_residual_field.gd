class_name PlasmaResidualField
extends Node2D

const ENEMY_HURTBOX_MASK := 1 << 1

var duration := 3.0
var radius := 16.0
var base_damage := 1
var max_bonus_mult := 1.0
var weapon: WeaponSystem

var _elapsed := 0.0
var _tick := 0.0


func configure(
	configured_duration: float,
	configured_radius: float,
	configured_damage: int,
	configured_max_bonus: float,
	configured_weapon: WeaponSystem,
) -> void:
	duration = maxf(0.05, configured_duration)
	radius = maxf(4.0, configured_radius)
	base_damage = maxi(1, configured_damage)
	max_bonus_mult = maxf(0.0, configured_max_bonus)
	weapon = configured_weapon


func _process(delta: float) -> void:
	_elapsed += delta
	_tick += delta
	if _elapsed >= duration:
		queue_free()
		return
	if _tick < 0.25:
		return
	_tick = 0.0
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var bonus := max_bonus_mult * t
	var damage := maxi(1, roundi(float(base_damage) * (0.25 + bonus * 0.35)))
	var world := get_world_2d()
	if world == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hitbox := HitboxComponent.new()
	for result in world.direct_space_state.intersect_shape(query, 64):
		var collider: Variant = result.get("collider")
		if not collider is HurtboxComponent:
			continue
		var hurtbox := collider as HurtboxComponent
		if hurtbox.is_invincible:
			continue
		if weapon != null:
			hitbox.damage = weapon.resolve_hit_damage(damage, hurtbox)
		else:
			hitbox.damage = damage
		hurtbox.hurt.emit(hitbox)
	hitbox.free()
