extends BarrageSequence
## Scene-configured aimed bursts; activation belongs to EnemyShootComponent.
## `shape` picks the bullet vocabulary: "needle" (aimed single, default),
## "round" (area pressure), "rice" (fast aimed) or "orb" (slow, lingering). `tint` recolours the shape
## (null keeps the preset colour) and `trail` adds the diamond particle trail.
## Barrage pressure (`pressure`) acts only through the limits a scene names:
## `rest_limit` shortens the rest, `shots_limit` adds shots, and `burst_span`
## keeps the whole burst that long so added shots close up the stream.

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
	var pressure := int(params.get("pressure", 0))
	var shots := int(params.get("shots", 2))
	if params.has("shots_limit"):
		shots = BarragePressure.scale_int(shots, int(params["shots_limit"]), pressure)
	var gap := float(params.get("gap", 0.15))
	if params.has("burst_span") and shots > 1:
		gap = float(params["burst_span"]) / float(shots - 1)
	var rest := float(params.get("rest", 4.5))
	if params.has("rest_limit"):
		rest = BarragePressure.scale(rest, float(params["rest_limit"]), pressure)
	for index in shots:
		fire(volley)
		if index < shots - 1:
			wait(gap)
	wait(rest)
	repeat()
