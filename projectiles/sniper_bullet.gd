class_name SniperBullet
extends Node2D

## Fast, world-directed sniper round. It never tracks after launch.

signal finished

@export_range(100.0, 2000.0, 10.0) var speed := 900.0
@export_range(1.0, 12.0, 0.5) var bullet_width := 3.0
@export_range(32.0, 800.0, 1.0) var max_range := 480.0
@export_range(1, 20, 1) var damage := 1
@export_range(4.0, 48.0, 1.0) var trail_length := 24.0
@export var core_color := Color(1.0, 0.92, 0.82, 1.0)
@export var trail_color := Color(1.0, 0.16, 0.1, 0.72)

var _direction := Vector2.DOWN
var _travelled := 0.0
var _active := false
var _core: Line2D
var _trail: Line2D
var _hitbox: HitboxComponent
var _collision: CollisionShape2D
var _shape: RectangleShape2D


func _ready() -> void:
	z_index = 12
	_create_visuals()
	_create_hitbox()
	set_physics_process(false)


func configure(
	origin: Vector2,
	direction: Vector2,
	p_speed: float,
	p_width: float,
	p_range: float,
	p_damage: int,
) -> void:
	global_position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.DOWN
	rotation = _direction.angle() - PI * 0.5
	speed = maxf(100.0, p_speed)
	bullet_width = maxf(1.0, p_width)
	max_range = maxf(8.0, p_range)
	damage = maxi(1, p_damage)
	_travelled = 0.0
	_apply_configuration()
	_active = true
	set_physics_process(true)


func get_direction() -> Vector2:
	return _direction


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var step := minf(speed * delta, max_range - _travelled)
	global_position += _direction * step
	_travelled += step
	if _travelled >= max_range:
		_finish()


func _create_visuals() -> void:
	var additive := load("res://effects/additive_unshaded_material.tres") as Material
	_trail = Line2D.new()
	_trail.material = additive
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.antialiased = true
	add_child(_trail)

	_core = Line2D.new()
	_core.material = additive
	_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	_core.antialiased = true
	add_child(_core)


func _create_hitbox() -> void:
	_shape = RectangleShape2D.new()
	_hitbox = HitboxComponent.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 1 # player_hurtbox
	_hitbox.monitoring = true
	_hitbox.monitorable = false
	_hitbox.hit_hurtbox.connect(_on_hit_hurtbox)
	_collision = CollisionShape2D.new()
	_collision.shape = _shape
	_hitbox.add_child(_collision)
	add_child(_hitbox)


func _apply_configuration() -> void:
	if _trail != null:
		_trail.points = PackedVector2Array([Vector2(0.0, -trail_length), Vector2(0.0, 4.0)])
		_trail.width = bullet_width * 2.4
		_trail.default_color = trail_color
	if _core != null:
		_core.points = PackedVector2Array([
			Vector2(0.0, -trail_length * 0.45),
			Vector2(0.0, 5.0),
		])
		_core.width = bullet_width
		_core.default_color = core_color
	if _hitbox != null:
		_hitbox.damage = damage
	if _shape != null:
		# A slightly long shape keeps the high-speed round reliable at 60 Hz.
		_shape.size = Vector2(maxf(2.0, bullet_width), maxf(18.0, speed / 30.0))


func _on_hit_hurtbox(_hurtbox: HurtboxComponent) -> void:
	_finish()


func _finish() -> void:
	if not _active:
		return
	_active = false
	set_physics_process(false)
	if _hitbox != null:
		_hitbox.monitoring = false
	finished.emit()
	queue_free()
