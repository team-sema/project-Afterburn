extends BarrageSequence
## Showcase: wavy curtain. Wide rice fans sway sideways in a continuous wave;
## every other row starts half a period out of phase, so gaps drift and the
## player has to weave through them.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var even := Shots.bullet(Shots.RICE, Shots.CYAN, BulletBehavior.new().lateral_wave(16.0, 1.3).repeat())
	var odd := Shots.bullet(Shots.RICE, Shots.GREEN, BulletBehavior.new().lateral_wave(16.0, 1.3, PI).repeat())
	fire_fan(even, 17, 150.0, 70.0)
	wait(0.4)
	fire_fan(odd, 16, 150.0, 70.0)
	wait(0.4)
	repeat()
