extends BarrageShot
## Elite Awl fountain laser: rises from the tail, then homes in and speeds up.

func _init() -> void:
	kind = Kind.TRAIL_LASER
	core_width = 5.0
	hit_width = 3.0
	trail_duration = 0.5
	lifetime = 5.0
	behavior = BulletBehavior.new()
	behavior.tint_to(Color(1.0, 0.35, 0.4), 0.0)
	behavior.wait(0.3)
	behavior.parallel([BulletAction.homing(180.0, 1.2), BulletAction.make(BulletAction.Type.SPEED, 190.0, 1.2)])
