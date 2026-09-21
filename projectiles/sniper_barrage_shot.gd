class_name SniperBarrageShot
extends BarrageShot
## Specialized body adapter. Preserves sniper range, damage, visuals and finished.
## Does not support BulletBehavior, Appearance or particle trails.

@export var bullet_width := 3.0
@export var max_range := 480.0
@export var damage := 1

func is_valid() -> bool:
	return (is_finite(bullet_width) and bullet_width >= 1.0
		and is_finite(max_range) and max_range >= 8.0 and damage >= 1
		and behavior == null and appearance == null and trail_effect == null)

func spawn(parent: Node2D, origin: Vector2, direction: Vector2, speed: float,
		_debug := false, _target: Node2D = null, _target_resolver := Callable()) -> Node2D:
	if not is_valid() or not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion(): return null
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx() or not is_finite(speed) or speed < 100: return null
	var bullet := preload("res://projectiles/sniper_bullet.tscn").instantiate() as SniperBullet
	parent.add_child(bullet)
	bullet.configure(origin, direction, speed, bullet_width, max_range, damage)
	bullet.global_rotation = direction.angle() - PI * 0.5
	return bullet
