class_name FoundationBullet
extends Node
## Enemy bullet body (BarrageShot.Kind.BULLET). A lightweight Node handle: it
## keeps tree membership, groups, queue_free, pause and instance identity, but
## owns no Area2D, no canvas item and no per-node processing. EnemyBulletPool
## (one per projectile parent) steps it, draws it and tests it against
## player-side hurtboxes. Straight bullets (empty Behavior, no bounce) skip the
## BulletBehaviorState entirely until an external effect or a query needs it;
## the state is then created on the same trajectory, so nothing changes.
## Rules: combat.md 탄, barrage-api.md 2·9·11절.

@export var appearance: BulletAppearance
@export var behavior: BulletBehavior
@export var trail_effect: BulletTrailEffect
var _trail: BulletTrailEmitter
@export var lifetime := 8.0
## Lazily created for straight bullets; reading it builds the state.
var behavior_state: BulletBehaviorState:
	get:
		return _ensure_state()
var _state: BulletBehaviorState
var visual_scale := 1.0
var hitbox_scale := 1.0
var render_tint := Color.WHITE
var render_opacity := 1.0
## False while a TANGIBLE Action has the hitbox switched off (ghost bullet).
var tangible := true
## Damage handed to the hurtbox on a hit (the player always takes 1; barrier
## segments and labs read it). Sniper rounds set it from their shot.
var damage := 1
@export var show_hitbox := false:
	set(value):
		if show_hitbox == value:
			return
		show_hitbox = value
		if _pool != null:
			_pool.debug_changed(self, value)
## World position and travel rotation, written by the pool every tick.
var global_position := Vector2.ZERO
var global_rotation := 0.0
## Hidden bullets keep simulating and colliding but are not drawn.
var visible := true
## False freezes the bullet in place (tests, lab pause). The pool skips it.
var simulating := true

var age := 0.0
var _origin := Vector2.ZERO
var _direction := Vector2.DOWN
var _speed := 0.0
var _active := false
var _entered_view := false
var _render_key := ""
var _visual_extent := 0.0
var _bounding_radius := 0.0
## Straight fast path: position is _origin + _direction * _speed * age and no
## state exists until an effect/query asks for one.
var _straight := false
## Per-tick fast paths, set after the first full pose update in launch():
## static visuals skip state sampling, constant travel skips rotation updates.
var _static_visuals := false
var _constant_travel := false
var _needs_rotation := true
var _has_spawns := false
var _spawn_frame := -1
## Target for SPAWN volleys with Aim.EACH_SHOT (the shot's launch target).
var _spawn_target: WeakRef
var _spawn_resolver := Callable()
## Set by BarrageShot.spawn for SPAWN children: appearance/behavior are the
## parent's private, already validated copy, so they are shared, not copied.
var shares_config := false
## Wall reflection (BarrageShot.bounce_walls / bounce_count); null = none.
var bounce_walls := 0
var bounce_count := 1
var _bounce: BulletWallBounce
## Pool bookkeeping (EnemyBulletPool).
var _pool: EnemyBulletPool
var _group: RefCounted
var _slot := -1
var _index := -1


func _init() -> void:
	add_to_group(EnemyBullets.GROUP)


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
	_visual_extent = appearance.visual_extent()
	_bounding_radius = appearance.bounding_radius()
	# The pool steps bullets; the engine must not dispatch _physics_process
	# per node (it exists only so tests can step a bullet by hand).
	set_physics_process(false)
	_pool = EnemyBulletPool.for_parent(get_parent())
	_pool.register(self)


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
	_spawn_frame = int(Engine.get_physics_frames())
	age = 0.0
	_active = true
	_entered_view = _view_rect().has_point(global_position)
	# A circle with centered collision looks and collides the same at any angle.
	_needs_rotation = appearance.form != BulletAppearance.Form.ROUND or appearance.collision_offset != Vector2.ZERO
	_straight = behavior.actions.is_empty() and bounce_walls == 0
	if _straight:
		# Nothing can change this bullet's visuals or heading until an effect
		# arrives, so the launch pose is final apart from the position.
		_static_visuals = true
		_constant_travel = true
		_has_spawns = false
		if _needs_rotation:
			global_rotation = _direction.angle() + PI * 0.5
		_show_launch_pose()
		return
	_ensure_state()
	if bounce_walls != 0:
		_bounce = BulletWallBounce.new(
			func(time: float) -> Vector2: return _origin + _state.position_at(time),
			_view_rect(), appearance.bounding_radius(), bounce_walls, bounce_count, lifetime)
	# The first update runs the full path (visuals, hitbox scale, rotation);
	# later ticks skip whatever can never change again.
	_static_visuals = false
	_constant_travel = false
	_update_pose()
	_static_visuals = _state.has_static_visuals()
	_constant_travel = _state.is_velocity_constant() and _bounce == null
	_has_spawns = _state.has_pending_spawns()
	_show_launch_pose()


