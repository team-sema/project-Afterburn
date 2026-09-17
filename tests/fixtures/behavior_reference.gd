# Frozen pre-cache evaluator used as an independent regression oracle.
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

func _init(behavior: BulletBehavior, direction: Vector2, speed: float, tint: Color, lifetime: float) -> void:
	_behavior = behavior.duplicate(true) as BulletBehavior
	_direction = direction.normalized()
	_speed = speed
	_tint = tint
	_limit = lifetime
	for action in _behavior.actions:
		var group: Array = action.children if action.type == BulletAction.Type.PARALLEL else [action]
		for child in group:
			if child.type == BulletAction.Type.LATERAL_WAVE:
				_has_lateral = true
			if child.channel() in ["heading", "speed"]:
				_constant_velocity = false
			if child.type == BulletAction.Type.HITBOX_SCALE:
				_max_hitbox_scale = maxf(_max_hitbox_scale, child.value)
			if child.type in [BulletAction.Type.HEADING_WAVE, BulletAction.Type.LATERAL_WAVE]:
				prediction_step = minf(prediction_step, child.period / 24.0)
	if _behavior.repeat_count == 1 and _behavior.actions.size() == 1 and _behavior.actions[0].type == BulletAction.Type.TURN_AT:
		_single_turn = _behavior.actions[0]
	if _behavior.actions.size() == 1 and _behavior.actions[0].type == BulletAction.Type.HEADING_WAVE:
		_single_wave = _behavior.actions[0]

func sample(time: float) -> Dictionary:
	var state := {"heading": 0.0, "speed": _speed, "tint": _tint, "opacity": 1.0, "visual_scale": 1.0, "hitbox_scale": 1.0, "lateral": 0.0, "lateral_velocity": 0.0}
	var left := clampf(time, 0, _limit)
	if _behavior.actions.is_empty(): return state
	var cycles := _behavior.repeat_count
	var cycle := 0
	while cycles == 0 or cycle < cycles:
		for action in _behavior.actions:
			var length := action.length()
			var elapsed := minf(left, length)
			var initial := state.duplicate()
			state.lateral_velocity = 0.0
			if action.type == BulletAction.Type.PARALLEL:
				for child in action.children:
					_apply(child, elapsed, initial, state)
			else:
				_apply(action, elapsed, initial, state)
			if left < length: return state
			left -= length
		cycle += 1
	state.lateral_velocity = 0.0
	return state

func _apply(action: BulletAction, elapsed: float, initial: Dictionary, state: Dictionary) -> void:
	var t := minf(elapsed, action.duration)
	var weight := clampf(t / action.duration, 0, 1) if action.duration > 0 else 1.0
	match action.type:
		BulletAction.Type.TURN_BY:
			state.heading = initial.heading + action.value * weight
		BulletAction.Type.TURN_TO:
			var desired := deg_to_rad(action.value) - Vector2.DOWN.angle_to(_direction)
			state.heading = rad_to_deg(lerp_angle(deg_to_rad(initial.heading), desired, weight))
		BulletAction.Type.TURN_AT:
			state.heading = initial.heading + action.value * t
		BulletAction.Type.HEADING_WAVE:
			# Rule change 2026-09-17: waves are centered on the heading at action start.
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
	var state := sample(time)
	return _direction.rotated(deg_to_rad(state.heading)) * float(state.speed) + _direction.orthogonal() * float(state.lateral_velocity)

func _forward_velocity(time: float) -> Vector2:
	if _single_wave != null:
		var t := clampf(time, 0, _limit)
		var duration := _single_wave.duration
		if _behavior.repeat_count > 0 and t >= duration * _behavior.repeat_count:
			t = duration
		elif duration > 0:
			t = fposmod(t, duration)
		var heading := _single_wave.value * sin(TAU * t / _single_wave.period + _single_wave.phase)
		return _direction.rotated(deg_to_rad(heading)) * _speed
	var state := sample(time)
	return _direction.rotated(deg_to_rad(state.heading)) * float(state.speed)

func _integral(start: float, duration: float) -> Vector2:
	# Midpoint quadrature avoids looking ahead across an instantaneous action.
	return _forward_velocity(start + duration * 0.5) * duration

func position_at(time: float) -> Vector2:
	var t := clampf(time, 0, _limit)
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
	# Monotonic linear scale actions: the largest endpoint bounds all future sizes.
	return _max_hitbox_scale
