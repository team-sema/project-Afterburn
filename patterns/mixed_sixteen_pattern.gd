extends BarrageSequence
## Eight straight balls interleaved with eight sinusoidal trail lasers.

func _init() -> void:
	var ball := BarrageShot.new()
	ball.appearance = preload("res://resources/projectiles/round.tres")
	ball.behavior = BulletBehavior.new()
	ball.lifetime = 8.0
	var laser := BarrageShot.new()
	laser.kind = BarrageShot.Kind.TRAIL_LASER
	var wave := BulletAction.make(
		BulletAction.Type.HEADING_WAVE, 35.0, 8.0
	)
	var accel := BulletAction.make(
		BulletAction.Type.SPEED, 300.0, 3.0
	)
	laser.behavior = BulletBehavior.new().parallel(
		[wave, accel]
	)
	laser.trail_duration = 2.4
	laser.lifetime = 8.0
	var balls := BarrageVolley.new()
	balls.shot = ball
	balls.layout = BarrageVolley.Layout.RING
	balls.count = 8
	balls.speed = 65.0
	var lasers := BarrageVolley.new()
	lasers.shot = laser
	lasers.layout = BarrageVolley.Layout.RING
	lasers.count = 8
	lasers.speed = 45.0
	lasers.angle_degrees = 22.5
	fire_together([balls, lasers])
	wait(5.0)
	repeat()
