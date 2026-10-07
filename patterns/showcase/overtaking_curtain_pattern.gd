extends BarrageSequence
## Showcase: overtaking curtain. Three muzzles across the field each throw eight
## fans in quick succession, every fan faster than the last, so later fans
## overtake earlier ones and the salvo squeezes into one thick wall before
## spreading out again. The aim is locked once per salvo; tint goes from cyan
## (slowest) to pink (fastest) so the overtaking is visible.
## Adapted from "Overtaking" / "Even Overtaking" in 『弾幕 最強のシューティングゲームを作る！』.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const GROUPS := 8
const GROUP_GAP := 0.08
const BASE_SPEED := 90.0
const SPEED_STEP := 22.0
const FAN_COUNT := 8
const SPREAD_DEGREES := 72.0
const MUZZLE_X: Array[float] = [-120.0, 0.0, 120.0]
const REST_SECONDS := 2.4


func _init() -> void:
	aim()
	for group in GROUPS:
		var tint := Shots.CYAN.lerp(Shots.PINK, float(group) / (GROUPS - 1))
		var shot := Shots.bullet(Shots.ROUND, tint)
		shot.appearance.core_size = Vector2(6, 6)
		var volleys: Array[BarrageVolley] = []
		for x in MUZZLE_X:
			var volley := BarrageVolley.new()
			volley.shot = shot
			volley.layout = BarrageVolley.Layout.FAN
			volley.count = FAN_COUNT
			volley.spread_degrees = SPREAD_DEGREES
			volley.speed = BASE_SPEED + SPEED_STEP * group
			volley.origin_offset = Vector2(x, 0)
			volley.aim = BarrageVolley.Aim.LOCKED
			volleys.append(volley)
		fire_together(volleys)
		wait(GROUP_GAP)
	wait(REST_SECONDS)
	repeat()
