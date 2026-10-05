extends BarrageSequence
## Showcase: comet trail (bullet -> bullet SPAWN). Three big orbs drift toward
## the target; each drops one small spark every 0.06s, alternating left and
## right behind it. Sparks drift backward, brake, cool from white to cyan, then
## shrink and fade with their hitbox, so the wake reads as an afterimage.
## A comet sheds for 64 cycles (128 sparks, the whole per-bullet SPAWN budget,
## about 7.7s). A finite repeat is used because an infinite Behavior cycle
## must last 0.1s+. Single alternating sparks with a short life keep roughly
## 20 sparks alive per comet.

const Shots := preload("res://labs/bullet/showcase_shots.gd")

const DROP_INTERVAL := 0.06
const WAKE_HALF_ANGLE := 35.0


func _init() -> void:
	var spark_behavior := BulletBehavior.new()
	spark_behavior.parallel([
		BulletAction.make(BulletAction.Type.SPEED, 0.0, 0.55).eased(Tween.TRANS_QUAD, Tween.EASE_OUT),
		BulletAction.tint_to(Shots.CYAN, 0.55),
	])
	spark_behavior.parallel([
		BulletAction.make(BulletAction.Type.OPACITY, 0.0, 0.75),
		BulletAction.visual_scale_to(0.4, 0.75),
		BulletAction.hitbox_scale_to(0.3, 0.75),
	])
	var spark := Shots.bullet(Shots.ROUND, Shots.WHITE, spark_behavior, 1.3)
	spark.appearance.core_size = Vector2(5, 5)
	spark.appearance.collision_radius = 2.0

	# 180 deg = straight behind the comet; alternate the two sides.
	var comet_behavior := BulletBehavior.new()
	for side in [-1.0, 1.0]:
		comet_behavior.wait(DROP_INTERVAL).spawn(Shots.single(spark, Vector2.UP.rotated(deg_to_rad(side * WAKE_HALF_ANGLE)), 28.0))
	var comet := Shots.bullet(Shots.ORB, Shots.CYAN, comet_behavior.repeat(64), 9.0)
	comet.appearance.core_size = Vector2(30, 30)
	comet.appearance.collision_radius = 11.0
	comet.appearance.collision_height = 22.0

	var volley := BarrageVolley.new()
	volley.shot = comet
	volley.layout = BarrageVolley.Layout.FAN
	volley.count = 3
	volley.spread_degrees = 56.0
	volley.speed = 62.0
	volley.aim = BarrageVolley.Aim.EACH_SHOT
	fire(volley)
	wait(2.6)
	repeat()
