extends BarrageSequence
## Evolved Caster: two rings per beat that spin in opposite directions.

func build(params: Dictionary) -> void:
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/needle.tres")
	shot.behavior = BulletBehavior.new()
	shot.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
	shot.lifetime = 8.0
	var rings := int(params.get("rings", 5))
	var count := int(params.get("count", 12))
	var speed := float(params.get("speed", 95.0))
	var spin := float(params.get("spin", 9.0))
	# The second ring starts half a gap over so the two rings never overlap.
	var half_gap := 180.0 / float(maxi(1, count))
	for index in rings:
		var forward := BarrageVolley.new()
		forward.shot = shot
		forward.layout = BarrageVolley.Layout.RING
		forward.count = count
		forward.speed = speed
		forward.angle_degrees = -90.0 + index * spin
		var backward := BarrageVolley.new()
		backward.shot = shot
		backward.layout = BarrageVolley.Layout.RING
		backward.count = count
		backward.speed = speed
		backward.angle_degrees = -90.0 + half_gap - index * spin
		var pair: Array[BarrageVolley] = [forward, backward]
		fire_together(pair)
		if index < rings - 1:
			wait(float(params.get("gap", 0.1)))
	wait(float(params.get("rest", 4.8)))
	repeat()
