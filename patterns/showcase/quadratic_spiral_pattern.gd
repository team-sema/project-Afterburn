extends BarrageSequence
## Showcase: quadratic spiral ("border of wave and particle" style).
## Each ring's angle grows with the square of time, so the arms first open,
## then sweep back as the rotation reverses. Pure angle bookkeeping — no
## per-bullet behaviour.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var shot := Shots.bullet(Shots.ROUND, Shots.VIOLET)
	shot.appearance.core_size = Vector2(7, 7)
	var rings := 110
	for index in rings:
		# Angular velocity ramps from -k to +k: rocking, accelerating arms.
		var t := float(index) - rings * 0.5
		fire_ring(shot, 5, 105.0, 0.045 * t * t)
		wait(0.055)
	wait(1.4)
	repeat()
