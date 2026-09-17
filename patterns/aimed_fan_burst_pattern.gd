extends BarrageSequence
## Five-way fan whose center shot aims at the target on every emission
## (Aim.EACH_SHOT), fired as a burst. Each fan re-centers on the target's
## current position, so the whole burst tracks a moving player.
##
## pattern_params (all optional): ways, spread, shots, gap, rest, speed.

func build(params: Dictionary) -> void:
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/round.tres")
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 6.0
	var fan := BarrageVolley.new()
	fan.shot = shot
	fan.layout = BarrageVolley.Layout.FAN
	fan.count = int(params.get("ways", 5))
	fan.spread_degrees = float(params.get("spread", 40.0))
	fan.aim = BarrageVolley.Aim.EACH_SHOT # Fan center = emitter -> target at fire time.
	fan.speed = float(params.get("speed", 120.0))
	var shots := int(params.get("shots", 5))
	var gap := float(params.get("gap", 0.15))
	for index in shots:
		fire(fan)
		if index < shots - 1:
			wait(gap)
	wait(float(params.get("rest", 1.6)))
	repeat()
