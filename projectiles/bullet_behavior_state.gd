class_name BulletBehaviorState
extends RefCounted
## Deterministic trajectory shared by movement, history and threat prediction.
## Position integrates forward speed/heading; lateral displacement is analytic.

const STEP := 1.0 / 120.0
var _behavior: BulletBehavior
var _direction: Vector2
var _speed: float
var _tint: Color
var _positions := PackedVector2Array([Vector2.ZERO])
var _limit := 8.0
var _constant_velocity := true
var _max_hitbox_scale := 1.0
var prediction_step := 0.04
var _single_turn: BulletAction
var _single_wave: BulletAction
var _has_lateral := false
const QUERY_CACHE_LIMIT := 2048
const BOUNDARY_EPSILON := 1.0e-10
var playback_time := 0.0
var cached_until := 0.0
var _position_queries: Dictionary = {}
var _starts := PackedFloat64Array()
var _ends := PackedFloat64Array()
var _initials: Array[Dictionary] = []
var _indices := PackedInt32Array()
var _tail: Dictionary
var _timeline_end := 0.0
var _next_action := 0
var _cycle := 0
var _finished := false
var _heading_actions: Array[BulletAction] = []
var _speed_actions: Array[BulletAction] = []
var _homing: RefCounted
## External trajectory effects (augments), keyed by handle:
## handle -> {speed_mult, heading_offset, until}. See combat.md 외부 궤도 개입.
var _effects: Dictionary = {}
## Stretches of bullet age with one combined effect set, oldest first:
## {time, speed_mult, heading_offset, anchor, has_anchor, cache}. Each stretch
## integrates from its anchor, so positions before a change never move.
var _events: Array[Dictionary] = []

func _init(behavior: BulletBehavior, direction: Vector2, speed: float, tint: Color, lifetime: float) -> void:
	_behavior = behavior.duplicate(true) as BulletBehavior
	_direction = direction.normalized()
	_speed = speed
	_tint = tint
	_limit = lifetime
	_tail = {"heading": 0.0, "speed": _speed, "tint": _tint, "opacity": 1.0, "visual_scale": 1.0, "hitbox_scale": 1.0, "lateral": 0.0, "lateral_velocity": 0.0}
	_finished = _behavior.actions.is_empty()
	var has_homing := false
	for action in _behavior.actions:
		var heading_action: BulletAction
		var speed_action: BulletAction
		var group: Array = action.children if action.type == BulletAction.Type.PARALLEL else [action]
		for child in group:
			if child.type == BulletAction.Type.HOMING: has_homing = true
			if child.channel() == "heading": heading_action = child
			if child.channel() == "speed": speed_action = child
			if child.type == BulletAction.Type.LATERAL_WAVE:
				_has_lateral = true
			if child.channel() in ["heading", "speed"]:
				_constant_velocity = false
			if child.type == BulletAction.Type.HITBOX_SCALE:
				_max_hitbox_scale = maxf(_max_hitbox_scale, child.value)
			if child.type in [BulletAction.Type.HEADING_WAVE, BulletAction.Type.LATERAL_WAVE]:
				prediction_step = minf(prediction_step, child.period / 24.0)
		_heading_actions.append(heading_action)
		_speed_actions.append(speed_action)
	if _behavior.repeat_count == 1 and _behavior.actions.size() == 1 and _behavior.actions[0].type == BulletAction.Type.TURN_AT:
		_single_turn = _behavior.actions[0]
	if _behavior.actions.size() == 1 and _behavior.actions[0].type == BulletAction.Type.HEADING_WAVE and _behavior.actions[0].duration > 0:
		_single_wave = _behavior.actions[0]
	if has_homing:
		_homing = preload("res://projectiles/bullet_homing_trajectory.gd").new(self)

func configure_homing(owner: Node2D, origin: Vector2, target: Node2D = null, resolver := Callable()) -> void:
	if _homing != null: _homing.configure(owner, origin, target, resolver)

func sample(time: float) -> Dictionary:
	if _homing != null: return _homing.sample(clampf(time, 0, _limit))
	var t := clampf(time, 0, _limit)
	var index := _segment_at(t)
	if index < 0: return _tail.duplicate()
	var initial := _initials[index]
	var state := initial.duplicate()
	_evaluate(_behavior.actions[_indices[index]], maxf(0, t - _starts[index]), initial, state)
	return state

func advance_to(time: float) -> void:
	# Only the actual body update commits time. Prediction queries never do.
	if _homing != null and time > playback_time:
		_homing.advance_to(clampf(time, 0, _limit))
		# A new homing observation changes the base velocity ahead of it.
		_trim_effect_caches(playback_time)
	playback_time = maxf(playback_time, clampf(time, 0, _limit))

