extends BarrageSequence
## Halting needle (정지탄 드론): the needle flies a short way, brakes to a stop
## in front of the drone, turns red as the warning, snaps toward the target and
## dashes. The lesson is Sniper's: moving before the launch does nothing,
## dodge after it commits. pattern_params: speed, hold, dash_speed, rest.

const NEEDLE := preload("res://resources/projectiles/needle.tres")
const TRAIL := preload("res://resources/projectiles/diamond_trail.tres")
const WARNING_RED := Color(1.0, 0.3, 0.32)


func build(params: Dictionary) -> void:
	var behavior := BulletBehavior.new()
	behavior.speed_to(0.0, 0.3).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)
	behavior.wait(float(params.get("hold", 0.4)))
	behavior.tint_to(WARNING_RED, 0.0)
	behavior.wait(0.15)
	behavior.homing(1440.0, 0.12)
	behavior.speed_to(float(params.get("dash_speed", 190.0)), 0.2).eased(Tween.TRANS_QUAD, Tween.EASE_IN)
	var shot := BarrageShot.new()
	shot.appearance = NEEDLE
	shot.behavior = behavior
	shot.trail_effect = TRAIL
	shot.lifetime = 8.0
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.aim = BarrageVolley.Aim.EACH_SHOT
	volley.speed = float(params.get("speed", 120.0))
	fire(volley)
	wait(float(params.get("rest", 4.5)))
	repeat()
