extends SceneTree

const INTRO_SCENE := preload("res://menus/augment_breakpoint_intro.tscn")
const PLAYER_ACCENT := Color(0.18, 0.82, 1.0, 1.0)
const ENEMY_ACCENT := Color(1.0, 0.2, 0.58, 1.0)

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var intro := INTRO_SCENE.instantiate() as AugmentBreakpointIntro
	root.add_child(intro)

	intro.set_accent_color(ENEMY_ACCENT)
	_expect(intro.accent_bar.color == ENEMY_ACCENT, "enemy intro uses the enemy accent bar")
	var enemy_style := intro.breakpoint_card.get_theme_stylebox(&"panel") as StyleBoxFlat
	_expect(enemy_style.border_color == Color(1.0, 0.2, 0.58, 0.9), "enemy intro uses a red border")
	_expect(enemy_style.bg_color.r > enemy_style.bg_color.b, "enemy intro background is red-dominant")
	_expect(
		intro.event_label.label_settings.font_color.r > intro.event_label.label_settings.font_color.b,
		"enemy intro eyebrow is red-dominant",
	)

	intro.set_accent_color(PLAYER_ACCENT)
	_expect(intro.accent_bar.color == PLAYER_ACCENT, "player intro restores the player accent bar")
	var player_style := intro.breakpoint_card.get_theme_stylebox(&"panel") as StyleBoxFlat
	_expect(player_style.border_color == Color(0.18, 0.82, 1.0, 0.9), "player intro restores a blue border")
	_expect(player_style.bg_color.b > player_style.bg_color.r, "player intro background is blue-dominant")

	if failures.is_empty():
		print("augment breakpoint theme test: PASS")
		quit()
		return
	for failure in failures:
		push_error("augment breakpoint theme test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
