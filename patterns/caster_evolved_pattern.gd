extends BarrageSequence
## Evolved Caster: two rings per beat that spin in opposite directions.
## Rounds, no trail; the forward ring stays pink and the backward ring is
## violet so the two lanes can be told apart while they cross.

const ROUND := preload("res://resources/projectiles/round.tres")
const PINK := Color(1.0, 0.22, 0.52)
const VIOLET := Color(0.7, 0.42, 1.0)


func build(params: Dictionary) -> void:
	var forward_shot := _shot(PINK)
	var backward_shot := _shot(VIOLET)
	var rings := int(params.get("rings", 5))
	var count := int(params.get("count", 12))
	var speed := float(params.get("speed", 95.0))
	var spin := float(params.get("spin", 9.0))
	# The second ring starts half a gap over so the two rings never overlap.
	var half_gap := 180.0 / float(maxi(1, count))
	for index in rings:
		var forward := BarrageVolley.new()
		forward.shot = forward_shot
		forward.layout = BarrageVolley.Layout.RING
		forward.count = count
		forward.speed = speed
		forward.angle_degrees = -90.0 + index * spin
		var backward := BarrageVolley.new()
		backward.shot = backward_shot
		backward.layout = BarrageVolley.Layout.RING
		backward.count = count
		backward.speed = speed
		backward.angle_degrees = -90.0 + half_gap - index * spin
		var pair: Array[BarrageVolley] = [forward, backward]
		fire_together(pair)
		if index < rings - 1:
			wait(float(params.get("gap", 0.1)))
	wait(float(params.get("rest", 4.8)))
	repeat()


func _shot(tint: Color) -> BarrageShot:
	var look := ROUND.duplicate() as BulletAppearance
	look.tint = tint
	var shot := BarrageShot.new()
	shot.appearance = look
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 8.0
	return shot
