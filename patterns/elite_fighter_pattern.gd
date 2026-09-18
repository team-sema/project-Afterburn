extends BarrageSequence
## One finite attack phase. Movement, warning and recovery belong to the actor.

func build(params: Dictionary) -> void:
	var focused := bool(params.get("focused", false))
	var shots := 10 if focused else 4
	var count := (3 if focused else 5) + int(params.get("extra_shots", 0))
	var spread := maxf(12.0 if focused else 76.0, float(params.get("min_spread", 0)))
	var direction_degrees := float(params.get("angle", 0))
	var gap := 0.13 if focused else 0.34
	var shot := preload("res://resources/projectiles/needle_straight_shot.tres")
	for index in shots:
		var angle := direction_degrees if focused else lerpf(-18.0, 18.0, float(index) / 3.0)
		fire_fan(shot, count, spread, 195.0 if focused else 145.0, angle)
		if index < shots - 1: wait(gap)
