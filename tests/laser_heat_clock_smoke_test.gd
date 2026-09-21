extends SceneTree

## laser_heat_stack intervals must run on gameplay time: a paused tree
## (augment pick / bullet cancel) leaves the laser clock untouched.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var laser := (load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene).instantiate() as LaserWeaponSystem
	root.add_child(laser)
	await physics_frame
	await physics_frame
	var before: float = laser.get("_clock")
	_expect(before > 0.0, "laser clock advances while the tree runs")

	paused = true
	await create_timer(0.2).timeout
	var during: float = laser.get("_clock")
	_expect(is_equal_approx(before, during), "paused tree does not advance the laser heat clock")

	paused = false
	await physics_frame
	await physics_frame
	var after: float = laser.get("_clock")
	_expect(after > during, "laser clock resumes after unpause")

	laser.queue_free()
	await process_frame
	if failures.is_empty():
		print("laser_heat_clock_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_heat_clock_smoke_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
