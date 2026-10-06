extends SceneTree
## The three-column world layout must never move. Long HUD strings (AUGMENT
## READY, XP RECOVERY, ELITE ENGAGED, big scores) used to widen the left panel
## and shift the whole screen by several pixels at level-up.

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _rects(world: Control) -> Dictionary:
	var out := {}
	for path in ["Layout", "Layout/LeftPanel", "Layout/Playfield", "Layout/RightPanel"]:
		out[path] = (world.get_node(path) as Control).get_global_rect()
	return out


func _expect_same(label: String, before: Dictionary, world: Control) -> void:
	var after := _rects(world)
	for path in before:
		var a: Rect2 = before[path]
		var b: Rect2 = after[path]
		_expect(a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size),
			"%s: %s moved %s -> %s" % [label, path, a, b])


func _run() -> void:
	var world := (load("res://world.tscn") as PackedScene).instantiate() as Control
	root.add_child(world)
	for _i in 6:
		await process_frame
	var base := _rects(world)
	_expect(is_equal_approx((base["Layout"] as Rect2).size.x, 640.0), "layout spans the 640px shell")
	_expect(is_equal_approx((base["Layout/LeftPanel"] as Rect2).size.x, 170.0), "left panel is 170px wide")
	_expect(is_equal_approx((base["Layout/Playfield"] as Rect2).position.x, 170.0), "playfield starts at x=170")

	var progression := world.find_child("AugmentProgressionController", true, false)
	var experience_label := world.get_node("Layout/LeftPanel/Margin/VBox/ProgressionHud/ExperienceLabel") as Label
	var threat_label := world.get_node("Layout/LeftPanel/Margin/VBox/ProgressionHud/ThreatLabel") as Label
	var shield_label := world.get_node("Layout/LeftPanel/Margin/VBox/ShipStatusHud/ShieldLabel") as Label
	var score_label := world.get_node("Layout/LeftPanel/Margin/VBox/ScoreValue") as Label
	var column_width := (world.get_node("Layout/LeftPanel/Margin/VBox") as Control).size.x

	# XP full: the ready prompt must fit the column without ellipsis.
	progression.add_experience(999)
	for _i in 3:
		await process_frame
	_expect(experience_label.text.contains("AUGMENT READY [C]"), "ready prompt names the C key")
	var font := experience_label.label_settings.font if experience_label.label_settings != null else experience_label.get_theme_font("font")
	var font_size := experience_label.label_settings.font_size if experience_label.label_settings != null else experience_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(experience_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_expect(text_width <= column_width, "ready prompt (%dpx) fits the %dpx HUD column" % [int(text_width), int(column_width)])
	_expect_same("xp full", base, world)

	# Bullet-cancel recovery wording.
	progression.set_bullet_cancel_reward_active(true)
	for _i in 3:
		await process_frame
	_expect(experience_label.text.contains("XP RECOVERY"), "recovery prompt shown")
	_expect_same("xp recovery", base, world)
	progression.set_bullet_cancel_reward_active(false)

	# Elite gate wording in sequence mode.
	var hud := world.get_node("Layout/LeftPanel/Margin/VBox/ProgressionHud")
	hud._on_sequence_started(&"main")
	hud._on_elite_gate_changed(true, 2)
	for _i in 3:
		await process_frame
	_expect(threat_label.text.contains("ELITE ENGAGED"), "elite gate prompt shown")
	_expect_same("elite gate", base, world)

	# Safety net: even absurd strings clip instead of widening the panel.
	for label: Label in [experience_label, threat_label, shield_label, score_label]:
		label.text = "X".repeat(80)
	for _i in 3:
		await process_frame
	_expect_same("overlong labels", base, world)
	for label: Label in [experience_label, threat_label, shield_label, score_label]:
		_expect(label.clip_text, "%s clips overflowing text" % label.name)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS hud_layout_stability_test")
		quit(0)
		return
	for failure in failures:
		printerr("FAIL: ", failure)
	quit(1)
