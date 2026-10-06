extends BarrageSequence
## Caster ring curtain: plain pink round bullets, no trail. Rounds mark area
## pressure, so the ring never reads as the aimed needles Drones fire.

const ROUND := preload("res://resources/projectiles/round.tres")


func build(params: Dictionary) -> void:
	var shot := BarrageShot.new()
	shot.appearance = ROUND
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 8.0
	var rings := int(params.get("rings", 5))
	for index in rings:
		fire_ring(shot, int(params.get("count", 16)), float(params.get("speed", 95.0)),
			-90.0 + index * float(params.get("spin", 7.0)))
		if index < rings - 1:
			wait(float(params.get("gap", 0.1)))
	wait(float(params.get("rest", 4.8)))
	repeat()
