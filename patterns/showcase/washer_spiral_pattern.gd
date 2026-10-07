extends BarrageSequence
## Showcase: washer spiral. A slow bent-ring spiral reverses its emitter rotation
## and bullet curvature together every few seconds, blending through zero so the
## arms unwind and re-wind the other way like a washing-machine drum. Two thin,
## fast straight arms rotating at different rates give the eye a reference frame.
## Adapted from the "Washer Spiral" family in 『弾幕 最強のシューティングゲームを作る！』.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const RINGS := 60 # One full reversal cycle: 60 rings × 1/6 s = 10 s.
const RING_GAP := 1.0 / 6.0
const STEADY := 25 # Rings at full rate before a reversal starts.
const BLEND := 5 # Rings spent blending from +1 to -1 (the book's 50-frame ramp).
const STEP_DEGREES := 7.2 # Bent-ring rotation per ring at full rate.
const CURVE_DEGREES := 60.0 # Bent-bullet turn rate (deg/s) at full rate.
const BENT_COUNT := 10
const ARM_COUNT := 4
const ARM_SPEED := 200.0


func _init() -> void:
	var arm_cw := Shots.bullet(Shots.ROUND, Shots.YELLOW)
	arm_cw.appearance.core_size = Vector2(6, 6)
	var arm_ccw := Shots.bullet(Shots.ROUND, Shots.YELLOW)
	arm_ccw.appearance.core_size = Vector2(6, 6)
	var bent_angle := 0.0
	for index in RINGS:
		var direction := _direction(index)
		bent_angle += STEP_DEGREES * direction
		fire_together([
			_ring(_bent_shot(direction), BENT_COUNT, 30.0, bent_angle),
			_ring(arm_cw, ARM_COUNT, ARM_SPEED, index * 10.8),
			_ring(arm_ccw, ARM_COUNT, ARM_SPEED, index * -7.2),
		])
		wait(RING_GAP)
	repeat()


## +1 for STEADY rings, a linear ramp to -1 over BLEND rings, -1 for STEADY
## rings, then a ramp back: the book's 250/50/250/50-frame square wave.
static func _direction(index: int) -> float:
	var half := STEADY + BLEND
	var local := index % (half * 2)
	var sign := 1.0 if local < half else -1.0
	local = local % half
	if local < STEADY:
		return sign
	return sign * (1.0 - 2.0 * (local - STEADY + 0.5) / BLEND)


## Bent bullets start slow and accelerate while turning against the emitter's
## rotation; the tint slides from cyan (forward) to pink (reversed).
static func _bent_shot(direction: float) -> BarrageShot:
	var behavior := BulletBehavior.new()
	behavior.parallel([
		BulletAction.make(BulletAction.Type.SPEED, 140.0, 2.5),
		BulletAction.make(BulletAction.Type.TURN_AT, -CURVE_DEGREES * direction, 2.5),
	])
	var tint := Shots.CYAN.lerp(Shots.PINK, (1.0 - direction) * 0.5)
	return Shots.bullet(Shots.ROUND, tint, behavior)


static func _ring(shot: BarrageShot, count: int, speed: float, angle: float) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.RING
	volley.count = count
	volley.speed = speed
	volley.angle_degrees = angle
	return volley
