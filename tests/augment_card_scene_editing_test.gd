extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for tier in 3:
		var path: String = ["silver", "gold", "prismatic"][tier]
		var scene := load("res://menus/cards/augment_card_%s.tscn" % path) as PackedScene
		var first := scene.instantiate()
		var second := scene.instantiate()
		root.add_child(first)
		root.add_child(second)
		await process_frame
		_expect(first.scene_file_path == scene.resource_path, "%s card instance keeps its scene path" % path)
		_expect(first.surface != second.surface, "%s materials must be instance-local" % path)
		var original_glow: Variant = second.surface.get_shader_parameter("glow_strength")
		first.surface.set_shader_parameter("glow_strength", 2.0)
		first.get_node("Title").position = Vector2(20, 80)
		first.get_node("Title").add_theme_color_override("font_color", Color.RED)
		first.get_node("MedallionAnchor").position = Vector2(70, 45)
		first.orbit_radius = 31.0
		# Any preset can opt into each effect; content tier must not override it.
		first.rotating_orbits_enabled = true
		first.particles_enabled = true
		first.surface.set_shader_parameter("ray_strength", 0.4)
		var augment := PlayerAugment.new()
		augment.tier = tier
		augment.display_name = "편집 유지 확인"
		augment.description = "씬의 설정을 유지합니다."
		first.configure(augment, null)
		first._process(0.1)
		_expect(first.get_node("Title").position == Vector2(20, 80), "%s configure keeps the edited title position" % path)
		_expect(first.get_node("Title").get_theme_color("font_color") == Color.RED, "%s configure keeps the title color override" % path)
		_expect(first.surface.get_shader_parameter("glow_strength") == 2.0, "%s keeps edited glow strength" % path)
		_expect(second.surface.get_shader_parameter("glow_strength") == original_glow, "%s edits do not leak into another instance" % path)
		_expect(first.surface.get_shader_parameter("orb_center") == Vector2(70, 45), "%s orb center follows the medallion anchor" % path)
		_expect(first.surface.get_shader_parameter("halo_radius") == 31.0, "%s halo radius follows orbit_radius" % path)
		_expect(first.rotating_orbits_enabled and first.particles_enabled, "%s tier does not override effect toggles" % path)
		_expect(is_equal_approx(first.surface.get_shader_parameter("ray_strength"), 0.4), "%s keeps edited ray strength" % path)
		first.queue_free()
		second.queue_free()
		await process_frame
	if failures.is_empty():
		print("augment card scene editing test: PASS")
		quit()
		return
	for failure in failures:
		push_error("augment card scene editing test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
