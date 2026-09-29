extends BarrageSequence
## Showcase: laser whirl. Rings of trail lasers curl into spirals, alternating
## turn direction each burst, with a ring of small balls between them.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var curl_left := Shots.trail_laser(BulletBehavior.new().turn_at(55.0, 4.0))
	var curl_right := Shots.trail_laser(BulletBehavior.new().turn_at(-55.0, 4.0))
	var balls := Shots.bullet(Shots.ROUND, Shots.YELLOW)
	balls.appearance.core_size = Vector2(6, 6)
	fire_ring(curl_left, 6, 72.0)
	wait(0.6)
	fire_ring(balls, 18, 90.0, 10.0)
	wait(0.9)
	fire_ring(curl_right, 6, 72.0, 30.0)
	wait(0.6)
	fire_ring(balls, 18, 90.0, 10.0)
	wait(0.9)
	repeat()
