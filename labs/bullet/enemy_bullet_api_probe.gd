extends Node2D
## Bullet Lab tool for trying EnemyBullets by hand.
## Q: cancel bullets whose centre is near the ship (query_circle).
## E (hold): beam from the ship to the top that cancels whatever its hitbox
## touches (query_shape, so laser bodies count anywhere along them).
## Every cancel arrives through the world hub and leaves a fading mark.

const CIRCLE_RADIUS := 40.0
const BEAM_WIDTH := 8.0
const MARK_SECONDS := 0.5
const MAX_MARKS := 96
const REASON_CIRCLE := &"lab_circle"
const REASON_BEAM := &"lab_beam"

var world: Node2D
var ship: Node2D
## reason -> cancel count reported by the hub.
var counts: Dictionary = {}
var _marks: Array[Dictionary] = []
var _circle_flash := 0.0
var _beam_on := false
var _q_was_down := false


func setup(p_world: Node2D, p_ship: Node2D) -> void:
	world = p_world
	ship = p_ship
	z_index = 20
	EnemyBullets.get_hub(world).bullet_cancelled.connect(_on_bullet_cancelled)


func reset() -> void:
	counts.clear()
	_marks.clear()
	_circle_flash = 0.0
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


func summary() -> String:
	if counts.is_empty():
		return "API: Q 원형 · E 빔"
	var parts := PackedStringArray()
	for reason in counts:
		parts.append("%s %d" % [reason, counts[reason]])
	return "API " + " · ".join(parts)


func _physics_process(delta: float) -> void:
	if world == null or ship == null:
		return
	var q_down := Input.is_physical_key_pressed(KEY_Q)
	if q_down and not _q_was_down:
		cancel_circle()
	_q_was_down = q_down
	_beam_on = Input.is_physical_key_pressed(KEY_E)
	if _beam_on:
		sweep_beam()
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
	for mark in _marks:
		var alpha := 1.0 - float(mark["age"]) / MARK_SECONDS
		var p: Vector2 = mark["position"]
		var color := Color(1.0, 1.0, 1.0, alpha)
		draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), color, 1.0)
		draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), color, 1.0)
