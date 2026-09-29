extends BarrageSequence
## Showcase: bloom burst. Large orbs drift out and stop, swell and flush white
## as a warning, then burst outward with a slight twist. A fast ring of small
## balls fills the pause.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var behavior := BulletBehavior.new()
	behavior.speed_to(0.0, 0.9).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)
	behavior.parallel([
		BulletAction.tint_to(Shots.WHITE, 0.35),
		BulletAction.visual_scale_to(1.35, 0.35),
	])
	behavior.parallel([
		BulletAction.make(BulletAction.Type.SPEED, 210.0, 1.0),
		BulletAction.turn_by(25.0, 1.0),
	])
	var orb := Shots.bullet(Shots.ORB, Shots.RED, behavior)
	var filler := Shots.bullet(Shots.ROUND, Shots.PINK)
	filler.appearance.core_size = Vector2(6, 6)
	fire_ring(orb, 10, 90.0)
	wait(0.8)
	fire_ring(filler, 30, 130.0, 6.0)
	wait(1.3)
	rotate(18)
	repeat()
