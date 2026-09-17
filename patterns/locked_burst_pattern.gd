extends BarrageSequence
## Aim once, then fire a burst along that locked direction. The target may move
## during the burst; the shots keep the direction captured by aim().
##
## pattern_params (all optional): shots, gap, rest, speed.

func build(params: Dictionary) -> void:
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/needle.tres")
	shot.behavior = BulletBehavior.new()
	shot.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
	shot.lifetime = 6.0
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.aim = BarrageVolley.Aim.LOCKED
	volley.speed = float(params.get("speed", 140.0))
	var shots := int(params.get("shots", 3))
	var gap := float(params.get("gap", 0.12))
	aim()
	for index in shots:
		fire(volley)
		if index < shots - 1:
			wait(gap)
	wait(float(params.get("rest", 2.0)))
	repeat()
