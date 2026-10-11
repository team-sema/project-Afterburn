extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var mark := DangerIndicator.new()
	mark.auto_advance = false
	mark.warning_color = Color(1, 0.2, 0.3, 0.4)
	mark.warning_scale = 0.7
	mark.warning_duration = 0.6
	root.add_child(mark)
	for inward in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP]:
		mark.inward_direction = inward
		mark.trajectory_direction = inward.rotated(0.3)
		check(mark.local_trajectory().rotated(inward.angle()).dot(mark.trajectory_direction) > 0.999, "Actual trajectory preserved on all edges")
	check(is_equal_approx(mark._color(0.5).a, 0.2), "Configured alpha retained")
	mark.set_preview_time(0.61)
	check(not mark.visible and not mark.is_warning_active(), "Preview expires")
	mark.set_preview_time(0.1)
	check(mark.visible and mark.is_warning_active(), "Preview rewinds")
	mark.auto_advance = true
	mark._process(0.51)
	check(mark.is_queued_for_deletion(), "Live indicator expires at configured duration")
	await process_frame
	if failures.is_empty(): print("PASS danger indicator lifecycle, settings and direction")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
