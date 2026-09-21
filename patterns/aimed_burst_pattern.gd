extends BarrageSequence
## Scene-configured aimed bursts; activation belongs to EnemyShootComponent.

func build(params: Dictionary) -> void:
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/needle.tres")
	shot.behavior = BulletBehavior.new()
	shot.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
	shot.lifetime = 8.0
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.FAN
	volley.count = int(params.get("ways", 5))
	volley.spread_degrees = float(params.get("spread", 15.0))
	volley.speed = float(params.get("speed", 80.0))
	volley.aim = BarrageVolley.Aim.EACH_SHOT
	var shots := int(params.get("shots", 2))
	for index in shots:
		fire(volley)
		if index < shots - 1:
			wait(float(params.get("gap", 0.15)))
	wait(float(params.get("rest", 4.5)))
	repeat()
