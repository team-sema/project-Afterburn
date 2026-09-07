extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(480, 600)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 1.0
	root.content_scale_size = Vector2i(480, 600)
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var background := ColorRect.new()
	background.size = Vector2(480, 600)
	background.color = Color("0b1325")
	background.z_index = -100
	world.add_child(background)
	var label := Label.new()
	label.position = Vector2(24, 22)
	label.text = "TRACKING / CONVEYOR LANE"
	world.add_child(label)
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	var player := Polygon2D.new()
	player.polygon = PackedVector2Array([Vector2(0, -9), Vector2(-6, 6), Vector2(6, 6)])
	player.color = Color(0.2, 0.8, 1.0)
	player.position = Vector2(130, 490)
	player.add_to_group("player")
	world.add_child(player)
	var elite := (load("res://enemies/elite_awl.tscn") as PackedScene).instantiate() as Enemy
	elite.augment_registry = registry
	world.add_child(elite)
	await process_frame
	elite.movement_controller.stop()
	elite.position = Vector2(310, 115)
	var attack = elite.get_node("EnemyShootComponent")
	attack.set_process(false)
	attack._begin_recovery()
	attack._process(1.21)
	attack._process(0.3)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/charge_lane_preview.png")
	label.text = "DASH / FLAME WAKE"
	attack.set_process(true)
	await create_timer(1.12).timeout
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/charge_flame_preview.png")
	print("charge motion preview: PASS")
	quit(0)
