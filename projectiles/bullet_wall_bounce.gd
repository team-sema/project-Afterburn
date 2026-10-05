class_name BulletWallBounce
extends RefCounted
## Wall reflection for one bullet body (combat.md 벽 반사). The body's own
## trajectory stays unbounded; this folds it at the walls. Bounces are found by
## scanning that trajectory forward in time, so the moving body, history
## (laser tails) and prediction all see the same reflected path. A bounce is a
## mirror across the wall line, an isometry, so the path stays continuous and
## keeps going straight once the bounce budget is spent.

enum { LEFT = 1, RIGHT = 2, TOP = 4, BOTTOM = 8 }
const SIDES := LEFT | RIGHT
const ALL := LEFT | RIGHT | TOP | BOTTOM
## Crossings are searched one frame apart, then pinned down by bisection; a
## path that leaves and re-enters within one step (a graze) does not bounce.
const SCAN_STEP := 1.0 / 60.0
const BISECT_STEPS := 18
## Safety stop for pathological paths (e.g. a bullet hugging a corner).
const MAX_EVENTS := 256

## (time: float) -> Vector2, the unbounded world position.
var _source: Callable
var _low: Vector2
var _high: Vector2
var _walls := 0
var _max_bounces := 0
var _limit := 0.0
## Bounces found so far, oldest first: {time, axis, line}.
var _events: Array[Dictionary] = []
var _scanned_until := 0.0
var _exhausted := false
## Composition of all known bounces: folded = unbounded * scale + offset.
var _mirror_scale := Vector2.ONE
var _mirror_offset := Vector2.ZERO
## Enabled walls as (axis, line, outward sign) triplets.
var _sides := PackedFloat32Array()
var _hit_time := 0.0
## Time of the newest known bounce (-INF if none), for the fast fold path.
var _last_event_time := -INF


## `rect` is the playfield in world space; walls sit `radius` inside it so the
## bullet's edge, not its centre, touches the wall. `max_bounces` 0 = unlimited.
func _init(source: Callable, rect: Rect2, radius: float, walls: int, max_bounces: int, lifetime: float) -> void:
	_source = source
	_low = rect.position + Vector2.ONE * radius
	_high = rect.end - Vector2.ONE * radius
	_walls = walls
	_max_bounces = max_bounces
	_limit = lifetime
	if walls & LEFT: _sides.append_array([0, _low.x, -1.0])
	if walls & RIGHT: _sides.append_array([0, _high.x, 1.0])
	if walls & TOP: _sides.append_array([1, _low.y, -1.0])
	if walls & BOTTOM: _sides.append_array([1, _high.y, 1.0])


func position_at(time: float) -> Vector2:
	var t := clampf(time, 0.0, _limit)
	_scan_to(t)
	return _fold(_source.call(t), t)


## Folds an unbounded world `point` that the trajectory reaches at `time`.
func fold_point(point: Vector2, time: float) -> Vector2:
	if time > _scanned_until:
		_scan_to(clampf(time, 0.0, _limit))
	if _last_event_time <= time:
		return point * _mirror_scale + _mirror_offset
	return _fold(point, time)


## Reflects an unbounded velocity (or direction) the same way as the position at `time`.
func reflect_vector(time: float, vector: Vector2) -> Vector2:
	_scan_to(clampf(time, 0.0, _limit))
	for event in _events:
		if float(event.time) > time:
			break
		vector[int(event.axis)] = -vector[int(event.axis)]
	return vector


## +1 or -1: mirroring flips turning direction, so a heading offset registered
## in world terms must be multiplied by this before reaching the unbounded path.
func handedness(time: float) -> float:
	return -1.0 if bounces_until(time) % 2 == 1 else 1.0


func bounces_until(time: float) -> int:
	_scan_to(clampf(time, 0.0, _limit))
	var count := 0
	for event in _events:
		if float(event.time) > time:
			break
		count += 1
	return count


## The trajectory after `time` changed (external effect): forget later bounces.
func invalidate_after(time: float) -> void:
	while not _events.is_empty() and float(_events[-1].time) > time:
		_events.pop_back()
	_rebuild_mirror()
	# Remaining events all happened at or before `time`.
	_scanned_until = minf(_scanned_until, time)
	_exhausted = false


func _fold(point: Vector2, time: float) -> Vector2:
	# Fast path: every known bounce is at or before `time`.
	if _last_event_time <= time:
		return point * _mirror_scale + _mirror_offset
	for event in _events:
		if float(event.time) > time:
			break
		var axis := int(event.axis)
		point[axis] = 2.0 * float(event.line) - point[axis]
	return point


func _budget_left() -> bool:
	return _max_bounces <= 0 or _events.size() < _max_bounces


func _add_event(time: float, axis: int, line: float) -> void:
	_events.append({"time": time, "axis": axis, "line": line})
	_last_event_time = time
	# x' = s*x + o mirrored across `line` becomes -s*x + (2*line - o).
	_mirror_scale[axis] = -_mirror_scale[axis]
	_mirror_offset[axis] = 2.0 * line - _mirror_offset[axis]


func _rebuild_mirror() -> void:
	_mirror_scale = Vector2.ONE
	_mirror_offset = Vector2.ZERO
	_last_event_time = float(_events[-1].time) if not _events.is_empty() else -INF
	for event in _events:
		var axis := int(event.axis)
		_mirror_scale[axis] = -_mirror_scale[axis]
		_mirror_offset[axis] = 2.0 * float(event.line) - _mirror_offset[axis]


func _scan_to(time: float) -> void:
	if _scanned_until >= time - 1.0e-9 or _exhausted:
		return
	var before := _fold(_source.call(_scanned_until), _scanned_until)
	while _scanned_until < time - 1.0e-9:
		if not _budget_left() or _events.size() >= MAX_EVENTS:
			# Nothing can bounce any more: the rest of the path is a fixed mirror.
			_scanned_until = _limit
			_exhausted = true
			return
		var from := _scanned_until
		var to := minf(from + SCAN_STEP, time)
		# Folded with the bounces known at `from`; a crossing shows up as
		# leaving the inner box on an enabled side.
		var after := (_source.call(to) as Vector2) * _mirror_scale + _mirror_offset
		var hit := _first_crossing(before, after, from, to)
		if hit < 0:
			_scanned_until = to
			before = after
			continue
		_scanned_until = _hit_time
		_add_event(_hit_time, int(_sides[hit]), _sides[hit + 1])
		before = _fold(_source.call(_scanned_until), _scanned_until)


## Index into _sides of the earliest wall crossed between `from` and `to`
## (its time in _hit_time), or -1.
func _first_crossing(before: Vector2, after: Vector2, from: float, to: float) -> int:
	var best := -1
	for index in range(0, _sides.size(), 3):
		var axis := int(_sides[index])
		var line := _sides[index + 1]
		var outward := _sides[index + 2]
		# Only a move from inside (or on) the wall to beyond it bounces, so a
		# bullet fired from outside the playfield enters freely.
		if (before[axis] - line) * outward > 1.0e-6 or (after[axis] - line) * outward <= 0.0:
			continue
		var time := _bisect(axis, line, outward, from, to)
		if best < 0 or time < _hit_time:
			best = index
			_hit_time = time
	return best


func _bisect(axis: int, line: float, outward: float, from: float, to: float) -> float:
	var low := from
	var high := to
	for _i in BISECT_STEPS:
		var middle := (low + high) * 0.5
		var point := (_source.call(middle) as Vector2) * _mirror_scale + _mirror_offset
		if (point[axis] - line) * outward > 0.0:
			high = middle
		else:
			low = middle
	return high
