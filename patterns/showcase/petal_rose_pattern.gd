extends BarrageSequence
## Showcase: rose petals. Two rings leave together, fly straight briefly, then
## bend 120° in opposite directions so their paths cross into petal shapes.

const Shots := preload("res://labs/bullet/showcase_shots.gd")


func _init() -> void:
	var left := Shots.bullet(
		Shots.ROUND,
		Shots.PINK,
		BulletBehavior.new().wait(0.35).turn_by(120, 1.4).eased(Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	)
	var right := Shots.bullet(
		Shots.ROUND,
		Shots.VIOLET,
		BulletBehavior.new().wait(0.35).turn_by(-120, 1.4).eased(Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	)
	var petals_left := BarrageVolley.new()
	petals_left.shot = left
	petals_left.layout = BarrageVolley.Layout.RING
	petals_left.count = 14
	petals_left.speed = 80.0
	var petals_right := petals_left.duplicate() as BarrageVolley
	petals_right.shot = right
	fire_together([petals_left, petals_right])
	wait(0.9)
	rotate(13)
	repeat()
