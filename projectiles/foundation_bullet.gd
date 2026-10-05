class_name FoundationBullet
extends Node2D

const BATCH_RENDERER = preload("res://projectiles/projectile_batch_renderer.gd")
@export var use_batched_rendering := true

@export var appearance: BulletAppearance
@export var behavior: BulletBehavior
@export var trail_effect: BulletTrailEffect
var _trail: BulletTrailEmitter
@export var lifetime := 8.0
var behavior_state: BulletBehaviorState
var visual_scale := 1.0
var hitbox_scale := 1.0
var render_tint := Color.WHITE
var render_opacity := 1.0
@export var show_hitbox := false:
	set(value):
		show_hitbox = value
		queue_redraw()

var age := 0.0
var _origin := Vector2.ZERO
var _direction := Vector2.DOWN
var _speed := 0.0
var _active := false
var _entered_view := false
var _hitbox: HitboxComponent
var _render_key := ""
var _texture_fallback: MultiMesh
## Target for SPAWN volleys with Aim.EACH_SHOT (the shot's launch target).
var _spawn_target: WeakRef
var _spawn_resolver := Callable()
## Set by BarrageShot.spawn for SPAWN children: appearance/behavior are the
## parent's private, already validated copy, so they are shared, not copied.
var shares_config := false
var _hitbox_scale_applied := -1.0


func _ready() -> void:
	if not shares_config and (appearance == null or not appearance.is_valid() or behavior == null or not behavior.validation_error().is_empty() or not is_finite(lifetime) or lifetime <= 0):
		push_error("FoundationBullet requires valid appearance, behavior and lifetime.")
		queue_free()
		return
	if not shares_config:
		appearance = appearance.duplicate() as BulletAppearance
		behavior = behavior.duplicate(true) as BulletBehavior
	render_tint = appearance.tint
	_render_key = appearance.render_key()
	_hitbox = HitboxComponent.new()
	_hitbox.name = "HitboxComponent"
	_hitbox.collision_layer = EnemyBullets.LAYER
	_hitbox.collision_mask = 1
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = appearance.make_shape()
	collision.position = appearance.collision_offset
	_hitbox.add_child(collision)
	_hitbox.hit_hurtbox.connect(_on_hit)
	add_child(_hitbox)
	if use_batched_rendering:
		BATCH_RENDERER.register(self)
	elif appearance.form == BulletAppearance.Form.TEXTURED:
		_texture_fallback = MultiMesh.new()
		_texture_fallback.transform_format = MultiMesh.TRANSFORM_2D
		_texture_fallback.use_colors = true
		_texture_fallback.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 2)
		_texture_fallback.mesh = quad
		_texture_fallback.instance_count = 1
		for layer_material in BATCH_RENDERER._make_texture_materials(appearance):
			var layer := MultiMeshInstance2D.new()
			layer.multimesh = _texture_fallback
			layer.texture = appearance.texture
			layer.material = layer_material
			layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(layer)
	set_physics_process(false)


func launch(direction: Vector2, speed: float) -> void:
	if not direction.is_finite() or direction.is_zero_approx() or not is_finite(speed) or speed < 0:
		push_error("FoundationBullet launch requires a finite nonzero direction and nonnegative speed.")
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
	# The body already owns a private Behavior (copied in _ready or shared from a
	# SPAWN parent's copy), so the state adopts it instead of copying again.
	behavior_state = BulletBehaviorState.new(behavior, _direction, speed, appearance.tint, lifetime, false)
	age = 0.0
	_active = true
	_entered_view = get_viewport_rect().has_point(global_position)
	_update_pose()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	age = minf(age + delta, lifetime)
	_update_pose()
	if _fire_due_spawns():
		return
	if _trail != null: _trail.advance(global_position, delta)
	var bounds := get_viewport_rect().grow(appearance.visual_extent() * visual_scale)
	if bounds.has_point(global_position):
		_entered_view = true
	if age >= lifetime or (_entered_view and not bounds.has_point(global_position)):
		_active = false
		queue_free()


func _update_pose() -> void:
	behavior_state.advance_to(age)
	global_position = _origin + behavior_state.position_at(age)
	var state := behavior_state.sample(age)
	visual_scale = state.visual_scale
	hitbox_scale = state.hitbox_scale
	render_tint = state.tint
	render_opacity = state.opacity
	if _texture_fallback != null:
		_texture_fallback.set_instance_transform_2d(0, Transform2D.IDENTITY.scaled_local(Vector2.ONE * visual_scale))
		_texture_fallback.set_instance_color(0, Color(1, 1, 1, render_opacity))
		_texture_fallback.set_instance_custom_data(0, render_tint)
	if hitbox_scale != _hitbox_scale_applied:
		# Touch the physics shape only when the scale actually changes.
		_hitbox_scale_applied = hitbox_scale
		_hitbox.get_child(0).scale = Vector2.ONE * hitbox_scale
		_hitbox.get_child(0).position = appearance.collision_offset * hitbox_scale
	if not use_batched_rendering:
		queue_redraw()
	var velocity := get_travel_velocity()
	if not velocity.is_zero_approx():
		global_rotation = velocity.angle() + PI * 0.5


func set_spawn_target(target: Node2D, resolver := Callable()) -> void:
	_spawn_target = weakref(target) if is_instance_valid(target) else null
	_spawn_resolver = resolver


