extends BarrageSequence
## Showcase: winder. Two side muzzles each stream a six-bullet ring so fast
## that the bullets read as solid rays; the rays sweep ±30° in opposite phase,
## so the two sets of rays wind against each other like windscreen wipers and
## the safe corridors between them keep opening and closing.
## Adapted from "Winder" in 『弾幕 最強のシューティングゲームを作る！』.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const CYCLE_SECONDS := 5.0
const TICK := 0.05
const SWING_DEGREES := 30.0
const RAYS := 6
const SPEED := 260.0
const MUZZLE := Vector2(80, 90) # Mirrored left/right, below the emitter.


func _init() -> void:
	var left := Shots.bullet(Shots.RICE, Shots.CYAN)
	var right := Shots.bullet(Shots.RICE, Shots.PINK)
	var ticks := int(CYCLE_SECONDS / TICK)
	for index in ticks:
		var swing := SWING_DEGREES * sin(TAU * index / ticks)
		fire_together([
			_ring(left, Vector2(-MUZZLE.x, MUZZLE.y), -swing),
			_ring(right, MUZZLE, swing),
		])
		wait(TICK)
	repeat()


static func _ring(shot: BarrageShot, offset: Vector2, angle: float) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.RING
	volley.count = RAYS
	volley.speed = SPEED
	volley.angle_degrees = angle
	volley.origin_offset = offset
	return volley
