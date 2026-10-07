extends BarrageSequence
## Showcase: placed star. Bullets are laid one by one along a pentagram outline
## and sit still until the whole shape is drawn, then flash red together and all
## launch at once, each twisted 144° from its radial so the star swirls in
## through its own centre and out the other side. A second, larger star is drawn
## at the same time, rotated 36° and spun the other way. Each bullet's wait is
## the time left until the shared launch.
## Adapted from "Star Placed" in 『弾幕 最強のシューティングゲームを作る！』.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const PER_LINE := 10
const DRAW_GAP := 1.0 / 30.0 # 50 bullets per star in 1.67 s.
const HOLD_SECONDS := 0.5 # Finished shape stays still before launching.
const WARN_SECONDS := 0.25 # Red flash before launch.
const CENTER := Vector2(0, 110) # Star centre relative to the emitter.
## Pentagram corners in draw order (the book's x/y tables), unit radius.
const CORNERS: Array[Vector2] = [
	Vector2(0.0, -1.0), Vector2(0.59, 0.81), Vector2(-0.95, -0.31),
	Vector2(0.95, -0.31), Vector2(-0.59, 0.81), Vector2(0.0, -1.0),
]


func _init() -> void:
	var total := (CORNERS.size() - 1) * PER_LINE
	for index in total:
		var remaining := (total - index) * DRAW_GAP + HOLD_SECONDS
		fire_together([
			_placed(index, Shots.YELLOW, 0.0, 50.0, 144.0, 100.0, remaining),
			_placed(index, Shots.CYAN, 36.0, 80.0, -144.0, 150.0, remaining),
		])
		wait(DRAW_GAP)
	wait(2.0)
	repeat()


## One stationary bullet on the outline that launches after `remaining` seconds.
static func _placed(
	index: int, tint: Color, star_angle: float, size: float,
	twist: float, speed: float, remaining: float,
) -> BarrageVolley:
	@warning_ignore("integer_division")
	var line := index / PER_LINE
	var along := float(index % PER_LINE) / PER_LINE
	var point := CORNERS[line].lerp(CORNERS[line + 1], along).rotated(deg_to_rad(star_angle)) * size
	var behavior := BulletBehavior.new()
	behavior.wait(remaining - WARN_SECONDS)
	behavior.tint_to(Shots.RED, WARN_SECONDS)
	behavior.speed_to(speed, 0.0)
	behavior.tint_to(tint, 0.3)
	var shot := Shots.bullet(Shots.ROUND, tint, behavior)
	var volley := Shots.single(shot, point.rotated(deg_to_rad(twist)), 0.0)
	volley.origin_offset = CENTER + point
	return volley
