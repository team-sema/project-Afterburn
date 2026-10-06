extends SceneTree

## Bullet Lab pattern picker: one grouped list (combos / demos / scripts),
## shape and motion only for combos, motion options that follow the shape,
## scripts that play straight from the list, and the path entry opening the dialog.

var failures: PackedStringArray = []


func _initialize() -> void:
	var music := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.stream = null
	_run.call_deferred()


func _run() -> void:
	var lab := (load("res://labs/bullet/bullet_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for _i in 3:
		await process_frame
	var picker: OptionButton = lab.pattern_choice

	var separators := PackedStringArray()
	for item in picker.item_count:
		if picker.is_item_separator(item):
			separators.append(picker.get_item_text(item))
	_expect(separators.size() == 3, "the list has three labelled groups (got %s)" % str(separators))
	_expect(lab.get_pattern_id() == &"fan5" and lab.is_combo(), "the lab opens on a combo pattern")
	_expect(not lab.shape_choice.disabled and not lab.motion_choice.disabled, "combos enable shape and motion")

	lab.shape_choice.select(4)
	lab._shape_changed(4)
	_expect(lab.motion_choice.get_item_text(0) == "오른쪽 선회", "a laser shape lists turn directions")
	lab.shape_choice.select(3)
	lab._shape_changed(3)
	_expect(lab.motion_choice.item_count == 1, "the legacy bullet only goes straight")
	lab.shape_choice.select(0)
	lab._shape_changed(0)
	_expect(lab.motion_choice.get_item_text(1) == "파동 이동", "ordinary bullets offer straight and wave")

	_expect(lab.select_pattern(&"mixed_sixteen"), "a demo is selectable by id")
	_expect(lab.shape_choice.disabled and lab.motion_choice.disabled, "demos lock shape and motion")
	_expect(lab.pattern_player.running, "the demo plays")

	var showcase := &"res://patterns/showcase/star_burst_pattern.gd"
	_expect(lab.select_pattern(showcase), "a script from patterns/ is listed")
	_expect(not lab._script_shade.visible, "a listed script plays without opening the dialog")
	_expect(lab._custom_path == String(showcase) and lab.pattern_player.running, "the listed script is loaded and playing")
	_expect(String(lab.details_label.text).begins_with("star_burst_pattern.gd"), "details name the script")

	var before: StringName = lab.get_pattern_id()
	var open_item: int = lab._item_for(&"open_panel")
	picker.select(open_item)
	lab._selection_changed(open_item)
	_expect(lab._script_shade.visible, "the path entry opens the script dialog")
	_expect(lab.get_pattern_id() == before, "opening the dialog keeps the current pattern selected")
	lab._close_script_panel()

	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("bullet_lab_pattern_picker_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("bullet_lab_pattern_picker_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
