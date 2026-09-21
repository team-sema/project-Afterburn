extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var player := VariablePitchAudioStreamPlayer.new()
	# Intentionally not added to the tree — formation reparent can hit this path.
	player.play_with_variance()
	if player.playing:
		failures.append("outside-tree play_with_variance should not start playback")

	root.add_child(player)
	await process_frame
	player.play_with_variance()
	if not player.is_inside_tree():
		failures.append("player should be inside the tree after add_child")

	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("variable_pitch_audio_outside_tree_smoke_test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("variable_pitch_audio_outside_tree_smoke_test: FAIL")
		quit(1)
