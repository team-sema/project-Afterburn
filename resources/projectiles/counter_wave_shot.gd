extends BarrageShot
## Hit/death retaliation: a small orange round with a direction-relative wave.

func _init() -> void:
	lifetime = 8.0
	appearance = BulletAppearance.new()
	appearance.collision_radius = 4.0
	appearance.collision_height = 8.0
	appearance.core_size = Vector2(8, 8)
	appearance.tint = Color(1, 0.25, 0.06)
	behavior = BulletBehavior.new().lateral_wave(4.0, 1.0).repeat()
	trail_effect = preload("res://resources/projectiles/diamond_trail.tres").duplicate() as BulletTrailEffect
	trail_effect.color = Color(1, 0.28, 0.06, 0.7)
	trail_effect.end_color = Color(0.8, 0.08, 0.02, 0)
