extends SceneTree
var failures := PackedStringArray()
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	GameSettings.instance.save_enabled = false
	GameSettings.instance.set_combat_event_log_enabled(true)
	var world = load("res://world.tscn").instantiate()
	root.add_child(world)
	for i in 3: await process_frame
	var log = world.get_node("Layout/CombatEventLog")
	var shield: ShieldComponent = world.gameplay.get_node("Ship/ShieldComponent")
	check(log.entries.is_empty(), "no startup notification")
	check(log._ink_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "empty projection does not render")
	shield.absorb_damage(99)
	check(log.entries.size() == 1 and log.entries[0].key == &"shield_lost", "shield break adds warning")
	log._process(0.2)
	shield.restore_shield(1)
	var hud = world.get_node("Layout/LeftPanel/Margin/VBox/ProgressionHud")
	hud.progression.experience_changed.emit(5,5,1)
	check(log.entries.size() == 3, "shield recovery and augment ready fill three rows")
	hud.progression.experience_changed.emit(5,5,1)
	check(log.entries.size() == 3, "repeat state does not duplicate")
	log._process(0.09)
	for i in range(1, log.entries.size()):
		check(log.entries[i].label.position.y - log.entries[i-1].label.position.y >= 13.99, "burst lines never overlap during slide")
	log._process(0.11)
	check(log.entries[0].age > log.entries[2].age, "new lines do not extend older lifetimes")
	paused = true
	var age: float = log.entries[0].age
	var scan_age: float = log._scan_age
	for i in 3: await process_frame
	check(log.entries[0].age == age, "pause freezes log")
	check(log._scan_age == scan_age, "pause freezes projection scan")
	paused = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/indicator-preview/event-log.png")
	log.post_event(&"fourth", "SYSTEM READY")
	check(log.entries.size() == 3 and log.entries[0].key == &"shield_online", "fourth displaces oldest")
	log.post_event(&"fourth", "SYSTEM READY")
	check(log.entries.size() == 3, "duplicate key suppressed")
	GameSettings.instance.set_combat_event_log_enabled(false)
	check(log.entries.is_empty() and not log.visible, "disable clears immediately")
	check(log._ink_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "disabled log stops offscreen rendering")
	shield.absorb_damage(99)
	GameSettings.instance.set_combat_event_log_enabled(true)
	check(log.entries.is_empty(), "disabled events never replay")
	shield.restore_shield(1)
	check(log.entries.size() == 1, "state tracking continues while disabled")
	log._process(3.0)
	check(log.entries.is_empty() and not log.is_processing(), "expiry removes all rows and stops work")
	check(not log._display.visible and log._ink_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "expiry hides stale viewport texture")
	if DisplayServer.get_name() != "headless":
		world.settings_menu.open()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/indicator-preview/event-log-settings.png")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS combat event log")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
