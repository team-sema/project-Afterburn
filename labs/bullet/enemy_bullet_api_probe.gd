extends Node2D
## Bullet Lab tool for trying EnemyBullets by hand.
## Q: cancel bullets whose centre is near the ship (query_circle).
## E (hold): beam from the ship to the top that cancels whatever its hitbox
## touches (query_shape, so laser bodies count anywhere along them).
## R (hold): slow field around the ship (apply_effect speed multiplier; wears
## off shortly after a bullet leaves).
## F: drop a gravity well at the ship for a few seconds; bullets inside keep
## bending toward it (apply_effect heading offset, accumulated each tick).
## Every cancel arrives through the world hub and leaves a fading mark.

const CIRCLE_RADIUS := 40.0
const BEAM_WIDTH := 8.0
const MARK_SECONDS := 0.5
const MAX_MARKS := 96
const REASON_CIRCLE := &"lab_circle"
const REASON_BEAM := &"lab_beam"
const SLOW_HANDLE := &"lab_slow"
const SLOW_RADIUS := 60.0
const SLOW_MULT := 0.35
## Re-applied every tick, so the slow ends this long after a bullet leaves.
const SLOW_LINGER := 0.15
const PULL_HANDLE := &"lab_pull"
const WELL_RADIUS := 90.0
const WELL_SECONDS := 3.0
const PULL_TURN_DEG_PER_SEC := 240.0
const PULL_SPEED_MULT := 0.85

var world: Node2D
var ship: Node2D
## reason -> cancel count reported by the hub.
var counts: Dictionary = {}
## Bullets touched by the slow field / gravity well on the last tick.
var slowed := 0
var pulled := 0
var _marks: Array[Dictionary] = []
var _circle_flash := 0.0
var _beam_on := false
var _slow_on := false
var _well_position := Vector2.ZERO
var _well_left := 0.0
var _q_was_down := false
var _f_was_down := false


func setup(p_world: Node2D, p_ship: Node2D) -> void:
	world = p_world
	ship = p_ship
	z_index = 20
	EnemyBullets.get_hub(world).bullet_cancelled.connect(_on_bullet_cancelled)


func reset() -> void:
	counts.clear()
	_marks.clear()
	_circle_flash = 0.0
	_well_left = 0.0
	slowed = 0
	pulled = 0
	queue_redraw()


func cancel_circle() -> int:
	_circle_flash = 1.0
	return EnemyBullets.cancel_all(
		world,
		EnemyBullets.query_circle(world, ship.global_position, CIRCLE_RADIUS),
		REASON_CIRCLE,
	)


func sweep_beam() -> int:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BEAM_WIDTH, ship.global_position.y)
	var center := Vector2(ship.global_position.x, ship.global_position.y * 0.5)
	return EnemyBullets.cancel_all(
		world,
		EnemyBullets.query_shape(world, shape, Transform2D(0.0, center)),
		REASON_BEAM,
	)


## One tick of the slow field; returns how many bullets it touched.
func apply_slow_field() -> int:
	var count := 0
	for bullet in EnemyBullets.query_circle(world, ship.global_position, SLOW_RADIUS):
		if EnemyBullets.apply_effect(bullet, SLOW_HANDLE, SLOW_MULT, 0.0, SLOW_LINGER):
			count += 1
	return count


func place_well(at: Vector2) -> void:
	_well_position = at
	_well_left = WELL_SECONDS


## One tick of the gravity well: turn each bullet's travel toward the well by at
## most PULL_TURN_DEG_PER_SEC * delta, keeping the accumulated offset.
func pull_step(delta: float) -> int:
	if _well_left <= 0.0:
		return 0
	var count := 0
	var max_turn := deg_to_rad(PULL_TURN_DEG_PER_SEC) * delta
	for bullet in EnemyBullets.query_circle(world, _well_position, WELL_RADIUS):
		if not bullet.has_method("get_travel_velocity"):
			continue
		var velocity: Vector2 = bullet.call("get_travel_velocity")
		var toward := _well_position - bullet.global_position
		if velocity.is_zero_approx() or toward.is_zero_approx():
			continue
		var turn := clampf(velocity.angle_to(toward), -max_turn, max_turn)
		var offset := float(EnemyBullets.get_effect(bullet, PULL_HANDLE).get("heading_offset", 0.0))
		if EnemyBullets.apply_effect(bullet, PULL_HANDLE, PULL_SPEED_MULT, offset + rad_to_deg(turn)):
			count += 1
	return count


