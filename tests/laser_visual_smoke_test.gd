extends SceneTree

## Laser beam visuals: beam shader inputs, startup width tween, pulse fade and
## refraction segments. Each check uses a fresh laser instance.

const LASER_SCENE := preload("res://player_ship/weapons/laser_weapon_system.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	_run.call_deferred()


func _run() -> void:
	await _test_beam_shader()
	await _test_startup_width()
	await _test_pulse_fade()
	await _test_refraction_segments()

	if failures.is_empty():
		print("laser_visual_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_visual_smoke_test: %s" % failure)
	quit(1)


func _spawn_laser() -> LaserWeaponSystem:
	var laser := LASER_SCENE.instantiate() as LaserWeaponSystem
	laser.position = Vector2(80.0, 216.0)
	root.add_child(laser)
	return laser


func _free_laser(laser: LaserWeaponSystem) -> void:
	laser.queue_free()
	await process_frame


## The laser beam shader receives its length and the gameplay clock.
func _test_beam_shader() -> void:
	var laser := _spawn_laser()
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
	await _free_laser(laser)


func _test_startup_width() -> void:
	var laser := _spawn_laser()
	var core_line: Line2D = laser.get_node("CoreLine") as Line2D
	var glow_line: Sprite2D = laser.get_node("GlowLine") as Sprite2D
	_expect(is_zero_approx(core_line.width), "laser core starts at zero width")
	_expect(is_zero_approx(glow_line.scale.x), "laser glow starts at zero width")
	_finish_width_tween(laser)
	_expect(is_equal_approx(core_line.width, 1.0), "laser core expands to its base width")
	_expect(is_equal_approx(glow_line.scale.x, 0.3125), "laser glow expands to its base width")

	laser.set_beam_width_multiplier(2.0)
	_expect(is_equal_approx(core_line.width, 2.0), "width multiplier updates the laser core")
	_expect(is_equal_approx(glow_line.scale.x, 0.625), "width multiplier updates the laser glow")
	laser.restart_beam_width_animation()
	_expect(is_zero_approx(core_line.width), "restarting fire resets the beam width")
	_finish_width_tween(laser)
	_expect(is_equal_approx(core_line.width, 2.0), "restart expands to the augmented width")
	await _free_laser(laser)


func _finish_width_tween(laser: LaserWeaponSystem) -> void:
	var tween := laser.get("_beam_width_tween") as Tween
	_expect(tween != null, "laser creates a width tween")
	if tween != null:
		tween.custom_step(laser.beam_expand_duration)


func _test_pulse_fade() -> void:
	var laser := _spawn_laser()
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
	await _free_laser(laser)


func _test_refraction_segments() -> void:
	var laser := _spawn_laser()
	await process_frame
	var refract_vfx := laser.get_node("RefractVfx")
	_expect(refract_vfx != null, "laser scene contains refract VFX")
	_expect(refract_vfx.material != null, "refract VFX uses an additive material")
	_expect(
		float(refract_vfx.get("glow_width")) > float(refract_vfx.get("core_width")),
		"refract glow is wider than its core",
	)

	var from_global := Vector2(84.0, 140.0)
	var target_global := Vector2(132.0, 104.0)
	laser.call("_show_refract_visual", from_global, target_global)
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 1,
		"a refract hit creates one visible segment",
	)

	refract_vfx.call("_process", float(refract_vfx.get("segment_lifetime")) * 0.5)
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 1,
		"refract segment remains during its fade",
	)
	refract_vfx.call("_process", float(refract_vfx.get("segment_lifetime")))
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 0,
		"refract segment is removed after its lifetime",
	)

	laser.call("_show_refract_visual", target_global, target_global)
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 0,
		"zero-length refract paths stay hidden",
	)
	await _free_laser(laser)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