func invalidate_prediction() -> void:
	_trim_effect_caches(playback_time)
	if _homing != null:
		_homing.invalidate_prediction()
		cached_until = playback_time
		return
	# Static Action checkpoints remain valid. Future dynamic input handling must
	# split its timeline at playback_time before changing any movement inputs.
	var keep := floori(playback_time / STEP) + 1
	if _positions.size() > keep: _positions.resize(keep)
	for time in _position_queries.keys():
		if time > playback_time: _position_queries.erase(time)
	cached_until = playback_time

func _evaluate(action: BulletAction, elapsed: float, initial: Dictionary, state: Dictionary) -> void:
	state.lateral_velocity = 0.0
	if action.type == BulletAction.Type.PARALLEL:
		for child in action.children: _apply(child, elapsed, initial, state)
	else:
		_apply(action, elapsed, initial, state)

func _segment_at(time: float) -> int:
	# Each completed Action is accumulated once, even if prediction runs ahead
	# of playback or callers later query history in reverse order.
	while not _finished and _timeline_end <= time + BOUNDARY_EPSILON:
		var action := _behavior.actions[_next_action]
		var length := action.length()
		var initial := _tail.duplicate()
		if length > 0:
			_starts.append(_timeline_end)
			_ends.append(_timeline_end + length)
			_initials.append(initial)
			_indices.append(_next_action)
		_evaluate(action, length, initial, _tail)
		_timeline_end += length
		_next_action += 1
		if _next_action == _behavior.actions.size():
			_next_action = 0
			_cycle += 1
			_finished = _behavior.repeat_count > 0 and _cycle >= _behavior.repeat_count
	if _finished and time + BOUNDARY_EPSILON >= _timeline_end:
		_tail.lateral_velocity = 0.0
		return -1
	# Upper bound makes exact boundaries select the following Action.
	var low := 0
	var high := _ends.size()
	while low < high:
		var middle := (low + high) / 2
		if _ends[middle] <= time + BOUNDARY_EPSILON: low = middle + 1
		else: high = middle
	return low

func _apply(action: BulletAction, elapsed: float, initial: Dictionary, state: Dictionary) -> void:
	if absf(elapsed - action.duration) <= BOUNDARY_EPSILON: elapsed = action.duration
	var t := minf(elapsed, action.duration)
	var weight := action.progress(t)
	match action.type:
		BulletAction.Type.TURN_BY:
			state.heading = initial.heading + action.value * weight
		BulletAction.Type.TURN_TO:
			var desired := deg_to_rad(action.value) - Vector2.DOWN.angle_to(_direction)
			state.heading = rad_to_deg(lerp_angle(deg_to_rad(initial.heading), desired, weight))
		BulletAction.Type.TURN_AT:
			state.heading = initial.heading + action.value * t
		BulletAction.Type.HEADING_WAVE:
			# Centered on the heading at action start, so waves compose with prior turns.
			state.heading = initial.heading + action.value * sin(TAU * t / action.period + action.phase)
		BulletAction.Type.LATERAL_WAVE:
			state.lateral = initial.lateral + action.value * (sin(TAU * t / action.period + action.phase) - sin(action.phase))
			state.lateral_velocity = action.value * TAU / action.period * cos(TAU * t / action.period + action.phase) if elapsed < action.duration else 0.0
		BulletAction.Type.SPEED:
			state.speed = lerpf(initial.speed, action.value, weight)
		BulletAction.Type.TINT:
			state.tint = (initial.tint as Color).lerp(action.color, weight)
		BulletAction.Type.OPACITY:
			state.opacity = lerpf(initial.opacity, action.value, weight)
		BulletAction.Type.VISUAL_SCALE:
			state.visual_scale = lerpf(initial.visual_scale, action.value, weight)
		BulletAction.Type.HITBOX_SCALE:
			state.hitbox_scale = lerpf(initial.hitbox_scale, action.value, weight)

func velocity_at(time: float) -> Vector2:
	var t := clampf(time, 0, _limit)
	var index := _event_index(t)
	if index < 0:
		return _base_velocity_at(t)
	return _effective_velocity(t, _events[index])

func _base_velocity_at(time: float) -> Vector2:
	var state := sample(time)
	return _direction.rotated(deg_to_rad(state.heading)) * float(state.speed) + _direction.orthogonal() * float(state.lateral_velocity)


# --- External trajectory effects -------------------------------------------

## Registers or replaces effect `handle` at the current playback time. Heading
## offsets add up and speed multipliers multiply across handles. duration <= 0
## keeps the effect until remove_effect(). Returns false for invalid input.
func apply_effect(handle: StringName, speed_mult := 1.0, heading_offset := 0.0, duration := 0.0) -> bool:
	if handle == &"" or not is_finite(speed_mult) or speed_mult < 0.0 or not is_finite(heading_offset) or not is_finite(duration):
		return false
	var now := playback_time
	var anchor := position_at(now)
	_drop_expired(now)
	_effects[handle] = {
		"speed_mult": speed_mult,
		"heading_offset": heading_offset,
		"until": now + duration if duration > 0.0 else INF,
	}
	_rebuild_effect_events(now, anchor)
	return true

