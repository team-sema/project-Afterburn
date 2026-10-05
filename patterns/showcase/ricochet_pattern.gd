extends BarrageSequence
## Showcase: ricochet (wall bounce). Two wide fans of rice bullets fly toward
## the side walls, bounce once and cross back over the middle. A pair of trail
## lasers bends into a V on each side wall. Every bounce is already part of the
## predicted path, so the safety meter sees the return leg early.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var rice := Shots.bullet(Shots.RICE, Shots.YELLOW)
	rice.bounce_walls = BulletWallBounce.SIDES
	rice.bounce_count = 1

	var left_fan := BarrageVolley.new()
	left_fan.shot = rice
	left_fan.layout = BarrageVolley.Layout.FAN
	left_fan.count = 7
	left_fan.spread_degrees = 36.0
	left_fan.angle_degrees = -58.0
	left_fan.speed = 120.0
	var right_fan := left_fan.duplicate() as BarrageVolley
	right_fan.angle_degrees = 58.0

	var laser := Shots.trail_laser(BulletBehavior.new(), 0.9, 6.0)
	laser.bounce_walls = BulletWallBounce.SIDES
	laser.bounce_count = 2
	var lasers := BarrageVolley.new()
	lasers.shot = laser
	lasers.layout = BarrageVolley.Layout.FAN
	lasers.count = 2
	lasers.spread_degrees = 130.0
	lasers.speed = 150.0

	fire_together([left_fan, right_fan])
	wait(0.9)
	fire(lasers)
	wait(1.3)
	rotate(6)
	repeat()
