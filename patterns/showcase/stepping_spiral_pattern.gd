extends BarrageSequence
## Showcase: stepping spiral. A single-arm spiral whose bullets fly for a
## second, freeze white for a third of a second, then go again, so each turn of
## the spiral advances in steps instead of flowing out. One bullet per physics
## tick keeps the arm continuous.
## Adapted from "Stepping" in 『弾幕 最強のシューティングゲームを作る！』.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const SPEED := 108.0
const MOVE_SECONDS := 1.0
const STOP_SECONDS := 1.0 / 3.0
const STEP_DEGREES := 10.8
const TICK := 1.0 / 60.0


func _init() -> void:
	var behavior := BulletBehavior.new()
	behavior.wait(MOVE_SECONDS)
	behavior.speed_to(0.0, 0.0)
	behavior.tint_to(Shots.WHITE, 0.0)
	behavior.wait(STOP_SECONDS)
	behavior.speed_to(SPEED, 0.0)
	behavior.tint_to(Shots.VIOLET, 0.0)
	behavior.repeat()
	var shot := Shots.bullet(Shots.ROUND, Shots.VIOLET, behavior)
	fire(Shots.single(shot, Vector2.DOWN, SPEED))
	rotate(STEP_DEGREES)
	wait(TICK)
	repeat()
