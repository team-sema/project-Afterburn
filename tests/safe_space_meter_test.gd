extends SceneTree

class PathProjectile extends Node2D:
	var points: PackedVector2Array
	var radius := 4.0
	func get_travel_velocity() -> Vector2: return Vector2.DOWN
	func get_predicted_path(_seconds: float) -> PackedVector2Array: return points
	func get_hazard_radius() -> float: return radius

class VelocityProjectile extends Node2D:
	func get_travel_velocity() -> Vector2: return Vector2(0, 105)

var failures := PackedStringArray()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := Node2D.new()
	world.add_child(player)
	var meter := SafeSpaceMeter.new()
	meter.monitored_root = world
	meter.player = player
	meter.set_process(false)
	world.add_child(meter)
	var rect := meter.get_defense_rect()

	_expect(is_equal_approx(meter.measure(), 1.0), "empty field is fully safe")

	# Bounded rasterization must match a brute-force per-cell distance test.
	var random := RandomNumberGenerator.new()
	random.seed = 37191
	var mismatches := 0
	for trial in 80:
		var bullet := PathProjectile.new()
		bullet.add_to_group("enemy_projectiles")
		world.add_child(bullet)
		bullet.radius = random.randf_range(0, 24)
		for i in 12:
			bullet.points.append(rect.position + Vector2(random.randf_range(-80, rect.size.x + 80), random.randf_range(-80, rect.size.y + 80)))
		if trial == 0:
			bullet.points = PackedVector2Array([rect.get_center(), rect.get_center()])
		var radius := bullet.radius + meter.body_hazard_padding
		var blocked := 0
		for row in meter.grid_rows:
			for column in meter.grid_columns:
				var point := rect.position + rect.size * Vector2((column + 0.5) / meter.grid_columns, (row + 0.5) / meter.grid_rows)
				for i in range(1, bullet.points.size()):
					if not meter._segment_intersects_rect(bullet.points[i - 1], bullet.points[i], rect.grow(radius)):
						continue
					if Geometry2D.get_closest_point_to_segment(point, bullet.points[i - 1], bullet.points[i]).distance_to(point) <= radius:
						blocked += 1
						break
		var expected := 1.0 - float(blocked) / (meter.grid_rows * meter.grid_columns)
		if not is_equal_approx(meter.measure(), expected):
			mismatches += 1
		bullet.free()
	_expect(mismatches == 0, "grid rasterization matches brute force (%d mismatches / 80)" % mismatches)

	var projectile := VelocityProjectile.new()
	projectile.add_to_group("enemy_projectiles")
	projectile.position = Vector2(rect.position.x + rect.size.x * 5.5 / meter.grid_columns, rect.position.y - 40.0)
	world.add_child(projectile)
	var sparse := meter.measure()
	_expect(sparse < 1.0, "a shot entering the defense region blocks cells")
	_expect(sparse > 0.5, "a sparse shot leaves most stationary positions safe")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("safe space meter test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