## Short status text; empty until the tools have done something.
func summary() -> String:
	var parts := PackedStringArray()
	for reason in counts:
		parts.append("%s %d" % [reason, counts[reason]])
	if slowed > 0:
		parts.append("감속 %d" % slowed)
	if pulled > 0:
		parts.append("흡인 %d" % pulled)
	return "" if parts.is_empty() else "API " + " · ".join(parts)


func _physics_process(delta: float) -> void:
	if world == null or ship == null:
		return
	var q_down := Input.is_physical_key_pressed(KEY_Q)
	if q_down and not _q_was_down:
		cancel_circle()
	_q_was_down = q_down
	var f_down := Input.is_physical_key_pressed(KEY_F)
	if f_down and not _f_was_down:
		place_well(ship.global_position)
	_f_was_down = f_down
	_beam_on = Input.is_physical_key_pressed(KEY_E)
	if _beam_on:
		sweep_beam()
	_slow_on = Input.is_physical_key_pressed(KEY_R)
	slowed = apply_slow_field() if _slow_on else 0
	pulled = pull_step(delta)
	_well_left = maxf(0.0, _well_left - delta)
	_circle_flash = maxf(0.0, _circle_flash - delta * 3.0)
	for mark in _marks:
		mark["age"] = float(mark["age"]) + delta
	_marks = _marks.filter(func(mark: Dictionary) -> bool: return float(mark["age"]) < MARK_SECONDS)
	queue_redraw()


func _on_bullet_cancelled(position: Vector2, reason: StringName, _bullet: Node2D) -> void:
	counts[reason] = int(counts.get(reason, 0)) + 1
	if _marks.size() < MAX_MARKS:
		_marks.append({"position": to_local(position), "age": 0.0})


func _draw() -> void:
	if ship == null:
		return
	var ship_local := to_local(ship.global_position)
	if _circle_flash > 0.0:
		draw_arc(ship_local, CIRCLE_RADIUS, 0.0, TAU, 48, Color(0.4, 0.95, 1.0, _circle_flash), 1.5)
	if _beam_on:
		# The probe sits at the world origin, so y = 0 is the field top.
		draw_rect(Rect2(ship_local.x - BEAM_WIDTH * 0.5, 0.0, BEAM_WIDTH, ship_local.y), Color(1.0, 0.85, 0.3, 0.35))
	if _slow_on:
		draw_circle(ship_local, SLOW_RADIUS, Color(0.35, 0.6, 1.0, 0.12))
		draw_arc(ship_local, SLOW_RADIUS, 0.0, TAU, 48, Color(0.35, 0.6, 1.0, 0.7), 1.0)
	if _well_left > 0.0:
		var well := to_local(_well_position)
		var strength := _well_left / WELL_SECONDS
		draw_circle(well, 5.0, Color(0.75, 0.4, 1.0, 0.9))
		draw_arc(well, WELL_RADIUS, 0.0, TAU, 56, Color(0.75, 0.4, 1.0, 0.25 + 0.5 * strength), 1.0)
		draw_arc(well, WELL_RADIUS * strength, 0.0, TAU, 40, Color(0.75, 0.4, 1.0, 0.35), 1.0)
	for mark in _marks:
		var alpha := 1.0 - float(mark["age"]) / MARK_SECONDS
		var p: Vector2 = mark["position"]
		var color := Color(1.0, 1.0, 1.0, alpha)
		draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), color, 1.0)
		draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), color, 1.0)
