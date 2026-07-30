extends Node2D

@export_range(8.0, 120.0, 1.0) var effect_radius := 36.0
@export var effect_color := Color(0.18, 0.82, 1.0)

@onready var glow: Sprite2D = $Glow
@onready var ring: Sprite2D = $Ring


func setup(radius: float, color: Color) -> void:
	effect_radius = radius
	effect_color = color


func _ready() -> void:
	glow.self_modulate = Color(effect_color.r, effect_color.g, effect_color.b, 0.22)
	ring.self_modulate = Color(effect_color.r, effect_color.g, effect_color.b, 0.95)
	glow.scale = Vector2.ONE * 0.08
	ring.scale = Vector2.ONE * 0.04

	var tween := create_tween().set_parallel(true)
	tween.tween_property(glow, "scale", Vector2.ONE * effect_radius / 28.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "self_modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * effect_radius / 47.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "self_modulate:a", 0.0, 0.36).set_delay(0.06)
	await tween.finished
	queue_free()
