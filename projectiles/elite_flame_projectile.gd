extends "res://projectiles/base_enemy_projectile.gd"

var _age := 0.0


func _ready() -> void:
	super._ready()
	$Sprite2D.hide()
	$Sprite2D/Trail.emitting = false


func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.9:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var flicker := sin(_age * 48.0) * 1.5
	var alpha := 1.0 - smoothstep(0.55, 0.9, _age)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(-4, 1), Vector2(flicker - 2, 8), Vector2(flicker, 16), Vector2(4, 2)]), Color(1.0, 0.22, 0.32, 0.7 * alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(-2, 1), Vector2(flicker * 0.5, 8), Vector2(2, 1)]), Color(1.0, 0.92, 0.94, alpha))
