class_name BarragePlayer
extends Node
## Attach to the world; pass an independent emitter and projectile parent to play().

signal volley_fired(projectiles: Array[Node2D])
signal finished

var show_hitbox := false
var running := false
var last_error := ""
## Optional callbacks: may_fire() -> bool, resolve_target() -> Node2D.
var may_fire := Callable()
var resolve_target := Callable()
var time_scale := 1.0
var _sequence: BarrageSequence
var _emitter: Node2D
var _projectile_parent: Node2D
var _target: Node2D
var _needs_target := false
var _paused := false
var _index := 0
var _cycle := 0
var _rotation := 0.0
var _locked_aim := Vector2.DOWN
var _has_locked_aim := false
var _wait_left := 0.0
var _credit := 0.0
var _generation := 0
var _bindings: Array[Node] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(false)

func play(sequence: BarrageSequence, emitter: Node2D, projectile_parent: Node2D, target: Node2D = null) -> bool:
	stop()
	last_error = "Missing sequence." if sequence == null else sequence.validation_error()
	if not last_error.is_empty():
		return false
	if not is_inside_tree() or not _alive(emitter) or not _alive(projectile_parent):
		last_error = "Player, emitter and projectile parent must be inside the tree."
		return false
	if emitter == projectile_parent or emitter.is_ancestor_of(projectile_parent) or emitter.get_viewport() != projectile_parent.get_viewport() or get_viewport() != emitter.get_viewport():
		last_error = "Use an independent projectile parent in the same viewport."
		return false
	_needs_target = sequence.needs_target()
	if _needs_target and not resolve_target.is_valid() and (not _alive(target) or target.get_viewport() != emitter.get_viewport()):
		last_error = "An aimed volley needs a target in the same viewport."
		return false
	_sequence = sequence.snapshot()
	_emitter = emitter
	_projectile_parent = projectile_parent
	_target = target
	_bind_lifetime(emitter)
	_bind_lifetime(projectile_parent)
	if _needs_target and not resolve_target.is_valid():
		_bind_lifetime(target)
	_index = 0
	_cycle = 0
	_rotation = 0
	_locked_aim = Vector2.DOWN
	_has_locked_aim = false
	_wait_left = 0
	_credit = 0
	_paused = false
	running = true
	set_physics_process(true)
	advance(0)
	return true

func stop() -> void:
	_generation += 1
	running = false
	_sequence = null
	for node in _bindings:
		if is_instance_valid(node) and node.tree_exiting.is_connected(stop):
			node.tree_exiting.disconnect(stop)
	_bindings.clear()
	set_physics_process(false)

func _bind_lifetime(node: Node) -> void:
	if node not in _bindings:
		_bindings.append(node)
		node.tree_exiting.connect(stop)

func pause() -> void:
	_paused = true

func resume() -> void:
	_paused = false

func _physics_process(delta: float) -> void:
	advance(delta)

func _exit_tree() -> void:
	stop()

func advance(seconds: float) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not running or _paused or get_tree().paused or not is_finite(seconds) or seconds < 0:
		return
	if not _alive(_emitter) or not _alive(_projectile_parent) or (_needs_target and not resolve_target.is_valid() and not _alive(_target)):
		stop()
		return
	if not is_finite(time_scale) or time_scale <= 0:
		return
	_credit += seconds * time_scale
	var generation := _generation
	var emitted := 0
	for operation in 256:
		if _wait_left > _credit + 0.000000001:
			_wait_left -= _credit
			_credit = 0
			return
		_credit = maxf(0, _credit - _wait_left)
		_wait_left = 0
		if _index == _sequence.steps.size():
			_cycle += 1
			if _sequence.repeat_count > 0 and _cycle >= _sequence.repeat_count:
				stop()
				finished.emit()
				return
			_index = 0
		var step := _sequence.steps[_index]
		_index += 1
		match step.action:
			BarrageStep.Action.WAIT:
				_wait_left = step.value
			BarrageStep.Action.ROTATE:
				_rotation = fposmod(_rotation + step.value, 360.0)
			BarrageStep.Action.ROTATE_TO:
				_rotation = fposmod(step.value, 360.0)
			BarrageStep.Action.AIM:
				var target := _target
				if resolve_target.is_valid():
					target = resolve_target.call() as Node2D
					if generation != _generation or not running: return
					if not _alive(_emitter) or not _alive(_projectile_parent):
						stop()
						return
				# A missing or overlapping target keeps the previous lock.
				if _alive(target) and target.get_viewport() == _emitter.get_viewport():
					var toward := target.global_position - _emitter.global_position
					if not toward.is_zero_approx():
						_locked_aim = toward.normalized()
						_has_locked_aim = true
			BarrageStep.Action.FIRE:
				var allowed := not may_fire.is_valid() or bool(may_fire.call())
				if generation != _generation or not running: return
				if not _alive(_emitter) or not _alive(_projectile_parent):
					stop()
					return
				if not allowed: continue
				var count := 0
				for volley in step.get_volleys():
					count += 1 if volley.layout == BarrageVolley.Layout.SINGLE else volley.count
				if emitted + count > 4096:
					_index -= 1
					return
				emitted += count
				var spawned: Array[Node2D] = []
				var target := _target
				if _needs_target and resolve_target.is_valid():
					target = resolve_target.call() as Node2D
					if generation != _generation or not running: return
					if not _alive(_emitter) or not _alive(_projectile_parent):
						stop()
						return
				for volley in step.get_volleys():
					var origin := _emitter.to_global(volley.origin_offset)
					var aim := Vector2.DOWN
					var rotation := _rotation
					match volley.aim:
						BarrageVolley.Aim.EACH_SHOT:
							if not _alive(target) or target.get_viewport() != _emitter.get_viewport():
								continue
							aim = target.global_position - origin
						BarrageVolley.Aim.LOCKED:
							if not _has_locked_aim:
								continue
							aim = _locked_aim
						_:
							if volley.relative_to_emitter:
								rotation += rad_to_deg(_emitter.global_rotation)
					for direction in volley.directions(rotation, aim):
						var projectile := volley.shot.spawn(_projectile_parent, origin, direction, volley.speed, show_hitbox, target if is_instance_valid(target) else null, resolve_target)
						# A homing resolver may stop/replace playback during spawn.
						if generation != _generation or not running: return
						if not _alive(_emitter) or not _alive(_projectile_parent):
							stop()
							return
						if projectile != null:
							spawned.append(projectile)
				volley_fired.emit(spawned)
				# Callbacks may stop/replace the sequence or delete the emitter.
				if generation != _generation or not running:
					return
				if _paused or get_tree().paused or is_queued_for_deletion():
					return
				if not _alive(_emitter) or not _alive(_projectile_parent) or (_needs_target and not resolve_target.is_valid() and not _alive(_target)):
					stop()
					return

func _alive(node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
