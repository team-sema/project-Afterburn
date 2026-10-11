class_name SniperBarrageShot
extends BarrageShot
## Sniper round recipe: a straight pooled FoundationBullet whose range, width
## and damage come from the attack component. Range becomes lifetime
## (`max_range / speed`), width scales the streak appearance and its collision
## rectangle, and damage rides on the bullet. Like every pooled bullet it is a
## normal enemy bullet to EnemyBullets (cancel, queries, trajectory effects).
## Rules: enemies/sniper.md 원거리 저격.

const APPEARANCE := preload("res://resources/projectiles/sniper_round.tres")
## Width the preset was drawn for; other widths scale the sprite layers.
const BASE_WIDTH := 3.0

@export var bullet_width := 3.0
@export var max_range := 480.0
@export var damage := 1


func _init() -> void:
	kind = Kind.BULLET
	appearance = APPEARANCE.duplicate() as BulletAppearance
	behavior = BulletBehavior.new()


func is_valid() -> bool:
	return (is_finite(bullet_width) and bullet_width >= 1.0
		and is_finite(max_range) and max_range >= 8.0 and damage >= 1
		and trail_effect == null and behavior != null and behavior.actions.is_empty()
		and super())


func spawn(parent: Node2D, origin: Vector2, direction: Vector2, speed: float,
		debug := false, target: Node2D = null, target_resolver := Callable(), _shared_config := false) -> Node:
	if not is_valid() or not is_finite(speed) or speed < 100:
		return null
	# The body copies this appearance at spawn, so size it for this shot first.
	var scale := bullet_width / BASE_WIDTH
	var base := APPEARANCE as BulletAppearance
	appearance.core_size = Vector2(base.core_size.x * scale, base.core_size.y)
	appearance.tight_size = Vector2(base.tight_size.x * scale, base.tight_size.y)
	appearance.wide_size = Vector2(base.wide_size.x * scale, base.wide_size.y)
	# A slightly long rectangle keeps the high-speed round reliable at 60 Hz.
	appearance.collision_size = Vector2(maxf(2.0, bullet_width), maxf(18.0, speed / 30.0))
	lifetime = max_range / speed
	var bullet := super.spawn(parent, origin, direction, speed, debug, target, target_resolver, false)
	if bullet is FoundationBullet:
		(bullet as FoundationBullet).damage = damage
	return bullet
