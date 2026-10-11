extends SceneTree
var failures := PackedStringArray()
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	GameSettings.instance.save_enabled = false
	var world = load("res://world.tscn").instantiate()
	root.add_child(world)
	for i in 3: await process_frame
	var hud = world.get_node("Layout/CockpitHud")
	var shield: ShieldComponent = world.gameplay.get_node("Ship/ShieldComponent")
	var mat: ShaderMaterial = hud.panels[0].get_child(0).material
	check(not hud.is_processing(), "normal lamps have no per-frame updates")
	shield.add_shield(2)
	shield.absorb_damage(1)
	check(not hud._shield_warning, "nonzero partial shield remains amber")
	shield.absorb_damage(99)
	hud.set_process(false)
	check(hud._shield_warning and mat.get_shader_parameter("lamp_blend") == 1.0, "depletion starts red warning")
	check(is_equal_approx(mat.get_shader_parameter("lamp_brightness"), 1.65), "break starts with localized bright flash")
	hud._process(hud.BREAK_DURATION)
	check(hud._transition.is_empty() and mat.get_shader_parameter("lamp_color") == Color.RED, "break settles into red warning")
	hud._process(0.4)
	check(is_equal_approx(mat.get_shader_parameter("lamp_brightness"), 0.18), "half-period is dim red")
	shield.absorb_damage(1)
	check(is_equal_approx(hud._warning_elapsed, 0.4), "zero-shield hits do not reset phase")
	hud.set_process(true)
	paused = true
	var before: float = hud._warning_elapsed
	for i in 4: await process_frame
	check(hud._warning_elapsed == before, "pause freezes warning phase")
	paused = false
	await process_frame
	await process_frame
	check(hud._warning_elapsed != before, "resume advances phase")
	shield.restore_shield(1)
	hud.set_process(false)
	check(not hud._shield_warning and hud._transition == "recovery", "one shield point starts recovery confirmation")
	check(mat.get_shader_parameter("lamp_color") == hud.RECOVERY_COLOR, "recovery immediately lights green")
	hud._process(0.2)
	var recovery_age: float = hud._transition_elapsed
	shield.restore_shield(1)
	check(hud._transition_elapsed == recovery_age, "additional recovery does not restart confirmation")
	hud.set_process(true)
	paused = true
	for i in 3: await process_frame
	check(hud._transition_elapsed == recovery_age, "pause freezes recovery")
	paused = false
	hud.set_process(false)
	shield.absorb_damage(99)
	check(hud._transition == "break", "new depletion interrupts recovery immediately")
	shield.restore_shield(1)
	hud._process(hud.RECOVERY_DURATION)
	check(not hud.is_processing() and hud._transition.is_empty(), "recovery ends without per-frame work")
	for panel in hud.panels:
		var material: ShaderMaterial = panel.get_child(0).material
		check(material.get_shader_parameter("lamp_blend") == 0.0 and material.get_shader_parameter("lamp_brightness") == 1.0, "all panels restore original amber")
	hud.set_indicator_style(Color.GREEN, 1.0, 0.5)
	check(mat.get_shader_parameter("lamp_color") == Color.GREEN, "code can select green")
	if DisplayServer.get_name() != "headless":
		await check_render(hud)
	var zero_start = load("res://menus/cockpit_hud.gd").new()
	zero_start._on_shield_changed(0, 0)
	check(zero_start._shield_warning and zero_start._transition.is_empty(), "initial zero shield skips break flash")
	zero_start.free()
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS cockpit indicators: shield events, recovery, pause, style API and available renderer")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
func capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func check_render(hud: Control) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1672, 941)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect := TextureRect.new()
	rect.texture = hud.FRAME
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = hud.POWER
	material.set_shader_parameter("lamp_mask", hud.LAMP_MASK)
	rect.material = material
	viewport.add_child(rect)
	var normal := await capture(viewport)
	material.set_shader_parameter("lamp_blend", 1.0)
	var red := await capture(viewport)
	material.set_shader_parameter("lamp_brightness", 0.18)
	var dim := await capture(viewport)
	material.set_shader_parameter("lamp_color", hud.BREAK_COLOR)
	material.set_shader_parameter("lamp_brightness", 1.65)
	var broken := await capture(viewport)
	material.set_shader_parameter("lamp_color", hud.RECOVERY_COLOR)
	material.set_shader_parameter("lamp_brightness", 1.25)
	var restored := await capture(viewport)
	var mask: Image = hud.LAMP_MASK.get_image()
	var outside_changed := 0
	for y in range(1, 940, 3):
		for x in range(1, 1671, 3):
			if mask.get_pixel(x,y).r == 0.0 and mask.get_pixel(x-1,y).r == 0.0 and mask.get_pixel(x+1,y).r == 0.0 and mask.get_pixel(x,y-1).r == 0.0 and mask.get_pixel(x,y+1).r == 0.0:
				# GPU readback can differ by one 8-bit step at translucent edges.
				var a := normal.get_pixel(x,y)
				for b in [red.get_pixel(x,y), dim.get_pixel(x,y), broken.get_pixel(x,y), restored.get_pixel(x,y)]:
					if maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))) > 1.01 / 255.0 or a.a != b.a:
						outside_changed += 1
	check(outside_changed == 0, "render leaves all sampled pixels outside mask unchanged")
	var bright := red.get_pixel(350,17)
	check(bright.r > bright.g * 1.2, "rendered lamp becomes red")
	check(dim.get_pixel(350,17).r < bright.r * 0.5, "rendered lamp dims")
	DirAccess.make_dir_recursive_absolute("res://.godot/indicator-preview")
	broken.save_png("res://.godot/indicator-preview/runtime-break.png")
	restored.save_png("res://.godot/indicator-preview/runtime-recovery.png")
	check(restored.get_pixel(350,17).g > restored.get_pixel(350,17).r, "recovery renders green")
	normal.save_png("res://.godot/indicator-preview/runtime-normal.png")
	red.save_png("res://.godot/indicator-preview/runtime-red.png")
	dim.save_png("res://.godot/indicator-preview/runtime-dim.png")
	print("Render outside-mask changes: ", outside_changed)
	viewport.queue_free()
