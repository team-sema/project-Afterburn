extends BarrageShot
## Approximation of the legacy flame using the existing textured body and trail.

func _init() -> void:
	lifetime = 0.9
	appearance = BulletAppearance.new()
	appearance.form = BulletAppearance.Form.TEXTURED
	appearance.texture = preload("res://assets/svg/elite_flame_bullet.svg")
	appearance.core_size = Vector2(12, 28)
	appearance.wide_size = Vector2(14, 30)
	appearance.tight_size = Vector2(12, 28)
	appearance.tint = Color.WHITE
	appearance.core_color = Color.WHITE
	appearance.wide_color = Color(1, 0.08, 0.15, 0.08)
	appearance.tight_color = Color(1, 0.2, 0.3, 0.18)
	appearance.collision_size = Vector2(4, 8)
	behavior = BulletBehavior.new().wait(0.55).opacity_to(0, 0.35).eased(Tween.TRANS_SINE)
	trail_effect = BulletTrailEffect.new()
	trail_effect.texture = preload("res://assets/svg/particle_diamond.svg")
	trail_effect.spacing = 1.5
	trail_effect.lifetime = 0.18
	trail_effect.size = 3.0
	trail_effect.end_size = 0.2
	trail_effect.speed_min = 8.0
	trail_effect.speed_max = 22.0
	trail_effect.spread_degrees = 20.0
	trail_effect.color = Color(1, 0.25, 0.32, 0.65)
	trail_effect.end_color = Color(0.8, 0.04, 0.12, 0)
