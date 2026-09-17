extends BarrageSequence
## Save this file (or a copy), then press F5 in the running Bullet Lab.

func _init() -> void:
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/round.tres")
	shot.behavior = BulletBehavior.new().homing(60, 1.5)
	shot.lifetime = 5
	fire_fan(shot, 5, 70, 80)
	wait(1.5)
	repeat()
