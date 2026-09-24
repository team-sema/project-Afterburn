extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _label(parent: Node, value: String, pos: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _run() -> void:
	root.size = Vector2i(1200, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var world := Node2D.new()
	root.add_child(world)
	var background := ColorRect.new()
	background.color = Color("080d19")
	background.size = Vector2(1200, 720)
	world.add_child(background)
	_label(world, "AFTERBURN / ELITE CASTER", Vector2(42, 26), 30, Color("fff0f3"))
	_label(world, "AIRFRAME CONCEPT 03     /     compact crystal + floating open halo", Vector2(44, 70), 17, Color("9ba6bd"))
	var names := ["enemy_caster", "enemy_elite_fighter", "enemy_elite_awl", "enemy_elite_caster"]
	var labels := ["CASTER", "ELITE FIGHTER", "ELITE AWL", "ELITE CASTER"]
	var descriptions := ["Original ring + crystal", "Broad artillery shoulders", "Long piercing keel", "Floating arcs / crystal core"]
	var scene := load("res://enemies/elite_fighter.tscn") as PackedScene
	for column in names.size():
		var source := FileAccess.get_file_as_string("res://assets/enemies/%s.svg" % names[column])
		var raster := Image.new()
		if raster.load_svg_from_string(source, 4.0) != OK:
			push_error("SVG render failed: " + names[column])
			quit(1)
			return
		if column == 3:
			raster.save_png("res://artifacts/enemy_elite_caster_preview.png")
		var native := Image.new()
		native.load_svg_from_string(source)
		var texture := ImageTexture.create_from_image(native)
		var enemy := scene.instantiate()
		var anchor := enemy.get_node("Anchor") as Node2D
		enemy.remove_child(anchor)
		enemy.free()
		for layer in ["WideGlow", "TightGlow", "Core"]:
			anchor.get_node(layer).texture = texture
		world.add_child(anchor)
		anchor.position = Vector2(150 + column * 300, 290)
		var actual := anchor.duplicate() as Node2D
		world.add_child(actual)
		actual.position.y = 574
		anchor.scale *= 5.0
		_label(world, labels[column], Vector2(30 + column * 300, 447), 22, Color("fff0f3"))
		_label(world, descriptions[column], Vector2(30 + column * 300, 483), 15, Color("9ba6bd"))
	_label(world, "NATIVE SCALE / 0.25 x 1.35", Vector2(44, 639), 16, Color("9ba6bd"))
	_label(world, "White vector mask / shared elite glow / visual concept only", Vector2(44, 670), 16, Color("9ba6bd"))
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/elite_caster_design.png")
	print("elite caster design preview: ", "PASS" if result == OK else "FAIL")
	quit(0 if result == OK else 1)
