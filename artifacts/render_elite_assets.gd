extends SceneTree


func _initialize() -> void:
	for asset in ["enemy_elite_fighter", "enemy_elite_awl", "enemy_awl"]:
		var source := FileAccess.get_file_as_string("res://assets/svg/%s.svg" % asset)
		var image := Image.new()
		var result := image.load_svg_from_string(source, 4.0)
		if result != OK:
			push_error("SVG render failed: %s" % asset)
			quit(1)
			return
		image.save_png("res://artifacts/%s_preview.png" % asset)
	print("elite SVG render: PASS")
	quit(0)
