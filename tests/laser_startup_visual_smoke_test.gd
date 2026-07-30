extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var laser_scene := load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene
	var laser := laser_scene.instantiate() as LaserWeaponSystem
	laser.position = Vector2(80.0, 216.0)
	root.add_child(laser)
	var core_line: Line2D = laser.get_node("CoreLine") as Line2D
	var glow_line: Sprite2D = laser.get_node("GlowLine") as Sprite2D

	_expect(is_zero_approx(core_line.width), "laser core starts at zero width")
	_expect(is_zero_approx(glow_line.scale.x), "laser glow starts at zero width")
	_finish_width_tween(laser)
	_expect(is_equal_approx(core_line.width, 1.0), "laser core expands to its base width")
	_expect(is_equal_approx(glow_line.scale.x, 0.053), "laser glow expands to its base width")

	laser.set_beam_width_multiplier(2.0)
	_expect(is_equal_approx(core_line.width, 2.0), "width multiplier updates the laser core")
	_expect(is_equal_approx(glow_line.scale.x, 0.106), "width multiplier updates the laser glow")
	laser.restart_beam_width_animation()
	_expect(is_zero_approx(core_line.width), "restarting fire resets the beam width")
	_finish_width_tween(laser)
	_expect(is_equal_approx(core_line.width, 2.0), "restart expands to the augmented width")

	laser.queue_free()
	await process_frame
	if failures.is_empty():
		print("laser startup visual smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser startup visual smoke test: %s" % failure)
	quit(1)


func _finish_width_tween(laser: LaserWeaponSystem) -> void:
	var tween := laser.get("_beam_width_tween") as Tween
	_expect(tween != null, "laser creates a width tween")
	if tween != null:
		tween.custom_step(laser.beam_expand_duration)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
