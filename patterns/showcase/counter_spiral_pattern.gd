extends BarrageSequence
## Showcase: counter-rotating double spiral. Two coloured arms fire together
## each step, one turning clockwise and one counter-clockwise, weaving a lattice.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var cw := Shots.bullet(Shots.RICE, Shots.CYAN)
	var ccw := Shots.bullet(Shots.RICE, Shots.PINK)
	for index in 100:
		var turn := index * 11.0
		fire_together([_ring(cw, turn), _ring(ccw, -turn)])
		wait(0.07)
	wait(1.0)
	repeat()


func _ring(shot: BarrageShot, angle: float) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.RING
	volley.count = 4
	volley.speed = 95.0
	volley.angle_degrees = angle
	return volley
