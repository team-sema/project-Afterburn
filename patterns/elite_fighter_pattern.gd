extends BarrageSequence
## One finite attack phase. Movement, warning and recovery belong to the actor.
## `mode`: "salvo" (default), "rail" or "scissor". `angle` is down = 0.

const NEEDLE := preload("res://resources/projectiles/elite_needle.tres")
const RICE := preload("res://resources/projectiles/rice.tres")
const WHITE := Color(0.95, 0.95, 1.0)
const PINK := Color(1.0, 0.22, 0.52)
const RED := Color(1.0, 0.28, 0.3)
const ORANGE := Color(1.0, 0.55, 0.25)
const POD_OFFSET := Vector2(14.0, 6.0)

func build(params: Dictionary) -> void:
	var angle := float(params.get("angle", 0))
	var extra := int(params.get("extra_shots", 0))
	var min_spread := float(params.get("min_spread", 0))
	match String(params.get("mode", "salvo")):
		"rail": _rail(angle)
		"scissor": _scissor(angle, extra, min_spread)
		_: _salvo(extra, min_spread)


## Pods throw needles up and outward; they brake, turn red and home in.
func _salvo(extra_shots: int, min_spread: float) -> void:
	var behavior := BulletBehavior.new()
	behavior.speed_to(40.0, 0.45).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)
	behavior.tint_to(RED, 0.0)
	behavior.parallel([BulletAction.homing(160.0, 0.9), BulletAction.make(BulletAction.Type.SPEED, 175.0, 0.9)])
	var shot := _shot(NEEDLE, WHITE, behavior, 6.0)
	var pods: Array[BarrageVolley] = []
	for side in [-1.0, 1.0]:
		pods.append(_pod(shot, side, 3 + extra_shots, maxf(40.0, min_spread), 110.0, -115.0 * side))
	for index in 4:
		fire_together(pods)
		if index < 3: wait(0.34)


## A white centre needle and two pink needles that fold back into parallel rails.
func _rail(angle: float) -> void:
	var centre := BarrageVolley.new()
	centre.shot = _shot(NEEDLE, WHITE, BulletBehavior.new(), 6.0)
	centre.speed = 195.0
	centre.angle_degrees = angle
	var volleys: Array[BarrageVolley] = [centre]
	for side in [-1.0, 1.0]:
		var rail := BarrageVolley.new()
		rail.shot = _shot(NEEDLE, PINK, BulletBehavior.new().turn_by(30.0 * side, 0.25), 6.0)
		rail.speed = 195.0
		rail.angle_degrees = angle - 30.0 * side
		volleys.append(rail)
	for index in 10:
		fire_together(volleys)
		if index < 9: wait(0.13)


## Side pods fire outward and their rice bends inward, crossing below the hull.
func _scissor(angle: float, extra_shots: int, min_spread: float) -> void:
	var pods: Array[BarrageVolley] = []
	for side in [-1.0, 1.0]:
		var behavior := BulletBehavior.new().wait(0.2).turn_by(80.0 * side, 1.0).eased(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		pods.append(_pod(_shot(RICE, ORANGE, behavior, 8.0), side, 3 + extra_shots, maxf(14.0, min_spread), 125.0, angle - 40.0 * side))
	for index in 10:
		fire_together(pods)
		if index < 9: wait(0.16)


## `side` -1 is the left pod, +1 the right pod.
func _pod(shot: BarrageShot, side: float, count: int, spread: float, speed: float, angle: float) -> BarrageVolley:
	var pod := BarrageVolley.new()
	pod.shot = shot
	pod.layout = BarrageVolley.Layout.FAN
	pod.count = count
	pod.spread_degrees = spread
	pod.speed = speed
	pod.angle_degrees = angle
	pod.origin_offset = Vector2(POD_OFFSET.x * side, POD_OFFSET.y)
	return pod


func _shot(appearance: BulletAppearance, tint: Color, behavior: BulletBehavior, lifetime: float) -> BarrageShot:
	var shot := BarrageShot.new()
	var look := appearance.duplicate() as BulletAppearance
	look.tint = tint
	shot.appearance = look
	shot.behavior = behavior
	shot.lifetime = lifetime
	return shot
