extends Node2D

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
