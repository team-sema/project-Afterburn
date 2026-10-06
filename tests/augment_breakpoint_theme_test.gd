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

	# The card may pop during the first 0.3 s, but from then on it must hold
	# exactly scale 1.0 and one rect: a slow drift through fractional scales
	# puts the pixel font off the pixel grid and reads as a tremble.
	# Scrub the paused animation: a process frame in headless mode can be
	# long enough to skip the whole 0.3 s pop, so sample without advancing.
	intro.visible = true
	intro.animation_player.play(&"reveal")
	intro.animation_player.pause()
	intro.animation_player.seek(0.05, true)
	var card := intro.breakpoint_card
	_expect(card.scale.x < 1.0, "card starts smaller than 1.0 (pop-in still plays): %s" % card.scale)
	intro.animation_player.seek(0.22, true)
	_expect(card.scale.x > 1.0, "card overshoots past 1.0 at the top of the pop: %s" % card.scale)
	intro.animation_player.seek(0.4, true)
	var rect_settled := card.get_global_rect()
	var alphas := PackedFloat32Array()
	for time in [0.4, 0.6, 0.9, 1.2, 1.26]:
		intro.animation_player.seek(time, true)
		_expect(card.scale.is_equal_approx(Vector2.ONE), "card scale holds 1.0 at t=%.2f (%s)" % [time, card.scale])
		var rect := card.get_global_rect()
		_expect(
			rect.position.is_equal_approx(rect_settled.position) and rect.size.is_equal_approx(rect_settled.size),
			"card rect is steady at t=%.2f (%s vs %s)" % [time, rect, rect_settled],
		)
		alphas.append(card.modulate.a)
	_expect(alphas[0] > 0.9 and alphas[4] > 0.9, "card is fully visible while it holds")
	intro.animation_player.seek(1.49, true)
	_expect(card.scale.x < 1.0 and card.modulate.a < 0.2, "card shrinks only while fading out: scale %s alpha %.2f" % [card.scale, card.modulate.a])
	_expect(intro.band.scale.x > 0.9, "band sweep still plays")
	intro.animation_player.stop()

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
