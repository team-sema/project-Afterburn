class_name SingularityLens
extends Node2D

## Screen-warping lens for the plasma singularity (plasma-bomb.md 특이점).
## Lives beside the bomb (not under it) so the collapse wave can play after the
## bomb is freed. Runs on _process delta, so tree pause freezes it.

const SHADER := preload("res://effects/singularity_lens.gdshader")
const Z_INDEX := 30
const RAMP_TIME := 0.3
const COLLAPSE_TIME := 0.45
const KICK := 0.25
const KICK_DECAY := 2.5
const SPIN_SPEED := 6.0

## Lens radius in px (the pull radius).
var radius := 80.0
var horizon_px := 5.0
var _source: WeakRef
var _material: ShaderMaterial
var _age := 0.0
var _kick := 0.0
var _spin := 0.0
## Seconds left in the collapse wave; negative while the singularity holds.
var _collapse_left := -1.0


func setup(p_radius: float, source: Node) -> void:
	radius = maxf(8.0, p_radius)
	_source = weakref(source)


func _ready() -> void:
	z_index = Z_INDEX
	z_as_relative = false
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.scale = Vector2.ONE * radius * 2.0 / 4.0
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	sprite.material = _material
	add_child(sprite)
	_apply(0.0, horizon_px, 0.0, 0.0)


func set_horizon(px: float) -> void:
	horizon_px = px


## A swallowed bullet makes the lens flinch.
func kick() -> void:
	_kick = minf(_kick + KICK, KICK * 2.0)


func collapse() -> void:
	if _collapse_left < 0.0:
		_collapse_left = COLLAPSE_TIME


func is_collapsing() -> bool:
	return _collapse_left >= 0.0


func get_strength() -> float:
	return float(_material.get_shader_parameter(&"strength")) if _material != null else 0.0


func _process(delta: float) -> void:
	_age += delta
	_spin += delta * SPIN_SPEED
	_kick = maxf(0.0, _kick - delta * KICK_DECAY)
	if _collapse_left < 0.0:
		if _source == null or _source.get_ref() == null:
			# The bomb vanished without collapsing (e.g. world cleared).
			collapse()
		else:
			_apply(minf(1.0, _age / RAMP_TIME) + _kick, horizon_px, 0.0, 0.0)
			return
	_collapse_left -= delta
	var t := clampf(1.0 - _collapse_left / COLLAPSE_TIME, 0.0, 1.0)
	# The hole caves in while the wave runs out to the rim.
	_apply((1.0 - t) * (1.0 - t), horizon_px * (1.0 - t), t, 1.0 - t)
	if _collapse_left <= 0.0:
		queue_free()


func _apply(strength: float, horizon: float, shock_radius: float, shock_strength: float) -> void:
	_material.set_shader_parameter(&"strength", strength)
	_material.set_shader_parameter(&"horizon", horizon / radius)
	_material.set_shader_parameter(&"spin", _spin)
	_material.set_shader_parameter(&"shock_radius", shock_radius)
	_material.set_shader_parameter(&"shock_strength", shock_strength)