## Ends effect `handle` now. The bullet keeps its current position and
## continues with the remaining effects.
func remove_effect(handle: StringName) -> bool:
	var now := playback_time
	_drop_expired(now)
	if not _effects.has(handle):
		return false
	var anchor := position_at(now)
	_effects.erase(handle)
	_rebuild_effect_events(now, anchor)
	return true

## The effect active now for `handle`, or an empty Dictionary.
func get_effect(handle: StringName) -> Dictionary:
	var effect: Dictionary = _effects.get(handle, {})
	if effect.is_empty() or float(effect.until) <= playback_time:
		return {}
	return effect.duplicate()

func has_effects() -> bool:
	return not _events.is_empty()

func _drop_expired(now: float) -> void:
	for handle in _effects.keys():
		if float(_effects[handle].until) <= now + BOUNDARY_EPSILON:
			_effects.erase(handle)

func _rebuild_effect_events(now: float, anchor: Vector2) -> void:
	# Keep every stretch that started before now; replace the future.
	while not _events.is_empty() and float(_events[-1].time) >= now - BOUNDARY_EPSILON:
		_events.pop_back()
	_events.append(_make_event(now, _effects, anchor, true))
	# Known expiries become future stretches so prediction already includes them.
	var ends: Array[float] = []
	for effect in _effects.values():
		var until := float(effect.until)
		if is_finite(until) and until > now and not ends.has(until):
			ends.append(until)
	ends.sort()
	var remaining := _effects.duplicate()
	for end in ends:
		for handle in remaining.keys():
			if float(remaining[handle].until) <= end + BOUNDARY_EPSILON:
				remaining.erase(handle)
		_events.append(_make_event(end, remaining, Vector2.ZERO, false))
	for time in _position_queries.keys():
		if time > now: _position_queries.erase(time)
	cached_until = now

func _make_event(time: float, effects: Dictionary, anchor: Vector2, has_anchor: bool) -> Dictionary:
	var speed_mult := 1.0
	var heading_offset := 0.0
	for effect in effects.values():
		speed_mult *= float(effect.speed_mult)
		heading_offset += float(effect.heading_offset)
	return {
		"time": time,
		"speed_mult": speed_mult,
		"heading_offset": heading_offset,
		"anchor": anchor,
		"has_anchor": has_anchor,
		"fixed_anchor": has_anchor,
		"cache": PackedVector2Array(),
	}

func _event_index(time: float) -> int:
	if _events.is_empty() or time < float(_events[0].time) - BOUNDARY_EPSILON:
		return -1
	var index := _events.size() - 1
	while index > 0 and float(_events[index].time) > time + BOUNDARY_EPSILON:
		index -= 1
	return index

func _effective_velocity(time: float, event: Dictionary) -> Vector2:
	return _base_velocity_at(time).rotated(deg_to_rad(float(event.heading_offset))) * float(event.speed_mult)

func _event_position(index: int, time: float) -> Vector2:
	var event := _events[index]
	if not event.has_anchor:
		event.anchor = _event_position(index - 1, float(event.time))
		event.has_anchor = true
	var start := float(event.time)
	var cache: PackedVector2Array = event.cache
	if cache.is_empty():
		cache.append(event.anchor)
	var local := maxf(0.0, time - start)
	var step_index := floori(local / STEP)
	while cache.size() <= step_index:
		var step_start := start + (cache.size() - 1) * STEP
		cache.append(cache[-1] + _effective_velocity(step_start + STEP * 0.5, event) * STEP)
	event.cache = cache
	var remainder := local - step_index * STEP
	if remainder <= BOUNDARY_EPSILON:
		return cache[step_index]
	var step_start := start + step_index * STEP
	return cache[step_index] + _effective_velocity(step_start + remainder * 0.5, event) * remainder

## Drops integrated positions after `after`; earlier ones stay fixed. Future
## expiry stretches recompute their anchor from the stretch before them.
func _trim_effect_caches(after: float) -> void:
	for event in _events:
		var start := float(event.time)
		if start > after + BOUNDARY_EPSILON:
			if not event.fixed_anchor:
				event.has_anchor = false
			event.cache = PackedVector2Array()
			continue
		var cache: PackedVector2Array = event.cache
		var keep := floori((after - start) / STEP + BOUNDARY_EPSILON) + 1
		if cache.size() > keep:
			cache.resize(keep)
			event.cache = cache

