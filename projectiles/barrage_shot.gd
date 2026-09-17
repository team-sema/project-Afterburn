class_name BarrageShot
extends Resource
## Serializable projectile recipe. No live projectile state belongs here.

enum Kind { BULLET, TRAIL_LASER, LEGACY, CURVED_LASER = 1 } # Legacy name aliases the same body.
@export var kind: Kind = Kind.BULLET
@export var appearance: BulletAppearance
@export var behavior: BulletBehavior
@export var trail_effect: BulletTrailEffect
@export var turn_degrees := 70.0
@export var turn_duration := 1.5
@export var trail_duration := 1.4
@export var core_width := 6.0
@export var hit_width := 4.0
@export var lifetime := 5.0

func is_valid() -> bool:
	if trail_effect != null and (not trail_effect.is_valid() or kind == Kind.LEGACY): return false
	if behavior != null and not behavior.validation_error().is_empty():
		return false
	match kind:
		Kind.BULLET:
			return appearance != null and appearance.is_valid() and behavior != null and is_finite(lifetime) and lifetime > 0
		Kind.LEGACY:
			return behavior == null # Comparison adapter has no Behavior runtime.
		Kind.CURVED_LASER:
			return (is_finite(turn_degrees) and is_finite(turn_duration) and turn_duration >= 0
				and is_finite(trail_duration) and trail_duration > 0
				and is_finite(core_width) and core_width > 0
				and is_finite(hit_width) and hit_width > 0 and hit_width <= core_width
				and is_finite(lifetime) and lifetime > 0)
	return false

func spawn(parent: Node2D, origin: Vector2, direction: Vector2, speed: float, debug := false, target: Node2D = null, target_resolver := Callable()) -> Node2D:
	if not is_valid() or not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return null
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx() or not is_finite(speed) or speed < 0 or (kind == Kind.CURVED_LASER and speed == 0):
		return null
	var projectile: Node2D
	match kind:
		Kind.BULLET:
			var bullet := preload("res://projectiles/foundation_bullet.tscn").instantiate() as FoundationBullet
			bullet.appearance = appearance
			bullet.behavior = behavior
			bullet.trail_effect = trail_effect
			bullet.lifetime = lifetime
			bullet.show_hitbox = debug
			projectile = bullet
		Kind.CURVED_LASER:
			var laser := preload("res://projectiles/curved_laser.tscn").instantiate() as CurvedLaser
			laser.turn_degrees = turn_degrees
			laser.behavior = behavior
			laser.trail_effect = trail_effect
			laser.turn_duration = turn_duration
			laser.trail_duration = trail_duration
			laser.core_width = core_width
			laser.hit_width = hit_width
			laser.lifetime = lifetime
			laser.show_hitbox = debug
			projectile = laser
		Kind.LEGACY:
			projectile = preload("res://projectiles/base_enemy_projectile.tscn").instantiate()
	projectile.position = parent.to_local(origin)
	parent.add_child(projectile)
	if kind == Kind.LEGACY:
		var velocity := parent.global_transform.basis_xform_inv(direction.normalized() * speed)
		projectile.launch(velocity.normalized() if speed > 0 else direction, velocity.length())
	else:
		projectile.launch(direction, speed)
		projectile.behavior_state.configure_homing(projectile, origin, target, target_resolver)
	return projectile if is_instance_valid(projectile) else null