## Draws the bullet at its launch pose right away, so it is visible on the
## frame it was fired instead of after the pool's next physics tick.
func _show_launch_pose() -> void:
	if _pool != null and _group != null:
		_pool._write_instance(self)


## Creates the trajectory state on first need (straight bullets defer it).
func _ensure_state() -> BulletBehaviorState:
	if _state == null and behavior != null and appearance != null:
		# The body already owns a private Behavior (copied in _ready or shared
		# from a SPAWN parent's copy), so the state adopts it instead of copying.
		_state = BulletBehaviorState.new(behavior, _direction, _speed, appearance.tint, lifetime, false)
		_state.configure_homing(self, _origin, _spawn_target.get_ref() if _spawn_target != null else null, _spawn_resolver)
		if _straight:
			_straight = false
			_state.advance_to(age)
	return _state


## Freezes or resumes this bullet (the pool skips frozen bullets).
func set_simulating(enabled: bool) -> void:
	simulating = enabled


## One simulation step, called by EnemyBulletPool (or a test). Returns the new
## world position; the bullet may have freed itself (check `_group == null`).
func _tick(delta: float, bounds: Rect2) -> Vector2:
	age = minf(age + delta, lifetime)
	var point: Vector2
	if _straight:
		# Inline fast path: one multiply-add, no state object, no extra call.
		point = _origin + _direction * (_speed * age)
		global_position = point
	else:
		point = _update_pose()
		if _has_spawns and _fire_due_spawns():
			return point
	if _trail != null: _trail.advance(point, delta)
	var inside := bounds.grow(_visual_extent * visual_scale).has_point(point)
	if inside:
		_entered_view = true
	if age >= lifetime or (_entered_view and not inside):
		_active = false
		queue_free()
	return point


## Steps the bullet outside the pool (tests): same as one physics tick. Works
## on a frozen (`simulating = false`) bullet too; only the pool honours the flag.
func step(delta: float) -> void:
	if _active:
		_tick(delta, _view_rect())
		if _group != null and _pool != null:
			_pool._write_instance(self)


## Manual stepping entry point for tests; engine dispatch stays disabled.
func _physics_process(delta: float) -> void:
	step(delta)


## Returns the new world position so the caller can reuse it.
func _update_pose() -> Vector2:
	if _straight:
		global_position = _origin + _direction * (_speed * age)
		return global_position
	var state := _state
	state.advance_to(age)
	var point := world_position_at(age)
	if not _static_visuals:
		var sample := state.sample_shared(age)
		visual_scale = sample.visual_scale
		hitbox_scale = sample.hitbox_scale
		render_tint = sample.tint
		render_opacity = sample.opacity
		tangible = sample.tangible
	if _needs_rotation and not _constant_travel:
		var velocity := get_travel_velocity()
		if not velocity.is_zero_approx():
			global_rotation = velocity.angle() + PI * 0.5
	global_position = point
	return point


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
	if not _state.has_pending_spawns():
		return false
	for entry in _state.take_due_spawns(age):
		var action := entry.action as BulletAction
		var time := float(entry.time)
		var heading := _state.heading_at(time)
		if _bounce != null:
			heading = _bounce.reflect_vector(time, heading)
		var origin := world_position_at(time)
		for volley in action.spawn_volleys():
			_fire_spawn(volley, origin, heading, age - time)
		if action.consume_parent:
			_active = false
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


