extends BarrageSequence
## Showcase: Saturn burst. A big orb flies toward the target, brakes and
## squeezes down to a bright core as if compressing, then pops into two
## concentric tilted ellipses of small bullets that expand without deforming,
## like Saturn's rings blown apart. Each shard's speed is the ellipse radius in
## its direction, which needs one SPAWN carrying 32 single volleys.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const SHARDS := 32
const AXIS_RATIO := 0.42 # Minor / major axis of each ring.
const MAJOR_AXIS_DEGREES := 65.0 # Major axis measured from the orb's heading.
const OUTER_SPEED := 170.0
const INNER_SPEED := 110.0
const ORB_SPEED := 130.0
const BRAKE_SECONDS := 0.9
const SQUEEZE_SECONDS := 0.45


func _init() -> void:
	for angle in [0.0, 28.0, -28.0]:
		var volley := BarrageVolley.new()
		volley.shot = _orb()
		volley.speed = ORB_SPEED
		volley.angle_degrees = angle
		volley.aim = BarrageVolley.Aim.EACH_SHOT
		fire(volley)
		wait(0.9)
	wait(1.2)
	repeat()


static func _orb() -> BarrageShot:
	var behavior := BulletBehavior.new()
	behavior.speed_to(0.0, BRAKE_SECONDS).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)
	behavior.parallel([
		BulletAction.visual_scale_to(0.35, SQUEEZE_SECONDS).eased(Tween.TRANS_QUAD, Tween.EASE_IN),
		BulletAction.hitbox_scale_to(0.4, SQUEEZE_SECONDS),
		BulletAction.tint_to(Shots.WHITE, SQUEEZE_SECONDS),
	])
	behavior.spawn_together(_ring(Shots.bullet(Shots.ROUND, Shots.YELLOW), OUTER_SPEED))
	behavior.spawn_together(_ring(Shots.bullet(Shots.ROUND, Shots.CYAN), INNER_SPEED), true)
	return Shots.bullet(Shots.ORB, Shots.VIOLET, behavior)


## One SINGLE volley per shard: its direction is a point on the tilted ellipse
## (relative to the orb heading) and its speed scales with that radius.
static func _ring(shard: BarrageShot, speed: float) -> Array[BarrageVolley]:
	shard.appearance.core_size = Vector2(6, 6)
	var volleys: Array[BarrageVolley] = []
	for index in SHARDS:
		var t := TAU * index / SHARDS
		var point := Vector2(cos(t), sin(t) * AXIS_RATIO).rotated(deg_to_rad(MAJOR_AXIS_DEGREES))
		var volley := BarrageVolley.new()
		volley.shot = shard
		volley.layout = BarrageVolley.Layout.SINGLE
		volley.angle_degrees = rad_to_deg(point.angle())
		volley.speed = speed * point.length()
		volleys.append(volley)
	return volleys
