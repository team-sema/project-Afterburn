extends Node2D

## ring.svg draws a radius-47 circle and the explode animation peaks at 0.23 scale.
const RING_SOURCE_RADIUS := 47.0
const RING_PEAK_SCALE := 0.23

@export var effect_color := Color("ff3f8f")

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_apply_effect_color()
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(&"explode")
	animation_player.advance(0.0)


func set_effect_color(color: Color) -> void:
	effect_color = color
	if is_node_ready():
		_apply_effect_color()


func set_effect_radius(radius: float) -> void:
	var source_peak_radius := RING_SOURCE_RADIUS * RING_PEAK_SCALE
	var radius_scale := maxf(0.0, radius) / source_peak_radius
	scale = Vector2.ONE * radius_scale


func get_effect_radius() -> float:
	return RING_SOURCE_RADIUS * RING_PEAK_SCALE * absf(scale.x)


func _apply_effect_color() -> void:
	$GlowSprite.self_modulate = _with_alpha(effect_color, 0.35)
	$RingSprite.self_modulate = _with_alpha(effect_color, 0.8)
	$StreakParticles.self_modulate = effect_color
	$SparkParticles.self_modulate = effect_color
	$DebrisParticles.self_modulate = effect_color


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"explode":
		queue_free()


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
