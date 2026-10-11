extends SceneTree
## The side HUD renders at window resolution with a smoothed font while the
## playfield keeps its 340x360 nearest-upscaled pixel look.

const WORLD_SCENE := preload("res://world.tscn")
const HUD_FONT := preload("res://fonts/Mulmaru_hud.ttf")
const PIXEL_FONT := preload("res://fonts/Mulmaru.ttf")
const HUD_LABEL_SETTINGS := [
	preload("res://fonts/default_label_settings.tres"),
	preload("res://fonts/title_label_settings.tres"),
	preload("res://fonts/hex_module_label_settings.tres"),
	preload("res://fonts/ship_panel_detail_label_settings.tres"),
]

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(
		HUD_FONT.antialiasing == TextServer.FONT_ANTIALIASING_GRAY,
		"HUD font uses grayscale antialiasing",
	)
	_expect(HUD_FONT.hinting == TextServer.HINTING_LIGHT, "HUD font uses light hinting")
	_expect(
		HUD_FONT.subpixel_positioning != TextServer.SUBPIXEL_POSITIONING_DISABLED,
		"HUD font keeps subpixel positioning for rotated instruments",
	)
	_expect(HUD_FONT.generate_mipmaps, "HUD font generates mipmaps for rotated text")
	_expect(not HUD_FONT.force_autohinter, "HUD font does not force autohinting")
	_expect(
		PIXEL_FONT.antialiasing == TextServer.FONT_ANTIALIASING_NONE
		and PIXEL_FONT.hinting == TextServer.HINTING_NONE,
		"overlay/menu pixel font keeps antialiasing and hinting disabled",
	)
	for settings: LabelSettings in HUD_LABEL_SETTINGS:
		_expect(settings.font == HUD_FONT, "%s uses the HUD font" % settings.resource_path)
	_expect(
		ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d") >= 1,
		"root viewport smooths HUD gauges with 2D MSAA",
	)

	var world := WORLD_SCENE.instantiate() as Control
	root.add_child(world)
	for _index in 2:
		await process_frame
	var left_panel := world.get_node("Layout/LeftPanel") as Control
	var right_panel := world.get_node("Layout/RightPanel") as Control
	_expect(
		left_panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"left HUD uses linear texture filtering",
	)
	_expect(
		right_panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"right HUD uses linear texture filtering",
	)
	var container := world.get_node("Layout/Playfield/ViewportContainer") as SubViewportContainer
	var playfield := container.get_node("PlayfieldViewport") as SubViewport
	_expect(
		container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"playfield keeps nearest upscaling",
	)
	_expect(playfield.get_visible_rect().size == Vector2(340, 360), "playfield logic keeps its 340x360 lane")
	_expect(playfield.size == Vector2i(372, 360), "playfield renders 16px of bleed past each lane edge")
	_expect(playfield.msaa_2d == Viewport.MSAA_DISABLED, "playfield stays free of 2D MSAA")
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
	for label: Label in left_panel.find_children("*", "Label", true, false) + right_panel.find_children("*", "Label", true, false):
		if label.label_settings != null:
			_expect(label.label_settings.font == HUD_FONT, "%s uses the HUD font" % label.get_path())

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
