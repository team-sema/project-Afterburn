extends SceneTree

class PathProjectile extends Node2D:
	var points: PackedVector2Array
	var radius := 4.0
	func get_threat_velocity() -> Vector2: return Vector2.DOWN
	func get_threat_path(_seconds: float) -> PackedVector2Array: return points
	func get_threat_radius() -> float: return radius

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var monitor := ThreatMonitor.new()
	var player := Node2D.new()
	root.add_child(player)
	monitor.player = player
	var random := RandomNumberGenerator.new()
	random.seed = 37191
	var rect := player.get_viewport_rect()
	rect.position.y += rect.size.y * monitor.defense_region_start_ratio
	rect.size.y *= 1.0 - monitor.defense_region_start_ratio
	var empty: Array[Dictionary] = []
	var failures := 0
	for trial in 80:
		var bullet := PathProjectile.new()
		root.add_child(bullet)
		bullet.radius = random.randf_range(0, 24)
		for i in 12:
			bullet.points.append(rect.position + Vector2(random.randf_range(-80, rect.size.x + 80), random.randf_range(-80, rect.size.y + 80)))
		if trial == 0: bullet.points = PackedVector2Array([rect.get_center(), rect.get_center()])
		var paths: Array[Dictionary] = []
		for i in range(1, bullet.points.size()):
			var radius := bullet.radius + monitor.body_hazard_padding
			if monitor._segment_intersects_rect(bullet.points[i - 1], bullet.points[i], rect.grow(radius)):
				paths.append({"start": bullet.points[i - 1], "end": bullet.points[i], "radius": radius})
		var blocked := 0
		for row in monitor.grid_rows:
			for column in monitor.grid_columns:
				var point := rect.position + rect.size * Vector2((column + 0.5) / monitor.grid_columns, (row + 0.5) / monitor.grid_rows)
				if monitor._is_point_blocked(point, paths, empty, empty): blocked += 1
		var actors: Array[Node] = [bullet]
		var enemies: Array[Node] = []
		var measured := monitor._measure_pattern_space(actors, enemies)
		if not is_equal_approx(measured.space, float(blocked) / (monitor.grid_rows * monitor.grid_columns)):
			failures += 1
		bullet.free()
	monitor.free()
	player.free()
	print("threat grid equivalence: ", "PASS" if failures == 0 else "FAIL", " (80 seeded paths)")
	quit(0 if failures == 0 else 1)
