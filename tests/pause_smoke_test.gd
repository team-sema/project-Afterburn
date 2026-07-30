extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var pause_overlay: ColorRect = world.get_node("Layout/Playfield/PauseOverlay") as ColorRect
	var progression: Node = world.get_node(
		"Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay/AugmentProgressionController"
	)

	_expect(not pause_overlay.visible, "pause overlay starts hidden")
	_send_escape(world)
	_expect(paused, "Escape pauses the scene tree")
	_expect(pause_overlay.visible, "Escape shows the playfield pause overlay")
	var threat_elapsed: float = progression.enemy_augment_elapsed
	await process_frame
	await process_frame
	_expect(
		is_equal_approx(progression.enemy_augment_elapsed, threat_elapsed),
		"Threat timer stops while paused",
	)

	_send_escape(world)
	_expect(not paused, "a second Escape resumes the scene tree")
	_expect(not pause_overlay.visible, "resuming hides the playfield pause overlay")

	paused = true
	_send_escape(world)
	_expect(paused, "Escape does not cancel a pause owned by another system")
	_expect(not pause_overlay.visible, "external pauses do not show the manual pause overlay")
	paused = false

	if failures.is_empty():
		print("pause smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("pause smoke test: %s" % failure)
	quit(1)


func _send_escape(world: Control) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	world.call("_unhandled_input", event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
