extends BarrageSequence
## Textured needle body with batched glow; schedule remains API-driven.

func _init() -> void:
	var volley := BarrageVolley.new()
	volley.shot = BarrageShot.new()
	volley.shot.appearance = preload("res://resources/projectiles/needle.tres")
	volley.shot.behavior = BulletBehavior.new()
	volley.shot.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
	volley.shot.lifetime = 8.0
	volley.aim = BarrageVolley.Aim.EACH_SHOT
	volley.speed = 105.0
	fire(volley)
	wait(4.5)
	repeat()
