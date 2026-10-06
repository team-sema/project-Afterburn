extends BarrageSequence
## Scene-configured aimed bursts; activation belongs to EnemyShootComponent.
## `shape` picks the bullet vocabulary: "needle" (aimed single, default),
## "round" (area pressure), "rice" (fast aimed) or "orb" (slow, lingering). `tint` recolours the shape
## (null keeps the preset colour) and `trail` adds the diamond particle trail.

const SHAPES := {
	"needle": preload("res://resources/projectiles/needle.tres"),
	"round": preload("res://resources/projectiles/round.tres"),
	"rice": preload("res://resources/projectiles/rice.tres"),
	"orb": preload("res://resources/projectiles/orb.tres"),
}
const TRAIL := preload("res://resources/projectiles/diamond_trail.tres")


func build(params: Dictionary) -> void:
	var shape := String(params.get("shape", "needle"))
	var appearance: BulletAppearance = SHAPES.get(shape, SHAPES["needle"])
	var tint = params.get("tint", null)
	if tint is Color:
		appearance = appearance.duplicate() as BulletAppearance
		appearance.tint = tint
	var shot := BarrageShot.new()
	shot.appearance = appearance
	shot.behavior = BulletBehavior.new()
	if bool(params.get("trail", shape == "needle")):
		shot.trail_effect = TRAIL
	shot.lifetime = 8.0
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.FAN
	volley.count = int(params.get("ways", 5))
	volley.spread_degrees = float(params.get("spread", 15.0))
	volley.speed = float(params.get("speed", 80.0))
	volley.aim = BarrageVolley.Aim.EACH_SHOT
	var shots := int(params.get("shots", 2))
	for index in shots:
		fire(volley)
		if index < shots - 1:
			wait(float(params.get("gap", 0.15)))
	wait(float(params.get("rest", 4.5)))
	repeat()
