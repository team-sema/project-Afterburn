class_name SniperLaserBeam
extends Node2D

## World-anchored sniper laser. Beam starts at the sniper origin and does not track.

signal finished

@export_range(0.05, 5.0, 0.05) var duration := 0.5
@export_range(1.0, 24.0, 0.5) var laser_width := 4.0
@export_range(32.0, 800.0, 1.0) var laser_range := 480.0
@export_range(1, 20, 1) var laser_damage := 1
@export var core_color := Color(1.0, 0.85, 0.65, 1.0)
@export var glow_color := Color(1.0, 0.35, 0.12, 0.7)

var _elapsed := 0.0
var _active := false
var _origin := Vector2.ZERO
var _direction := Vector2.DOWN
var _configured := false
var _core: Line2D
var _glow: Line2D
var _core_streak: Sprite2D
var _glow_streak: Sprite2D
var _hitbox: HitboxComponent
var _collision: CollisionShape2D
var _shape: RectangleShape2D


func configure(
	origin: Vector2,
	direction: Vector2,
	p_duration: float,
	p_width: float,
	p_range: float,
	p_damage: int,
) -> void:
	_origin = origin
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.DOWN
	duration = maxf(0.05, p_duration)
	laser_width = maxf(1.0, p_width)
	laser_range = maxf(8.0, p_range)
	laser_damage = maxi(1, p_damage)
	_configured = true
	if is_node_ready():
		_apply_configure()


func _ready() -> void:
	_glow = Line2D.new()
	_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.antialiased = true
	add_child(_glow)

	_core = Line2D.new()
	_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	_core.antialiased = true
	add_child(_core)

	var streak := load("res://assets/svg/particle_streak.svg") as Texture2D
	var additive := load("res://effects/additive_unshaded_material.tres") as Material
	if streak != null:
		_glow_streak = Sprite2D.new()
		_glow_streak.texture = streak
		_glow_streak.material = additive
		# Tip of the streak sits on the sniper; beam grows along +Y.
		_glow_streak.centered = false
		_glow_streak.offset = Vector2(-streak.get_width() * 0.5, 0.0)
		add_child(_glow_streak)

		_core_streak = Sprite2D.new()
		_core_streak.texture = streak
		_core_streak.material = additive
		_core_streak.centered = false
		_core_streak.offset = Vector2(-streak.get_width() * 0.5, 0.0)
		add_child(_core_streak)

	_shape = RectangleShape2D.new()
	_hitbox = HitboxComponent.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 1 # player_hurtbox
	_hitbox.monitoring = true
	_hitbox.monitorable = false
	_collision = CollisionShape2D.new()
	_collision.shape = _shape
	_hitbox.add_child(_collision)
	add_child(_hitbox)

	if _configured:
		_apply_configure()
	_active = true


func _apply_configure() -> void:
	global_position = _origin
	rotation = _direction.angle() - PI * 0.5
	if _hitbox != null:
		_hitbox.damage = laser_damage
	if _shape != null:
		_shape.size = Vector2(maxf(2.0, laser_width), laser_range)
	if _collision != null:
		# Shape grows from the sniper along +Y (not centered mid-beam).
		_collision.position = Vector2(0.0, laser_range * 0.5)
	_update_visual(1.0)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	_update_visual(1.0 - t)
	if _elapsed >= duration:
		_finish()


func _update_visual(alpha: float) -> void:
	var a := clampf(alpha, 0.0, 1.0)
	# Local +Y beam starts at (0,0) = sniper world origin after transform.
	var end := Vector2(0.0, laser_range)
	if _glow != null:
		_glow.points = PackedVector2Array([Vector2.ZERO, end])
		_glow.width = laser_width * 2.6 * (0.55 + 0.45 * a)
		var glow := glow_color
		glow.a = glow_color.a * a
		_glow.default_color = glow
	if _core != null:
		_core.points = PackedVector2Array([Vector2.ZERO, end])
		_core.width = laser_width * (0.7 + 0.3 * a)
		var core := core_color
		core.a = core_color.a * a
		_core.default_color = core

	var tex_h := 16.0
	if _core_streak != null and _core_streak.texture != null:
		tex_h = float(_core_streak.texture.get_height())
	var length_scale := laser_range / maxf(1.0, tex_h)
	var width_scale := laser_width / 4.0
	if _glow_streak != null:
		_glow_streak.position = Vector2.ZERO
		_glow_streak.scale = Vector2(width_scale * 1.8, length_scale)
		var glow_mod := Color(1.0, 0.3, 0.1, 0.55 * a)
		_glow_streak.self_modulate = glow_mod
	if _core_streak != null:
		_core_streak.position = Vector2.ZERO
		_core_streak.scale = Vector2(width_scale * 0.7, length_scale)
		var core_mod := core_color
		core_mod.a = core_color.a * a
		_core_streak.self_modulate = core_mod


func _finish() -> void:
	if not _active:
		return
	_active = false
	if _hitbox != null:
		_hitbox.monitoring = false
	finished.emit()
	queue_free()
