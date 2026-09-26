extends SceneTree

## The laser beam shader receives its length and the gameplay clock.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var laser := (load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene).instantiate() as LaserWeaponSystem
	laser.position = Vector2(80.0, 216.0)
	root.add_child(laser)
	await physics_frame
	await physics_frame

	var glow_line := laser.get_node("GlowLine") as Sprite2D
	var beam_material := glow_line.material as ShaderMaterial
	_expect(beam_material != null, "laser glow uses a shader material")
	if beam_material != null:
		_expect(
			beam_material.shader.resource_path == "res://effects/laser_beam.gdshader",
			"laser glow uses the beam shader",
		)
		var expected_length := 216.0 - LaserWeaponSystem.PLAYFIELD_TOP_MARGIN + LaserWeaponSystem.BEAM_LOCAL_START.y
		_expect(
			is_equal_approx(float(beam_material.get_shader_parameter(&"beam_length")), expected_length),
			"beam shader length matches the beam to the playfield top",
		)
		_expect(
			is_equal_approx(float(beam_material.get_shader_parameter(&"beam_time")), float(laser.get("_clock"))),
			"beam shader time follows the gameplay clock",
		)

	laser.queue_free()
	await process_frame
	if failures.is_empty():
		print("laser_beam_shader_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_beam_shader_smoke_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
