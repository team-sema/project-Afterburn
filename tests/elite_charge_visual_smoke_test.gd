extends SceneTree

func _initialize() -> void:
	var visual := preload("res://components/elite_charge_visual.gd").new()
	var failures := 0
	var old_failures := 0
	var checked := 0
	for degrees in range(0, 360, 3):
		for age in [0.0, 0.25, 0.54, 0.549, 0.54999999, 0.55, 0.6]:
			var ember := {"age": age, "size": 2.0, "velocity": Vector2.RIGHT.rotated(deg_to_rad(degrees)) * 85.0}
			var polygon: PackedVector2Array = visual._ember_polygon(ember)
			if not polygon.is_empty():
				checked += 1
				if Geometry2D.triangulate_polygon(polygon).size() != 6: failures += 1
			elif age < 0.549:
				failures += 1
			if age == 0.54999999:
				var center := Vector2(500, 350)
				var fraction: float = age / 0.55
				var heading: Vector2 = ember.velocity.normalized()
				var tail := -heading * lerpf(9, 3, fraction)
				var side := heading.orthogonal() * 2.0 * (1.0 - fraction)
				var old := PackedVector2Array([center - tail * 0.25, center + tail + side, center + tail * 1.6, center + tail - side])
				if Geometry2D.triangulate_polygon(old).is_empty(): old_failures += 1
	if old_failures == 0: failures += 1
	if not visual._ember_polygon({"age": 0.1, "size": 3.0, "velocity": Vector2.ZERO}).is_empty(): failures += 1
	visual.free()
	print("elite charge visual smoke test: ", "PASS" if failures == 0 else "FAIL", " / valid=", checked, " / reproduced legacy failures=", old_failures)
	quit(0 if failures == 0 else 1)
