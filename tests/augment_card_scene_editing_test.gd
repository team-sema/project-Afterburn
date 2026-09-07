extends SceneTree


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
		assert(first.scene_file_path == scene.resource_path)
		assert(first.surface != second.surface, "materials must be instance-local")
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
		assert(first.get_node("Title").position == Vector2(20, 80))
		assert(first.get_node("Title").get_theme_color("font_color") == Color.RED)
		assert(first.surface.get_shader_parameter("glow_strength") == 2.0)
		assert(second.surface.get_shader_parameter("glow_strength") == original_glow)
		assert(first.surface.get_shader_parameter("orb_center") == Vector2(70, 45))
		assert(first.surface.get_shader_parameter("halo_radius") == 31.0)
		assert(first.rotating_orbits_enabled and first.particles_enabled)
		assert(is_equal_approx(first.surface.get_shader_parameter("ray_strength"), 0.4))
		first.queue_free()
		second.queue_free()
		await process_frame
	print("augment card scene editing test: PASS")
	quit(0)
