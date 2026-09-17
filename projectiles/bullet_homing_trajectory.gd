extends RefCounted
## Input snapshots and committed trajectory for Behaviors containing homing.
## The owner runtime is weak to avoid a RefCounted ownership cycle.

const STEP := 1.0 / 120.0
const EPS := 1.0e-10

class Frame:
	extends RefCounted
	var time := 0.0
	var position := Vector2.ZERO # Forward integral; lateral displacement is analytic.
	var state: Dictionary
	var initial: Dictionary
	var index := 0
	var cycle := 0
	var elapsed := 0.0
	var finished := false
	var has_target := false
	var target := Vector2.ZERO

	func copy() -> Frame:
		var result := Frame.new()
		result.time = time
		result.position = position
		result.state = state.duplicate()
		result.initial = initial
		result.index = index
		result.cycle = cycle
		result.elapsed = elapsed
		result.finished = finished
		result.has_target = has_target
		result.target = target
		return result

var _runtime: WeakRef
var _owner: WeakRef
var _target: WeakRef
var _resolver := Callable()
var _origin := Vector2.ZERO
var _direction: Vector2
var _behavior: BulletBehavior
var _frames: Array[Frame] = []
var _committed := 0

func _init(runtime) -> void:
	_runtime = weakref(runtime)
	_direction = runtime._direction
	_behavior = runtime._behavior
	var first := Frame.new()
	first.state = runtime._tail.duplicate()
	first.initial = first.state.duplicate()
	_normalize(first)
	_frames.append(first)

func configure(owner: Node2D, origin: Vector2, target: Node2D, resolver: Callable) -> void:
	_owner = weakref(owner)
	_origin = origin
	_target = weakref(target) if is_instance_valid(target) else null
	_resolver = resolver
	invalidate_prediction()
	_observe(_frames[_committed])

func _valid_target(node) -> bool:
	var owner = _owner.get_ref() if _owner != null else null
	return (is_instance_valid(owner) and owner.is_inside_tree()
		and node is Node2D and is_instance_valid(node) and node.is_inside_tree()
		and not node.is_queued_for_deletion() and node.get_viewport() == owner.get_viewport()
		and node.global_position.is_finite())

func _observe(frame: Frame) -> void:
	var node = _target.get_ref() if _target != null else null
	if not _valid_target(node):
		node = _resolver.call() if _resolver.is_valid() else null
		_target = weakref(node) if _valid_target(node) else null
	frame.has_target = _valid_target(node)
	if frame.has_target: frame.target = node.global_position

func invalidate_prediction() -> void:
	_frames.resize(_committed + 1)

func advance_to(time: float) -> void:
	if time <= _frames[_committed].time: return
	invalidate_prediction()
	# Change only the input for the interval starting at the committed boundary.
	# Older frames retain the input used to integrate their own interval.
	_observe(_frames[_committed])
	var frame := _at(time)
	var index := _floor_index(time)
	_frames.resize(index + 1)
	if _frames[-1].time < time - EPS: _frames.append(frame)
	_committed = _frames.size() - 1
	_runtime.get_ref().cached_until = time

func sample(time: float) -> Dictionary:
	return _at(time).state.duplicate()

func position_at(time: float) -> Vector2:
	var frame := _at(time)
	return frame.position + _direction.orthogonal() * float(frame.state.lateral)

func _floor_index(time: float) -> int:
	var low := 0
	var high := _frames.size()
	while low < high:
		var middle := (low + high) / 2
		if _frames[middle].time <= time + EPS: low = middle + 1
		else: high = middle
	return maxi(0, low - 1)

func _at(time: float) -> Frame:
	while _frames[-1].time < time - EPS:
		var last := _frames[-1]
		var next_grid := (floori((last.time + EPS) / STEP) + 1) * STEP
		var duration := next_grid - last.time
		if not last.finished:
			var action := _behavior.actions[last.index]
			duration = minf(duration, action.length() - last.elapsed)
			# Split at child completion too, so homing stops at its own duration.
			if action.type == BulletAction.Type.PARALLEL:
				for child in action.children:
					if child.duration > last.elapsed + EPS:
						duration = minf(duration, child.duration - last.elapsed)
		_frames.append(_step(last, duration))
	var frame := _frames[_floor_index(time)]
	return frame if absf(frame.time - time) <= EPS else _step(frame, time - frame.time)

func _normalize(frame: Frame) -> void:
	while not frame.finished:
		var action := _behavior.actions[frame.index]
		if frame.elapsed < action.length() - EPS:
			_runtime.get_ref()._evaluate(action, frame.elapsed, frame.initial, frame.state)
			return
		if action.length() <= EPS:
			_runtime.get_ref()._evaluate(action, action.length(), frame.initial, frame.state)
		frame.index += 1
		if frame.index == _behavior.actions.size():
			frame.index = 0
			frame.cycle += 1
			frame.finished = _behavior.repeat_count > 0 and frame.cycle >= _behavior.repeat_count
		frame.elapsed = 0
		frame.initial = frame.state.duplicate()
	frame.state.lateral_velocity = 0.0

func _turn(frame: Frame, action: BulletAction, duration: float) -> float:
	var heading := float(frame.state.heading)
	if not frame.has_target or frame.elapsed >= action.duration - EPS: return heading
	var position := _origin + frame.position + _direction.orthogonal() * float(frame.state.lateral)
	var offset := frame.target - position
	if offset.is_zero_approx(): return heading
	var current := _direction.rotated(deg_to_rad(heading))
	var difference := current.angle_to(offset)
	# Vector2 angles use engine real precision (float32 in standard builds).
	if absf(absf(difference) - PI) < 1.0e-6: difference = PI
	var limit := deg_to_rad(action.value) * minf(duration, action.duration - frame.elapsed)
	return heading + rad_to_deg(clampf(difference, -limit, limit))

func _step(previous: Frame, duration: float) -> Frame:
	var next := previous.copy()
	var midpoint := previous.state.duplicate()
	if not previous.finished:
		var action := _behavior.actions[previous.index]
		var runtime = _runtime.get_ref()
		runtime._evaluate(action, previous.elapsed + duration * 0.5, previous.initial, midpoint)
		runtime._evaluate(action, previous.elapsed + duration, previous.initial, next.state)
		var heading_action: BulletAction = runtime._heading_actions[previous.index]
		if heading_action != null and heading_action.type == BulletAction.Type.HOMING:
			midpoint.heading = _turn(previous, heading_action, duration * 0.5)
			next.state.heading = _turn(previous, heading_action, duration)
	next.position += _direction.rotated(deg_to_rad(midpoint.heading)) * float(midpoint.speed) * duration
	next.time += duration
	next.elapsed += duration
	_normalize(next)
	return next
