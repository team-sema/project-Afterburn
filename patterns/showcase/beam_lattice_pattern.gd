extends BarrageSequence
## Showcase: beam lattice (telegraphed BEAM). A fan of five pink beams aimed at
## the target flashes thin warning lines, then fires. Right after, a slowly
## turning ring of violet beams cuts the screen into wedges. Every beam shows
## its exact path before it can hit.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var aimed := BarrageVolley.new()
	aimed.shot = Shots.beam(Shots.PINK, 0.8, 0.45, 6.0)
	aimed.layout = BarrageVolley.Layout.FAN
	aimed.count = 5
	aimed.spread_degrees = 64.0
	aimed.speed = 0.0
	aimed.aim = BarrageVolley.Aim.EACH_SHOT

	var ring := BarrageVolley.new()
	ring.shot = Shots.beam(Shots.VIOLET, 1.0, 0.6, 8.0)
	ring.layout = BarrageVolley.Layout.RING
	ring.count = 6
	ring.speed = 0.0

	fire(aimed)
	wait(1.0)
	fire(ring)
	wait(1.9)
	rotate(20)
	repeat()
