extends SceneTree

## Launch sequence (docs/design/scene-flow.md 「런 시작 · 출격 시퀀스」):
## idle without a current scene, then play() + advance() drives ship rise,
## background burst/streaks, music low-pass opening, control unlock, and the
## EncounterDirector start at the end without pulling the player-flown ship back.

const STEP := 0.05
const HOME := Vector2(100.0, 216.0)

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null

	LaunchSequence.set_music_muffled(true)
	_expect(is_equal_approx(LaunchSequence.get_music_cutoff(), 500.0), "Music bus low-pass closes to 500Hz")
	LaunchSequence.set_music_muffled(false)
	_expect(is_equal_approx(LaunchSequence.get_music_cutoff(), 20500.0), "Music bus low-pass opens to 20500Hz")

	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	root.add_child(gameplay)
	await process_frame
	var launch := gameplay.get_node("LaunchSequence") as LaunchSequence
	var director := gameplay.get_node("EncounterDirector") as EncounterDirector
	var ship := gameplay.get_node("Ship") as Node2D
	var background := gameplay.get_node("SpaceBackground") as SpaceBackground
	var move_input := ship.get_node("MoveInputComponent") as MoveInputComponent
	var clamp := ship.get_node("PositionClampComponent") as PositionClampComponent
	var weapon_loadout := ship.get_node("PlayerWeaponLoadout") as Node
	var viewport_height := ship.get_viewport_rect().size.y
	_expect(launch != null and not launch.is_launching, "without a current scene the launch stays idle")
	_expect(not director.autostart and not director.is_running, "director waits for the launch instead of autostarting")
	_expect(ship.position.is_equal_approx(HOME), "ship rests at its authored home before launch")
	_expect(move_input.enabled and clamp.enabled, "controls are enabled before launch")
	_expect(
		is_equal_approx(background.speed_scale, 1.0) and is_equal_approx(background.get_layer_speed(2), 160.0),
		"background cruises at 160px/s on the close layer",
	)

	var finished := [false]
	launch.launch_finished.connect(func() -> void: finished[0] = true)
	launch.play()
	launch.set_process(false)
	_expect(launch.is_launching, "play() starts the launch")
	_expect(ship.position.y > viewport_height, "ship starts below the screen")
	_expect(not move_input.enabled and not clamp.enabled, "controls lock at launch start")
	_expect(weapon_loadout.process_mode == Node.PROCESS_MODE_DISABLED, "weapons stop firing during the launch")
	_expect(is_equal_approx(background.speed_scale, 0.0), "stars stand still at ignition")
	_expect(is_equal_approx(LaunchSequence.get_music_cutoff(), 500.0), "music is muffled at launch start")

	_step(launch, background, 1.0)
	_expect(background.speed_scale > 3.0, "burn pushes the background past 3x (%f)" % background.speed_scale)
	_expect(background.is_streaking(), "streaks show during the burn")
	_expect(
		ship.position.y < viewport_height and ship.position.y > HOME.y,
		"ship is rising into the screen at 1.0s (%f)" % ship.position.y,
	)
	_expect(not move_input.enabled, "controls stay locked at 1.0s")
	var cutoff := LaunchSequence.get_music_cutoff()
	_expect(cutoff > 2000.0 and cutoff < 10000.0, "low-pass is half open at 1.0s (%f)" % cutoff)

	_step(launch, background, 0.5)
	_expect(is_equal_approx(LaunchSequence.get_music_cutoff(), 20500.0), "low-pass is fully open by 1.5s")

	_step(launch, background, 0.4)
	_expect(move_input.enabled and clamp.enabled, "controls unlock after 1.8s")
	_expect(weapon_loadout.process_mode == Node.PROCESS_MODE_INHERIT, "weapons resume with the controls")
	_expect(launch.is_launching, "launch keeps settling after the unlock")
	_expect(not director.is_running, "director waits until the settle ends")
	_expect(ship.position.is_equal_approx(HOME), "ship reaches home by the unlock (%s)" % ship.position)

	# The player flies the ship after the unlock; the settle must not pull it back.
	var flown := HOME + Vector2(60.0, -40.0)
	_step(launch, background, 0.3)
	ship.position = flown
	_step(launch, background, 0.5)
	_expect(not launch.is_launching and finished[0], "launch finishes at 2.6s and emits launch_finished")
	_expect(ship.position.is_equal_approx(flown), "ship keeps the player's position at the finish (%s)" % ship.position)
	_expect(is_equal_approx(background.speed_scale, 1.0) and not background.is_streaking(), "background settles to cruise without streaks")
	_expect(is_equal_approx(LaunchSequence.get_music_cutoff(), 20500.0), "music is fully open after launch")
	_expect(director.is_running, "director starts when the launch finishes")
	_expect(ResourceLoader.exists("res://sounds/launch_burn.wav"), "launch roar wav is imported")

	gameplay.queue_free()
	await process_frame
	await process_frame

	if failures.is_empty():
		print("launch_sequence_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("launch_sequence_test: %s" % failure)
	quit(1)


func _step(launch: LaunchSequence, background: SpaceBackground, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0001:
		var dt := minf(STEP, remaining)
		launch.advance(dt)
		background._process(dt)
		remaining -= dt


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
