extends SceneTree

## 게임 오버 화면의 기록 표시와 메인 메뉴 복귀를 확인한다.

const GAME_OVER_SCENE := preload("res://menus/game_over.tscn")

var game_stats: GameStats = preload("res://game_stats.tres")

var failures: PackedStringArray = []


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
	_run.call_deferred()


func _run() -> void:
	var original_score := game_stats.score
	var original_highscore := game_stats.highscore
	game_stats.score = 1500
	game_stats.highscore = 900

	var game_over := GAME_OVER_SCENE.instantiate() as Control
	root.add_child(game_over)
	current_scene = game_over
	await process_frame

	var record_label := game_over.get_node("%RecordLabel") as Label
	var menu_button := game_over.get_node("%MenuButton") as Button
	_expect(game_over.theme != null, "game over uses the shared UI theme")
	_expect(game_stats.highscore == 1500, "a higher score becomes the new high score")
	_expect(record_label.visible, "new record label is shown when the high score is beaten")
	_expect((game_over.get_node("%ScoreValue") as Label).text == "001500", "score uses six digits")
	_expect(menu_button.has_focus(), "main menu item is focused on entry")

	_press(&"ui_accept")
	var deadline := Time.get_ticks_msec() + 3000
	while (current_scene == null or current_scene.name != "Menu") and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(current_scene != null and current_scene.name == "Menu", "accept returns to the main menu")

	if current_scene != null and current_scene.name == "Menu":
		deadline = Time.get_ticks_msec() + 15000
		while current_scene.get("_game_scene") == null and Time.get_ticks_msec() < deadline:
			await process_frame
		current_scene.queue_free()
		current_scene = null
		await process_frame

	game_stats.score = 0
	game_stats.highscore = 0
	var no_record := GAME_OVER_SCENE.instantiate() as Control
	root.add_child(no_record)
	await process_frame
	_expect(not (no_record.get_node("%RecordLabel") as Label).visible, "no record label without a new high score")
	no_record.queue_free()
	await process_frame

	game_stats.score = original_score
	game_stats.highscore = original_highscore
	if failures.is_empty():
		print("game over smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("game over smoke test: %s" % failure)
	quit(1)


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
