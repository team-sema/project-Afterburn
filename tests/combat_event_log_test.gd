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
	# Launch: the window widens to five rows and streams the boot log on the launch clock.
	var launch: LaunchSequence = world.gameplay.get_node("LaunchSequence")
	check(log._rows == 3 and log.size.y == 48.0, "idle log keeps three rows")
	launch.play()
	check(log._rows == 5 and log.size.y == 76.0 and log._ink_viewport.size_2d_override.y == 76 and log._ink.size.y == 70.0, "launch widens the log to five rows")
	launch.advance(0.12)
	check(log.entries.size() == 1 and log.entries[0].key == &"launch_reactor" and is_equal_approx(log.entries[0].lifetime, 1.5), "first boot line at 0.1s with the short launch lifetime")
	launch.advance(0.4)
	log._process(0.4)
	check(log.entries.size() == 4 and log.entries[2].key == &"launch_ignition" and log.entries[2].urgent, "ignition burst stacks four lines with a red ignition")
	log._process(0.09)
	for i in range(1, log.entries.size()):
		check(log.entries[i].label.position.y - log.entries[i-1].label.position.y >= 13.99, "launch burst lines never overlap")
	launch.advance(0.5)
	log._process(0.5)
	check(log.entries.size() == 5 and log.entries[0].key == &"launch_fuel" and log.entries[-1].key == &"launch_dampers", "sixth boot line scrolls the oldest out of five rows")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/indicator-preview/event-log-launch.png")
	launch.advance(1.0)
	check(log.entries.size() == 5 and log.entries[0].key == &"launch_velocity" and log.entries[-1].key == &"launch_controls", "settle lines keep the window full at 2.0s")
	log._process(1.01)
	check(log.entries.size() == 3 and log.entries[0].key == &"launch_canopy" and log._rows == 5, "boot lines expire after 1.5s without shrinking mid-launch")
	launch.advance(0.6)
	check(not launch.is_launching and log.entries.size() == 4 and log.entries[-1].key == &"launch_highlight", "highlight line posts before the launch ends")
	check(is_equal_approx(log.entries[-1].lifetime, 3.5) and log.entries[-1].tone != log.entries[0].tone, "highlight line lingers with its own tone")
	check(log._rows == 5 and log._target_rows == 3, "finished launch waits to shrink while boot lines overflow three rows")
	log._process(0.45)
	check(log.entries.size() == 4 and log._rows == 5, "overflowing boot lines keep five rows after the launch")
	log._process(0.1)
	check(log.entries.size() == 1 and log._rows == 3 and log._box_rows == 5 and log.size.y == 76.0, "fitting rows shrink the layout but keep the box until the slide ends")
	log._process(0.2)
	check(log._box_rows == 3 and log.size.y == 48.0 and log._ink_viewport.size_2d_override.y == 48 and is_equal_approx(log.entries[0].label.position.y, 28.0), "box shrinks after the slide with the last line on the bottom row")
	log._process(1.0)
	check(log.entries.size() == 1 and log.entries[0].key == &"launch_highlight", "highlight stays alone after the boot lines drain")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/indicator-preview/event-log-highlight.png")
	log._process(2.0)
	check(log.entries.is_empty() and not log.is_processing(), "boot log drains completely")
	GameSettings.instance.set_combat_event_log_enabled(false)
	launch.play()
	launch.advance(0.6)
	check(log.entries.is_empty() and log._rows == 5, "disabled log skips boot lines")
	GameSettings.instance.set_combat_event_log_enabled(true)
	launch.advance(2.1)
	log._process(4.0)
	check(not launch.is_launching and log.entries.is_empty() and log._rows == 3 and log.size.y == 48.0, "second launch drains back to three rows")
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
