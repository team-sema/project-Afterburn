extends BarrageSequence
## Showcase: stop and re-aim (knife-thrower style). A needle ring spreads out,
## brakes to a halt, turns red, snaps toward the target and then launches.
## Uses the Lab target through homing; nothing is aimed at fire time.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var behavior := BulletBehavior.new()
	behavior.speed_to(0.0, 0.7).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)
	behavior.tint_to(Shots.RED, 0.0)
	behavior.homing(1440.0, 0.25)
	behavior.speed_to(185.0, 0.5).eased(Tween.TRANS_QUAD, Tween.EASE_IN)
	var knife := Shots.bullet(Shots.NEEDLE, Shots.WHITE, behavior)
	fire_ring(knife, 20, 150.0)
	wait(1.7)
	rotate(9)
	repeat()