## Called by the pool after the hurtbox took the hit.
func _on_hit(_hurtbox: HurtboxComponent) -> void:
	_active = false
	queue_free()


## External trajectory effect (see EnemyBullets.apply_effect). Applies from the
## bullet's current age; false before launch or after it ends. A straight
## bullet leaves its fast path here.
func apply_trajectory_effect(handle: StringName, speed_mult: float, heading_offset: float, duration: float) -> bool:
	if not _active:
		return false
	var state := _ensure_state()
	if _bounce != null:
		# A mirrored path turns the other way; later bounces are recomputed.
		heading_offset *= _bounce.handedness(age)
	var applied := state.apply_effect(handle, speed_mult, heading_offset, duration)
	if applied:
		# Effects change velocity, so the travel rotation must update again.
		_constant_travel = false
	if applied and _bounce != null:
		_bounce.invalidate_after(age)
	return applied


func remove_trajectory_effect(handle: StringName) -> bool:
	var removed := _active and _state != null and _state.remove_effect(handle)
	if removed and _bounce != null:
		_bounce.invalidate_after(age)
	return removed


func get_trajectory_effect(handle: StringName) -> Dictionary:
	return _state.get_effect(handle) if _state != null else {}


func get_travel_velocity() -> Vector2:
	if not _active:
		return Vector2.ZERO
	if _straight:
		return _direction * _speed
	var velocity := _state.velocity_at(age)
	return _bounce.reflect_vector(age, velocity) if _bounce != null else velocity


## World position on the (wall-reflected) trajectory at bullet age `time`.
func world_position_at(time: float) -> Vector2:
	if _straight:
		return _origin + _direction * (_speed * clampf(time, 0.0, lifetime))
	var point := _origin + _state.position_at(time)
	return _bounce.fold_point(point, time) if _bounce != null else point


func get_bounce_count() -> int:
	return _bounce.bounces_until(age) if _bounce != null else 0


func get_hazard_radius() -> float:
	return appearance.bounding_radius() * (_state.max_hitbox_scale(lifetime) if _state != null else 1.0)


func get_predicted_path(seconds: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not _active or is_queued_for_deletion():
		return points
	var duration := minf(maxf(seconds, 0.0), lifetime - age)
	var bounds := _view_rect().grow(_visual_extent * visual_scale)
	if _straight:
		# A straight path needs only its two ends, clipped where it leaves view.
		points.append(global_position)
		points.append(world_position_at(age + duration))
		return points
	# At least 24 samples per wave; cap the step at 50 ms.
	var step := _state.prediction_step
	var count := maxi(1, ceili(duration / step))
	for index in range(count + 1):
		var time := age + duration * float(index) / count
		var point := world_position_at(time)
		points.append(point)
		if _entered_view and not bounds.has_point(point):
			break
	return points


## The physics-equivalent collision shape (shared per appearance) and its
## world transform with hitbox scale and offset, for queries and debug drawing.
func collision_shape() -> Shape2D:
	return appearance.shared_shape()


func collision_transform() -> Transform2D:
	var scale := Vector2.ONE * hitbox_scale
	return Transform2D(global_rotation, scale, 0.0, global_position + (appearance.collision_offset * hitbox_scale).rotated(global_rotation))


## True when `shape` placed at `shape_transform` overlaps this bullet's hitbox
## (EnemyBullets.query_shape). Intangible bullets never overlap.
func overlaps_shape(shape: Shape2D, shape_transform: Transform2D) -> bool:
	if not _active or not tangible:
		return false
	var reach := _bounding_radius * hitbox_scale + shape.get_rect().size.length() * 0.5 * maxf(shape_transform.get_scale().x, shape_transform.get_scale().y)
	if global_position.distance_squared_to(shape_transform.origin) > reach * reach:
		return false
	return shape.collide(shape_transform, collision_shape(), collision_transform())


func _view_rect() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_visible_rect() if viewport != null else Rect2(0, 0, 640, 360)
