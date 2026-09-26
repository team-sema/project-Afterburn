class_name CurvedLaser
extends Node2D

const SEGMENTS := 36
const BATCH_RENDERER = preload("res://projectiles/projectile_batch_renderer.gd")
@export var use_batched_rendering := true
const LASER_HITBOX := preload("res://projectiles/curved_laser_hitbox.gd")

@export var behavior: BulletBehavior
@export var trail_effect: BulletTrailEffect
var _trail: BulletTrailEmitter
var behavior_state: BulletBehaviorState
var visual_scale := 1.0
var hitbox_scale := 1.0
var render_tint := Color.WHITE
var render_opacity := 1.0
# Legacy scene inputs; used only if no Behavior is supplied.
@export var turn_degrees := 70.0
@export var turn_duration := 1.5
@export var trail_duration := 1.4
@export var core_width := 6.0
@export var hit_width := 4.0
@export var lifetime := 5.0
@export var show_hitbox := false:
	set(value):
		show_hitbox = value
		queue_redraw()

var age := 0.0
var _origin := Vector2.ZERO
var _direction := Vector2.DOWN
var _speed := 90.0
var _active := false
var _seen := false
var _hitbox: HitboxComponent
var _collisions: Array[CollisionShape2D] = []
var _body := PackedVector2Array()
var _ribbon_offsets := PackedVector2Array()
var _profile := PackedFloat32Array()


func _ready() -> void:
	for index in range(SEGMENTS + 1):
		_profile.append(maxf(0.08, pow(sin(PI * float(index) / SEGMENTS), 0.55)) * 0.5)
	_hitbox = LASER_HITBOX.new()
	_hitbox.name = "HitboxComponent"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 1
	for index in SEGMENTS:
		var collision := CollisionShape2D.new()
		collision.shape = CapsuleShape2D.new()
		collision.disabled = true
		_collisions.append(collision)
		_hitbox.add_child(collision)
	add_child(_hitbox)
	if use_batched_rendering:
		BATCH_RENDERER.register(self)
	set_physics_process(false)


func launch(direction: Vector2, speed: float) -> void:
	if (
		not direction.is_finite() or direction.is_zero_approx()
		or not is_finite(speed) or speed <= 0
		or not is_finite(turn_degrees) or not is_finite(turn_duration) or turn_duration < 0
		or not is_finite(trail_duration) or trail_duration <= 0
		or not is_finite(core_width) or core_width <= 0
		or not is_finite(hit_width) or hit_width <= 0 or hit_width > core_width
		or not is_finite(lifetime) or lifetime <= 0
	):
		push_error("CurvedLaser requires valid finite motion and width settings.")
		queue_free()
		return
	if behavior == null:
		behavior = BulletBehavior.new().turn_at(turn_degrees, turn_duration)
	if not behavior.validation_error().is_empty():
		push_error(behavior.validation_error())
		queue_free()
		return
	_origin = global_position
	if trail_effect != null:
		if not trail_effect.is_valid() or not get_parent() is Node2D:
			push_error("Trail requires valid settings and a Node2D world.")
			queue_free()
			return
		_trail = BulletTrailEmitter.new(get_parent(), trail_effect, _origin)
	_direction = direction.normalized()
	_speed = speed
	behavior_state = BulletBehaviorState.new(behavior, _direction, speed, Color.WHITE, lifetime)
	age = 0
	_active = true
	_seen = false
	for index in SEGMENTS:
		(_collisions[index].shape as CapsuleShape2D).radius = hit_width * 0.5 * width_factor(index)
	_update_body()
	set_physics_process(true)


func position_at(time: float) -> Vector2:
	return _origin + behavior_state.position_at(time)