## Moves a just-launched bullet `seconds` along its path, so a child spawned
## between frames starts where it would have been by now.
func prewarm(seconds: float) -> void:
	if not _active or not is_finite(seconds) or seconds <= 0.0:
		return
	age = minf(seconds, lifetime)
	_update_pose()


## Fires every SPAWN Action that came due this frame. Returns true when one of
## them consumed this bullet.
func _fire_due_spawns() -> bool:
	if not behavior_state.has_pending_spawns():
		return false
	for entry in behavior_state.take_due_spawns(age):
		var action := entry.action as BulletAction
		var time := float(entry.time)
		_fire_spawn(action.payload, _origin + behavior_state.position_at(time), behavior_state.heading_at(time), age - time)
		if action.consume_parent:
			_active = false
			set_physics_process(false)
			queue_free()
			return true
	return false


func _fire_spawn(volley: BarrageVolley, origin: Vector2, heading: Vector2, overshoot: float) -> void:
	var world := get_parent() as Node2D
	if volley == null or world == null or not world.is_inside_tree():
		return
	var target := _resolve_spawn_target()
	var directions: PackedVector2Array
	if volley.aim == BarrageVolley.Aim.NONE:
		# Volley angles are measured from the bullet heading instead of world-down.
		directions = volley.directions(rad_to_deg(Vector2.DOWN.angle_to(heading)))
	else:
		if target == null or target.global_position.is_equal_approx(origin):
			return
		directions = volley.directions(0.0, target.global_position - origin)
	var start := origin + volley.origin_offset.rotated(Vector2.DOWN.angle_to(heading))
	for direction in directions:
		var child := volley.shot.spawn(world, start, direction, volley.speed, show_hitbox, target, _spawn_resolver, true)
		if child is FoundationBullet:
			(child as FoundationBullet).prewarm(overshoot)


func _resolve_spawn_target() -> Node2D:
	var node: Variant = _spawn_target.get_ref() if _spawn_target != null else null
	if not _is_spawn_target(node) and _spawn_resolver.is_valid():
		node = _spawn_resolver.call()
	return node as Node2D if _is_spawn_target(node) else null


func _is_spawn_target(node: Variant) -> bool:
	return (node is Node2D and is_instance_valid(node) and (node as Node2D).is_inside_tree()
		and not (node as Node2D).is_queued_for_deletion() and (node as Node2D).get_viewport() == get_viewport())


func _on_hit(_hurtbox: HurtboxComponent) -> void:
	_active = false
	set_physics_process(false)
	queue_free()


## External trajectory effect (see EnemyBullets.apply_effect). Applies from the
## bullet's current age; false before launch or after it ends.
func apply_trajectory_effect(handle: StringName, speed_mult: float, heading_offset: float, duration: float) -> bool:
	if not _active or behavior_state == null:
		return false
	return behavior_state.apply_effect(handle, speed_mult, heading_offset, duration)


func remove_trajectory_effect(handle: StringName) -> bool:
	return _active and behavior_state != null and behavior_state.remove_effect(handle)


func get_trajectory_effect(handle: StringName) -> Dictionary:
	return behavior_state.get_effect(handle) if behavior_state != null else {}


func get_travel_velocity() -> Vector2:
	return behavior_state.velocity_at(age) if _active else Vector2.ZERO


func get_hazard_radius() -> float:
	return appearance.bounding_radius() * (behavior_state.max_hitbox_scale(lifetime) if behavior_state != null else 1.0)


func get_predicted_path(seconds: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not _active or is_queued_for_deletion():
		return points
	var duration := minf(maxf(seconds, 0.0), lifetime - age)
	# At least 24 samples per wave; cap the step at 50 ms.
	var step := behavior_state.prediction_step
	var count := maxi(1, ceili(duration / step))
	var bounds := get_viewport_rect().grow(appearance.visual_extent() * visual_scale)
	for index in range(count + 1):
		var time := age + duration * float(index) / count
		var point := _origin + behavior_state.position_at(time)
		points.append(point)
		if _entered_view and not bounds.has_point(point):
			break
	return points


func _draw() -> void:
	if use_batched_rendering:
		return
	if appearance == null or not appearance.is_valid():
		return
	if appearance.form != BulletAppearance.Form.TEXTURED:
		_draw_core(1.65 * visual_scale, Color(render_tint, 0.10 * render_opacity))
		_draw_core(1.2 * visual_scale, Color(render_tint, 0.45 * render_opacity))
		_draw_core(visual_scale, Color(render_tint.lightened(0.75), render_tint.a * render_opacity))
	if show_hitbox:
		draw_set_transform(appearance.collision_offset * hitbox_scale, 0, Vector2.ONE * hitbox_scale)
		var shape := appearance.make_shape()
		shape.draw(get_canvas_item(), Color(0.2, 1.0, 0.75, 0.7))


func _draw_core(multiplier: float, color: Color) -> void:
	if appearance.form == BulletAppearance.Form.ROUND:
		draw_circle(Vector2.ZERO, appearance.core_size.x * 0.5 * multiplier, color, true, -1, true)
	else:
		var size := appearance.core_size * 0.5 * multiplier
		var points := PackedVector2Array()
		for index in 24:
			var angle := TAU * index / 24.0
			points.append(Vector2(sin(angle) * size.x, cos(angle) * size.y))
		draw_colored_polygon(points, color)
