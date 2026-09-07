extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 1.0
	root.content_scale_size = Vector2i(960, 540)
	var world := Node2D.new()
	root.add_child(world)
	var background := ColorRect.new()
	background.color = Color("080d19")
	background.size = Vector2(960, 540)
	world.add_child(background)
	var scene := load("res://enemies/elite_fighter.tscn") as PackedScene
	for column in 2:
		var enemy := scene.instantiate()
		var anchor := enemy.get_node("Anchor") as Node2D
		enemy.remove_child(anchor)
		enemy.free()
		world.add_child(anchor)
		anchor.position = Vector2(260 + column * 440, 235)
		anchor.scale *= 5.0
		if column == 0:
			var diffuse := anchor.get_node("DiffuseGlow") as Sprite2D
			diffuse.material = load("res://effects/diffuse_glow_material.tres")
			diffuse.scale = Vector2(0.17, 0.17)
			diffuse.self_modulate = Color(1, 0.15, 0.35, 0.14)
			var wide := anchor.get_node("WideGlow") as Sprite2D
			wide.material = load("res://effects/wide_glow_material.tres")
			wide.scale = Vector2(0.38, 0.38)
			wide.self_modulate = Color(1, 0.12, 0.32, 0.22)
			var tight := anchor.get_node("TightGlow") as Sprite2D
			tight.material = load("res://effects/tight_glow_material.tres")
			tight.scale = Vector2(0.27, 0.27)
			tight.self_modulate = Color(1, 0.25, 0.42, 0.5)
		var actual := anchor.duplicate() as Node2D
		world.add_child(actual)
		actual.scale /= 5.0
		actual.position.y = 450
		var label := Label.new()
		label.text = "BEFORE" if column == 0 else "AFTER"
		label.position = Vector2(190 + column * 440, 40)
		label.add_theme_font_size_override("font_size", 26)
		world.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/elite_glow_comparison.png")
	print("elite glow preview: ", "PASS" if result == OK else "FAIL")
	quit(0 if result == OK else 1)