func body_at(time: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var tail_time := maxf(0, time - trail_duration)
	for index in range(SEGMENTS + 1):
		points.append(position_at(lerpf(tail_time, time, float(index) / SEGMENTS)))
	return points


func width_factor(index: int) -> float:
	# Rounded, tapered ends; collision follows the same profile as the core.
	return maxf(0.08, pow(sin(PI * (float(index) + 0.5) / SEGMENTS), 0.55))


func _physics_process(delta: float) -> void:
	if not _active:
		return
	age = minf(age + delta, lifetime)
	_update_body()
	if _trail != null: _trail.advance(global_position, delta)
	_hitbox.call("apply_contacts")
	var visible := false
	var bounds := get_viewport_rect().grow(core_width * visual_scale * 2)
	for point in _body:
		if bounds.has_point(point):
			visible = true
			_seen = true
			break
	if age >= lifetime or (_seen and not visible):
		_active = false
		queue_free()


func _update_body() -> void:
	behavior_state.advance_to(age)
	var state := behavior_state.sample(age)
	visual_scale = state.visual_scale
	hitbox_scale = state.hitbox_scale
	render_tint = state.tint
	render_opacity = state.opacity
	global_position = position_at(age)
	_body = body_at(age)
	_ribbon_offsets.resize(_body.size())
	for index in _body.size():
		var before := _body[maxi(0, index - 1)]
		var after := _body[mini(_body.size() - 1, index + 1)]
		_ribbon_offsets[index] = (after - before).normalized().orthogonal() * _profile[index]
	var inverse := global_transform.affine_inverse()
	for index in SEGMENTS:
		var start := inverse * _body[index]
		var end := inverse * _body[index + 1]
		var collision := _collisions[index]
		if collision.disabled != (age <= 0.001):
			collision.disabled = age <= 0.001
		collision.position = (start + end) * 0.5
		collision.rotation = (end - start).angle() - PI * 0.5
		var capsule := collision.shape as CapsuleShape2D
		var radius := hit_width * 0.5 * width_factor(index) * hitbox_scale
		if not is_equal_approx(capsule.radius, radius):
			capsule.radius = radius
		capsule.height = start.distance_to(end) + capsule.radius * 2
	if not use_batched_rendering:
		queue_redraw()


func get_travel_velocity() -> Vector2:
	return behavior_state.velocity_at(age)


func get_hazard_radius() -> float:
	return hit_width * 0.5 * (behavior_state.max_hitbox_scale(lifetime) if behavior_state != null else 1.0)


func get_predicted_path(seconds: float) -> PackedVector2Array:
	if not _active or is_queued_for_deletion():
		return PackedVector2Array()
	# The swept body is a contiguous interval of the same stored trajectory:
	# current tail through future head. Include the body already behind the head.
	var start := maxf(0, age - trail_duration)
	var end := minf(lifetime, age + maxf(seconds, 0))
	var count := maxi(1, ceili((end - start) / behavior_state.prediction_step))
	var points := PackedVector2Array()
	for index in range(count + 1):
		points.append(position_at(lerpf(start, end, float(index) / count)))
	return points


func _draw() -> void:
	if use_batched_rendering:
		return
	if age <= 0.001 or _body.size() < 2:
		return
	_draw_ribbon(core_width * 2.6, Color(1, 0.4, 0.03, 0.12))
	_draw_ribbon(core_width * 1.5, Color(1, 0.75, 0.12, 0.55))
	_draw_ribbon(core_width, Color(1, 0.98, 0.66))
	if show_hitbox:
		for index in SEGMENTS:
			draw_set_transform(_collisions[index].position, _collisions[index].rotation)
			_collisions[index].shape.draw(get_canvas_item(), Color(0.1, 1, 0.65, 0.65))
		draw_set_transform(Vector2.ZERO)


func _draw_ribbon(width: float, color: Color) -> void:
	width *= visual_scale
	color *= render_tint
	color.a *= render_opacity
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for index in _body.size():
		var before := _body[maxi(0, index - 1)]
		var after := _body[mini(_body.size() - 1, index + 1)]
		var normal := (after - before).normalized().orthogonal()
		var factor := maxf(0.08, pow(sin(PI * float(index) / SEGMENTS), 0.55))
		var point := to_local(_body[index])
		left.append(point + normal * width * factor * 0.5)
		right.append(point - normal * width * factor * 0.5)
	right.reverse()
	left.append_array(right)
	draw_colored_polygon(left, color)
