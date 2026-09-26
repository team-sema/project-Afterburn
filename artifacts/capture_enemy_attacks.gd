extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab := preload("res://labs/enemy_attack/enemy_attack_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	for mode in 3:
		if mode > 0:
			lab.restart(mode)
			await process_frame
			await process_frame
		var capture_time: float = [4.4, 3.3, 3.5][mode]
		while lab.elapsed < capture_time:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/enemy_attack_%s.png" % ["awl", "fighter", "sniper"][mode]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Capture failed: " + path)
			quit(1)
			return
	lab.queue_free()
	await process_frame
	print("enemy attack rendering capture: PASS")
	quit()
