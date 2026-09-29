extends RefCounted
## Shot builders shared by the lab showcase patterns in patterns/showcase/.
## Lives outside patterns/ so the Lab pattern list only shows real patterns.

const ROUND := preload("res://resources/projectiles/round.tres")
const RICE := preload("res://resources/projectiles/rice.tres")
const ORB := preload("res://resources/projectiles/orb.tres")
const NEEDLE := preload("res://resources/projectiles/needle.tres")

const PINK := Color(1.0, 0.22, 0.52)
const CYAN := Color(0.3, 0.85, 1.0)
const YELLOW := Color(1.0, 0.85, 0.25)
const VIOLET := Color(0.7, 0.42, 1.0)
const GREEN := Color(0.4, 1.0, 0.55)
const RED := Color(1.0, 0.28, 0.3)
const WHITE := Color(0.95, 0.95, 1.0)


## A bullet of `appearance` recoloured to `tint`. Appearance is duplicated so the
## shared preset keeps its colour; textures stay shared.
static func bullet(
	appearance: BulletAppearance,
	tint: Color,
	behavior: BulletBehavior = null,
	lifetime := 10.0,
) -> BarrageShot:
	var shot := BarrageShot.new()
	var look := appearance.duplicate() as BulletAppearance
	look.tint = tint
	shot.appearance = look
	shot.behavior = behavior if behavior != null else BulletBehavior.new()
	shot.lifetime = lifetime
	return shot


static func trail_laser(behavior: BulletBehavior, trail := 1.6, lifetime := 8.0) -> BarrageShot:
	var shot := BarrageShot.new()
	shot.kind = BarrageShot.Kind.TRAIL_LASER
	shot.behavior = behavior
	shot.trail_duration = trail
	shot.core_width = 6.0
	shot.hit_width = 3.0
	shot.lifetime = lifetime
	return shot


## One straight bullet toward `direction` (API angles: down = 0°).
static func single(shot: BarrageShot, direction: Vector2, speed: float) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.SINGLE
	volley.speed = speed
	volley.angle_degrees = rad_to_deg(Vector2.DOWN.angle_to(direction))
	return volley
