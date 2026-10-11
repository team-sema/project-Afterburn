extends BarrageSequence
## Showcase: phantom drift (Touhou-style ghost bullets). A cyan rice fan falls,
## then suddenly goes intangible: it fades to a pale ghost, splits left/right
## and drifts slowly while hits pass through. It then turns solid pink again,
## brakes, re-aims at the target and launches. Opacity is restored before the
## hitbox returns, so the reactivation can be read in time.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const PALE := Color(0.6, 0.7, 0.8)
const FALL_SECONDS := 0.9
const FADE_SECONDS := 0.15
const GHOST_OPACITY := 0.3
const DRIFT_DEGREES := 70.0
const DRIFT_SPEED := 45.0
const DRIFT_SECONDS := 1.1
const SOLIDIFY_SECONDS := 0.3
const DASH_SPEED := 170.0
const HALF_COUNT := 4
const HALF_SPREAD := 30.0
const HALF_OFFSET := 20.0
const SALVO_ANGLES: Array[float] = [-12.0, 0.0, 12.0]
const SALVO_GAP := 0.8


func _init() -> void:
	# Down is 0 degrees and positive angles turn toward screen-left.
	var left := _ghost_shot(DRIFT_DEGREES)
	var right := _ghost_shot(-DRIFT_DEGREES)
	for angle in SALVO_ANGLES:
		var halves: Array[BarrageVolley] = [
			_half_fan(left, angle + HALF_OFFSET),
			_half_fan(right, angle - HALF_OFFSET),
		]
		fire_together(halves)
		wait(SALVO_GAP)
	repeat()


func _ghost_shot(drift_degrees: float) -> BarrageShot:
	var behavior := BulletBehavior.new()
	behavior.wait(FALL_SECONDS)
	behavior.intangible()
	behavior.parallel([
		BulletAction.make(BulletAction.Type.OPACITY, GHOST_OPACITY, FADE_SECONDS),
		BulletAction.tint_to(PALE, FADE_SECONDS),
		BulletAction.make(BulletAction.Type.TURN_TO, drift_degrees, FADE_SECONDS),
		BulletAction.make(BulletAction.Type.SPEED, DRIFT_SPEED, FADE_SECONDS),
	])
	behavior.wait(DRIFT_SECONDS)
	# Solid again before the hitbox returns, stopping so the re-aim reads clearly.
	behavior.parallel([
		BulletAction.make(BulletAction.Type.OPACITY, 1.0, SOLIDIFY_SECONDS),
		BulletAction.tint_to(Shots.PINK, SOLIDIFY_SECONDS),
		BulletAction.make(BulletAction.Type.SPEED, 0.0, SOLIDIFY_SECONDS),
	])
	behavior.tangible()
	behavior.homing(1440.0, 0.2)
	behavior.speed_to(DASH_SPEED, 0.5).eased(Tween.TRANS_QUAD, Tween.EASE_IN)
	return Shots.bullet(Shots.RICE, Shots.CYAN, behavior)


func _half_fan(shot: BarrageShot, angle: float) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.FAN
	volley.count = HALF_COUNT
	volley.spread_degrees = HALF_SPREAD
	volley.angle_degrees = angle
	volley.speed = 110.0
	return volley
