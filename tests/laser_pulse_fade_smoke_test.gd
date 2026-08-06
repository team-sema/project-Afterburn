extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var laser_scene := load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene
	var laser := laser_scene.instantiate() as LaserWeaponSystem
	root.add_child(laser)
	await process_frame

	var core_line: Line2D = laser.get_node("CoreLine") as Line2D
	var glow_line: Sprite2D = laser.get_node("GlowLine") as Sprite2D
	var base_core_a: float = laser.get("_base_core_alpha")
	var base_glow_a: float = laser.get("_base_glow_alpha")

	laser.set("_pulse_beam_alpha", 0.5)
	laser.call("_apply_pulse_beam_alpha")
	_expect(
		is_equal_approx(core_line.default_color.a, base_core_a * 0.5),
		"pulse alpha scales core line opacity",
	)
	_expect(
		is_equal_approx(glow_line.self_modulate.a, base_glow_a * 0.5),
		"pulse alpha scales glow opacity",
	)

	laser.set("_pulse_beam_alpha", 0.0)
	laser.call("_apply_pulse_beam_alpha")
	_expect(not core_line.visible, "zero pulse alpha hides the core beam")
	_expect(not glow_line.visible, "zero pulse alpha hides the glow beam")

	laser.queue_free()
	await process_frame
	if failures.is_empty():
		print("laser_pulse_fade_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_pulse_fade_smoke_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