func _forward_velocity(time: float) -> Vector2:
	if _single_wave != null:
		var t := clampf(time, 0, _limit)
		var duration := _single_wave.duration
		var end_heading := _single_wave.value * sin(TAU * duration / _single_wave.period + _single_wave.phase)
		var cycles := floori((t + BOUNDARY_EPSILON) / duration)
		var heading: float
		if _behavior.repeat_count > 0 and cycles >= _behavior.repeat_count:
			heading = end_heading * _behavior.repeat_count
		else:
			var elapsed := maxf(0.0, t - cycles * duration)
			heading = end_heading * cycles + _single_wave.value * sin(TAU * elapsed / _single_wave.period + _single_wave.phase)
		return _direction.rotated(deg_to_rad(heading)) * _speed
	var t := clampf(time, 0, _limit)
	var index := _segment_at(t)
	if index < 0:
		return _direction.rotated(deg_to_rad(_tail.heading)) * float(_tail.speed)
	var initial := _initials[index]
	var elapsed := maxf(0, t - _starts[index])
	var heading := float(initial.heading)
	var speed := float(initial.speed)
	var action := _heading_actions[_indices[index]]
	if action != null:
		var duration := minf(elapsed, action.duration)
		var weight := action.progress(duration)
		match action.type:
			BulletAction.Type.TURN_BY: heading += action.value * weight
			BulletAction.Type.TURN_TO:
				var desired := deg_to_rad(action.value) - Vector2.DOWN.angle_to(_direction)
				heading = rad_to_deg(lerp_angle(deg_to_rad(heading), desired, weight))
			BulletAction.Type.TURN_AT: heading += action.value * duration
			BulletAction.Type.HEADING_WAVE: heading += action.value * sin(TAU * duration / action.period + action.phase)
	action = _speed_actions[_indices[index]]
	if action != null:
		speed = lerpf(speed, action.value, action.progress(elapsed))
	return _direction.rotated(deg_to_rad(heading)) * speed

func _integral(start: float, duration: float) -> Vector2:
	# Midpoint quadrature avoids looking ahead across an instantaneous action.
	return _forward_velocity(start + duration * 0.5) * duration

func position_at(time: float) -> Vector2:
	var t := clampf(time, 0, _limit)
	cached_until = maxf(cached_until, t)
	var effect_index := _event_index(t)
	if effect_index >= 0:
		return _event_position(effect_index, t)
	if _homing != null: return _homing.position_at(t)
	# Analytic/simple wave paths cost less than dictionary cache bookkeeping.
	if _constant_velocity or _single_turn != null or _single_wave != null:
		return _position_at_uncached(t)
	if _position_queries.has(t): return _position_queries[t]
	var position := _position_at_uncached(t)
	if _position_queries.size() >= QUERY_CACHE_LIMIT: _position_queries.clear()
	_position_queries[t] = position
	return position

## Evenly spaced positions from start to end (segments + 1 points) for drawing
## and laser bodies. Homing paths without effects walk their stored frames once
## and interpolate between them (sub-pixel); everything else calls position_at.
func positions_between(start: float, end: float, segments: int) -> PackedVector2Array:
	var from := clampf(start, 0, _limit)
	var to := clampf(end, 0, _limit)
	if _homing != null and _events.is_empty():
		cached_until = maxf(cached_until, to)
		return _homing.positions_between(from, to, segments)
	var points := PackedVector2Array()
	points.resize(segments + 1)
	for index in segments + 1:
		points[index] = position_at(lerpf(start, end, float(index) / segments))
	return points

func _position_at_uncached(t: float) -> Vector2:
	if _constant_velocity:
		return _direction * _speed * t + (_direction.orthogonal() * float(sample(t).lateral) if _has_lateral else Vector2.ZERO)
	if _single_turn != null:
		var turning := minf(t, _single_turn.duration)
		var omega := deg_to_rad(_single_turn.value)
		if absf(omega) < 0.0001: return _direction * _speed * t
		var normal := Vector2(-_direction.y, _direction.x)
		return _speed / omega * (_direction * sin(omega * turning) + normal * (1 - cos(omega * turning))) + _direction.rotated(omega * turning) * _speed * (t - turning)
	var index := floori(t / STEP)
	while _positions.size() <= index:
		var start := (_positions.size() - 1) * STEP
		_positions.append(_positions[-1] + _integral(start, STEP))
	var remainder := t - index * STEP
	var position := _positions[index] + _integral(index * STEP, remainder) if remainder > 0 else _positions[index]
	return position + (_direction.orthogonal() * float(sample(t).lateral) if _has_lateral else Vector2.ZERO)

func max_hitbox_scale(_until: float) -> float:
	# Clamped interpolation stays between endpoints, even for nonmonotonic easing.
	return _max_hitbox_scale
