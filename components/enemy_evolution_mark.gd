class_name EnemyEvolutionMark
extends Sprite2D
## Pulsing gold shell behind an evolved enemy so evolved spawns read at a glance.
## Place under the enemy's Anchor; it copies the sibling Core sprite's texture.

const EVOLUTION_COLOR := Color(1.0, 0.78, 0.25)

@export var core_path := NodePath("../Core")
## Shell size relative to the Core sprite.
@export_range(1.0, 3.0, 0.05) var shell_scale := 1.5
@export_range(0.2, 5.0, 0.05, "suffix:s") var pulse_period := 1.2
@export_range(0.0, 1.0, 0.01) var min_alpha := 0.3
@export_range(0.0, 1.0, 0.01) var max_alpha := 0.7

var _time := 0.0


func _ready() -> void:
	show_behind_parent = true
	var core := get_node_or_null(core_path) as Sprite2D
	if core != null:
		texture = core.texture
		offset = core.offset
		rotation = core.rotation
		scale = core.scale * shell_scale
	self_modulate = Color(EVOLUTION_COLOR, min_alpha)


func _process(delta: float) -> void:
	_time += delta
	var wave := 0.5 + 0.5 * sin(TAU * _time / pulse_period)
	self_modulate.a = lerpf(min_alpha, max_alpha, wave)
