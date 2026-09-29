extends BarrageSequence
## Showcase: expanding star. Bullets are placed along a five-point star outline
## and each flies at a speed proportional to its distance from the centre, so
## the whole shape grows without deforming. Alternate stars turn 36°.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const POINTS := 5
const PER_EDGE := 6
const OUTER := 1.0
const INNER := 0.42
const SPEED := 110.0


func _init() -> void:
	var gold := Shots.bullet(Shots.ROUND, Shots.YELLOW)
	var green := Shots.bullet(Shots.ROUND, Shots.GREEN)
	fire_together(_star(gold))
	wait(1.1)
	rotate(36)
	fire_together(_star(green))
	wait(1.1)
	rotate(36)
	repeat()


func _star(shot: BarrageShot) -> Array[BarrageVolley]:
	var corners: Array[Vector2] = []
	for index in POINTS * 2:
		var radius := OUTER if index % 2 == 0 else INNER
		corners.append(Vector2.DOWN.rotated(TAU * index / (POINTS * 2)) * radius)
	var volleys: Array[BarrageVolley] = []
	for index in corners.size():
		var from := corners[index]
		var to := corners[(index + 1) % corners.size()]
		for step in PER_EDGE:
			var point := from.lerp(to, float(step) / PER_EDGE)
			volleys.append(Shots.single(shot, point, SPEED * point.length()))
	return volleys
