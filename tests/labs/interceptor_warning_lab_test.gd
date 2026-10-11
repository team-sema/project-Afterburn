extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	GameSettings.instance.save_enabled = false
	var lab = load("res://labs/hud/interceptor_warning_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	await process_frame
	for style in 3:
		lab.choose(style)
		for side in [false, true]:
			lab.set_side(side)
			lab.replay()
			lab.advance(0.5)
			check(lab.warning_active(), "Warning before deadline")
			lab.toggle_pause()
			lab.advance(1.0)
			check(is_equal_approx(lab.elapsed, 0.5), "Pause freezes warning")
			lab.choose(style)
			check(is_equal_approx(lab.elapsed, 0.5), "Style comparison retains paused time")
			lab.toggle_pause()
			lab.advance(0.41)
			check(not lab.warning_active(), "Warning ends after 0.9 seconds")
	lab.replay()
	lab.slow = true
	lab.advance(1.0)
	check(is_equal_approx(lab.elapsed, 0.35), "Slow playback")
	lab.advance(12.0)
	check(lab.elapsed < 4.0, "Loop bounded")
	check(lab.buttons.size() == 9, "All controls available")
	lab.free()
	await process_frame
	if failures.is_empty(): print("PASS interceptor warning lab: variants, sides, timing, pause, slow, loop")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
