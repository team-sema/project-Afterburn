class_name CurvedLaser
extends Node2D

const SEGMENTS := 36
const BATCH_RENDERER = preload("res://projectiles/projectile_batch_renderer.gd")
@export var use_batched_rendering := true
const DEBUG_COLOR := Color(0.1, 1, 0.65, 0.65)

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

## Set by BarrageShot.spawn when the behavior is the firing Player's private,
## already validated copy: share it instead of copying and re-validating.
var shares_config := false
var age := 0.0
var _origin := Vector2.ZERO
var _direction := Vector2.DOWN
var _speed := 90.0
var _active := false
var _seen := false
var _static_visuals := false
## Shape-less HitboxComponent handed to hurtboxes as the damage source; the
## body is tested on the CPU against EnemyBullets.TARGET_GROUP every tick.
var _hitbox: HitboxComponent
var _targets: Array[EnemyBulletPool.Target] = []
var _body := PackedVector2Array()
var _ribbon_offsets := PackedVector2Array()
var _profile := PackedFloat32Array()
## Wall reflection (BarrageShot.bounce_walls / bounce_count); null = none.
var bounce_walls := 0
var bounce_count := 1
var _bounce: BulletWallBounce


func _ready() -> void:
	for index in range(SEGMENTS + 1):
		_profile.append(maxf(0.08, pow(sin(PI * float(index) / SEGMENTS), 0.55)) * 0.5)
	_hitbox = HitboxComponent.new()
	_hitbox.name = "HitboxComponent"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	_hitbox.monitorable = false
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
	if not shares_config and not behavior.validation_error().is_empty():
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
	# A shared behavior is the Player's validated, read-only copy; adopt it.
	behavior_state = BulletBehaviorState.new(behavior, _direction, speed, Color.WHITE, lifetime, not shares_config)
	if bounce_walls != 0:
		_bounce = BulletWallBounce.new(
			func(time: float) -> Vector2: return _origin + behavior_state.position_at(time),
			get_viewport_rect(), hit_width * 0.5, bounce_walls, bounce_count, lifetime)
	age = 0
	_active = true
	_seen = false
	# The first update runs the full path; later ticks skip constant visuals.
	_static_visuals = false
	_update_body()
	_static_visuals = behavior_state.has_static_visuals()
	set_physics_process(true)


func position_at(time: float) -> Vector2:
	var point := _origin + behavior_state.position_at(time)
	return _bounce.fold_point(point, time) if _bounce != null else point


func body_at(time: float) -> PackedVector2Array:
	var start := maxf(0, time - trail_duration)
	var points := behavior_state.positions_between(start, time, SEGMENTS)
	for index in points.size():
		points[index] += _origin
		if _bounce != null:
			# Each body point folds by the bounces that happened before its own time.
			points[index] = _bounce.fold_point(points[index], lerpf(start, time, float(index) / SEGMENTS))
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
	apply_contacts()
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
	if not _static_visuals:
		var state := behavior_state.sample_shared(age)
		visual_scale = state.visual_scale
		hitbox_scale = state.hitbox_scale
		render_tint = state.tint
		render_opacity = state.opacity
	global_position = position_at(age)
	_body = body_at(age)
	var count := _body.size()
	_ribbon_offsets.resize(count)
	_ribbon_offsets[0] = (_body[1] - _body[0]).normalized().orthogonal() * _profile[0]
	for index in range(1, count - 1):
		_ribbon_offsets[index] = (_body[index + 1] - _body[index - 1]).normalized().orthogonal() * _profile[index]
	_ribbon_offsets[count - 1] = (_body[count - 1] - _body[count - 2]).normalized().orthogonal() * _profile[count - 1]
	if not use_batched_rendering or show_hitbox:
		queue_redraw()


## Half hit width at drawn segment `index` (same taper as the core).
func segment_hit_radius(index: int) -> float:
	return hit_width * 0.5 * width_factor(index) * hitbox_scale


## CPU collision: every body segment against every player-side hurtbox shape.
## Polling each tick means a player sitting inside a persistent laser is hit
## again once immunity ends, like the old overlap polling.
func apply_contacts() -> void:
	if age <= 0.001 or _body.size() < 2 or not is_inside_tree():
		return
	EnemyBulletPool.collect_targets(get_tree(), _targets)
	if _targets.is_empty():
		return
	var low := _body[0]
	var high := _body[0]
	for point in _body:
		low = low.min(point)
		high = high.max(point)
	var margin := hit_width * 0.5 * hitbox_scale
	for target in _targets:
		var reach := margin + target.radius
		if target.center.x < low.x - reach or target.center.x > high.x + reach or target.center.y < low.y - reach or target.center.y > high.y + reach:
			continue
		if target.hurtbox.is_invincible:
			continue
		for index in _body.size() - 1:
			var hit: Variant = EnemyBulletPool.segment_hits(_body[index], _body[index + 1], segment_hit_radius(index), target)
			if hit != null:
				_hitbox.global_position = hit
				_hitbox._on_hurtbox_entered(target.hurtbox)
				break


## True when `shape` at `shape_transform` overlaps any body segment
## (EnemyBullets.query_shape).
func overlaps_shape(shape: Shape2D, shape_transform: Transform2D) -> bool:
	if not _active or age <= 0.001 or _body.size() < 2:
		return false
	var capsule := CapsuleShape2D.new()
	for index in _body.size() - 1:
		var a := _body[index]
		var b := _body[index + 1]
		capsule.radius = segment_hit_radius(index)
		capsule.height = a.distance_to(b) + capsule.radius * 2.0
		var xform := Transform2D((b - a).angle() - PI * 0.5, (a + b) * 0.5)
		if shape.collide(shape_transform, capsule, xform):
			return true
	return false


## External trajectory effect on the laser head (see EnemyBullets.apply_effect).
## The body already drawn keeps its past path.
func apply_trajectory_effect(handle: StringName, speed_mult: float, heading_offset: float, duration: float) -> bool:
	if not _active or behavior_state == null:
		return false
	if _bounce != null:
		heading_offset *= _bounce.handedness(age)
	var applied := behavior_state.apply_effect(handle, speed_mult, heading_offset, duration)
	if applied and _bounce != null:
		_bounce.invalidate_after(age)
	return applied


func remove_trajectory_effect(handle: StringName) -> bool:
	var removed := _active and behavior_state != null and behavior_state.remove_effect(handle)
	if removed and _bounce != null:
		_bounce.invalidate_after(age)
	return removed


func get_trajectory_effect(handle: StringName) -> Dictionary:
	return behavior_state.get_effect(handle) if behavior_state != null else {}


func get_travel_velocity() -> Vector2:
	var velocity := behavior_state.velocity_at(age)
	return _bounce.reflect_vector(age, velocity) if _bounce != null else velocity


func get_bounce_count() -> int:
	return _bounce.bounces_until(age) if _bounce != null else 0


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
	if age <= 0.001 or _body.size() < 2:
		return
	if not use_batched_rendering:
		_draw_ribbon(core_width * 2.6, Color(1, 0.4, 0.03, 0.12))
		_draw_ribbon(core_width * 1.5, Color(1, 0.75, 0.12, 0.55))
		_draw_ribbon(core_width, Color(1, 0.98, 0.66))
	if show_hitbox:
		# One capsule per segment: the exact CPU collision volume.
		for index in _body.size() - 1:
			draw_line(to_local(_body[index]), to_local(_body[index + 1]), DEBUG_COLOR, segment_hit_radius(index) * 2.0, true)


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
