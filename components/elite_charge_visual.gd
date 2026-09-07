extends Node2D

var aiming := false
var locked := false
var direction := Vector2.DOWN
var lane_width := 30.0
var _time := 0.0
var _embers: Array[Dictionary] = []


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_time += delta
	for i in range(_embers.size() - 1, -1, -1):
		_embers[i].age += delta
		_embers[i].position += _embers[i].velocity * delta
		if _embers[i].age >= 0.55:
			_embers.remove_at(i)
	queue_redraw()


func emit_wake(origin: Vector2, dash_direction: Vector2) -> void:
	var side := dash_direction.orthogonal()
	for sign_value in [-1.0, 1.0]:
		if _embers.size() >= 120:
			_embers.pop_front()
		var velocity: Vector2 = (side * float(sign_value)).rotated(randf_range(-0.24, 0.24)) * randf_range(65.0, 105.0)
		_embers.append({"position": origin, "velocity": velocity, "age": 0.0, "size": randf_range(2.0, 4.0)})
	queue_redraw()


func _draw() -> void:
	if aiming:
		var length := get_viewport_rect().size.length() + 80.0
		var side := direction.orthogonal() * lane_width * 0.5
		var finish := direction * length
		var strength := 1.0 if locked else 0.7
		draw_colored_polygon(PackedVector2Array([-side, side, finish + side, finish - side]), Color(1.0, 0.08, 0.2, 0.075 * strength))
		draw_line(-side, finish - side, Color(1.0, 0.22, 0.32, 0.24 * strength), 0.8, true)
		draw_line(side, finish + side, Color(1.0, 0.22, 0.32, 0.24 * strength), 0.8, true)
		# Parallel moving chevrons form a conveyor belt, never a widening cone.
		var offset := fmod(_time * 65.0, 26.0)
		for i in int(length / 26.0):
			var center := direction * (float(i) * 26.0 + offset)
			draw_polyline(PackedVector2Array([center - side * 0.7, center + direction * 7.0, center + side * 0.7]), Color(1.0, 0.25, 0.42, 0.26 * strength), 1.2, true)
	for ember in _embers:
		var age: float = ember.age / 0.55
		var center := to_local(ember.position)
		var velocity: Vector2 = ember.velocity
		var tail := -velocity.normalized() * lerpf(9.0, 3.0, age)
		var side := velocity.normalized().orthogonal() * float(ember.size) * (1.0 - age)
		draw_colored_polygon(PackedVector2Array([center - tail * 0.25, center + tail + side, center + tail * 1.6, center + tail - side]), Color(1.0, lerpf(0.25, 0.08, age), lerpf(0.42, 0.2, age), 0.6 * (1.0 - age)))
