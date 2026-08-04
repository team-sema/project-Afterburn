extends SceneTree

const WORLD_SCENE := preload("res://world.tscn")
const HUD_FONT := preload("res://fonts/Mulmaru.ttf")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(
		HUD_FONT.antialiasing == TextServer.FONT_ANTIALIASING_NONE,
		"HUD font keeps antialiasing disabled",
	)
	_expect(HUD_FONT.hinting == TextServer.HINTING_NONE, "HUD font avoids glyph-edge hinting")
	_expect(not HUD_FONT.force_autohinter, "HUD font does not force autohinting")

	var world := WORLD_SCENE.instantiate() as Control
	root.add_child(world)
	for _index in 2:
		await process_frame
	var left_panel := world.get_node("Layout/LeftPanel") as PanelContainer
	var right_panel := world.get_node("Layout/RightPanel") as PanelContainer
	_expect(
		left_panel.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"left HUD uses nearest texture filtering",
	)
	_expect(
		right_panel.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"right HUD uses nearest texture filtering",
	)
	for label_path in [
		"Layout/LeftPanel/Margin/VBox/GameTitle",
		"Layout/LeftPanel/Margin/VBox/ScoreValue",
		"Layout/RightPanel/Margin/VBox/LoadoutTitle",
	]:
		var label := world.get_node(label_path) as Label
		_expect(
			label.global_position == label.global_position.round(),
			"%s is aligned to whole logical pixels" % label_path,
		)

	if failures.is_empty():
		print("side HUD crisp rendering test: PASS")
		quit()
		return
	for failure in failures:
		push_error("side HUD crisp rendering test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
