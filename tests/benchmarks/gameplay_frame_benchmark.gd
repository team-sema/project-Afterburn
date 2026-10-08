extends SceneTree

## Gameplay frame-budget benchmark (needs a window). Plays the real start path
## (menu -> World) with an invincible auto-piloted ship and auto-accepted
## offers, and writes one JSON row per rendered frame to
## .godot/perf-logs/gameplay_frame_<scenario>.jsonl plus an events file.
## Summarise with tools/analyze_frame_benchmark.py.
##
##   tools\run-godot.cmd --script res://tests/benchmarks/gameplay_frame_benchmark.gd -- seconds=150 scenarios=default,late
##
## Columns: frame, t_ms, interval, proc_ms (previous frame's _process pass),
## phys_ms (this frame's physics passes), phys_ticks, render cpu/gpu of the
## root viewport, render cpu/gpu of the playfield, nodes, orphans, objects,
## draw calls, render objects, primitives, collision pairs, static memory KB,
## enemies, enemy bullets, orbs, player bullets, paused, token, stage, level,
## elite gate, phase, nodes added this frame by class, nodes removed.
##
## Measurement notes: a windowed D3D12 run stays capped at the display refresh
## rate even with vsync off, so the interval column only shows spikes above
## that floor; proc/phys come from priority sentinel nodes and the render
## columns from RenderingServer.viewport_set_measure_render_time.
## "late" equips laser + homing missile, installs weapon-room facilities,
## raises the Threat tier and plays only the mix phase.

const OUT_DIR := "res://.godot/perf-logs/"

class Sentinel extends Node:
	static var proc_start := 0
	static var phys_start := 0
	static var proc_total := 0
	static var phys_total := 0
	static var phys_ticks := 0
	var is_end := false
	func _init(end: bool) -> void:
		is_end = end
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = 100000 if end else -100000
		process_physics_priority = 100000 if end else -100000
	func _process(_d: float) -> void:
		if is_end:
			proc_total += Time.get_ticks_usec() - proc_start
		else:
			proc_start = Time.get_ticks_usec()
	func _physics_process(_d: float) -> void:
		if is_end:
			phys_total += Time.get_ticks_usec() - phys_start
			phys_ticks += 1
		else:
			phys_start = Time.get_ticks_usec()

var run_seconds := 150.0
var scenarios: PackedStringArray = ["default"]
var _file: FileAccess
var _frame := 0
var _prev_usec := 0
var _added: Dictionary = {}
var _removed := 0
var _live: Dictionary = {}
var _gameplay: Node
var _ship: Node2D
var _move: MoveComponent
var _move_input: MoveInputComponent
var _director: Node
var _progression: Node
var _offer: Node
var _launch: Node
var _playfield_rid := RID()
var _target := Vector2.ZERO
var _retarget_at := 0.0
var _paused_frames := 0
var _rng := RandomNumberGenerator.new()
var _events: Array = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_rng.seed = 12345
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seconds="):
			run_seconds = float(arg.substr(8))
		elif arg.begins_with("scenarios="):
			scenarios = arg.substr(10).split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	node_added.connect(_on_node_added)
	node_removed.connect(_on_node_removed)
	var music := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music != null:
		music.volume_db = -40.0
	root.add_child(Sentinel.new(false))
	root.add_child(Sentinel.new(true))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_run.call_deferred()


func _on_node_added(node: Node) -> void:
	var key := _class_key(node)
	_added[key] = int(_added.get(key, 0)) + 1
	_live[key] = int(_live.get(key, 0)) + 1


func _on_node_removed(node: Node) -> void:
	_removed += 1
	var key := _class_key(node)
	_live[key] = int(_live.get(key, 0)) - 1


func _class_key(node: Node) -> String:
	var script: Script = node.get_script()
	if script != null:
		var name := script.get_global_name()
		if name != &"":
			return String(name)
		return script.resource_path.get_file()
	return node.get_class()


func _run() -> void:
	for scenario in scenarios:
		_file = FileAccess.open(OUT_DIR + "gameplay_frame_%s.jsonl" % scenario, FileAccess.WRITE)
		_events.clear()
		await _play_one_run(scenario)
		_file.close()
		var events := FileAccess.open(OUT_DIR + "gameplay_frame_events_%s.json" % scenario, FileAccess.WRITE)
		events.store_string(JSON.stringify(_events))
		events.close()
		print("GAMEPLAY_FRAME_BENCHMARK %s done -> %s" % [scenario, ProjectSettings.globalize_path(OUT_DIR)])
	quit()


func _event(kind: String, detail: String = "") -> void:
	_events.append({"frame": _frame, "t": Time.get_ticks_msec(), "kind": kind, "detail": detail})


func _play_one_run(scenario: String) -> void:
	var menu: Node = current_scene
	if menu == null or menu.name != "Menu":
		menu = (load("res://menus/menu.tscn") as PackedScene).instantiate()
		root.add_child(menu)
		current_scene = menu
	await process_frame
	var deadline := Time.get_ticks_msec() + 30000
	while menu.get("_game_scene") == null and Time.get_ticks_msec() < deadline:
		await process_frame
	var preload_start := Time.get_ticks_msec()
	deadline = Time.get_ticks_msec() + 15000
	while AugmentPoolLoader.is_background_preload_pending() and Time.get_ticks_msec() < deadline:
		await process_frame
	_event("card_preload_waited", "%d ms" % (Time.get_ticks_msec() - preload_start))
	_start_recording()
	menu.call("_request_start")
	_event("start_requested")
	deadline = Time.get_ticks_msec() + 30000
	while (current_scene == null or current_scene.name != "World") and Time.get_ticks_msec() < deadline:
		await process_frame
		_record_frame("menu")
	_event("world_entered")
	_gameplay = get_first_node_in_group("gameplay_world")
	_ship = _gameplay.get_node("Ship")
	_move = _ship.get_node("MoveComponent")
	_move_input = _ship.get_node("MoveInputComponent")
	_director = _gameplay.get_node("EncounterDirector")
	_progression = _gameplay.get_node("AugmentProgressionController")
	_offer = _gameplay.get_node("AugmentOfferController")
	_launch = _gameplay.get_node("LaunchSequence")
	_playfield_rid = (_gameplay.get_viewport() as SubViewport).get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_playfield_rid, true)
	_ship.get_node("PlayerHitPoint/HurtboxComponent").set("is_invincible", true)
	_director.step_started.connect(func(token, kind): _event("step", "%s kind=%d stage=%d" % [token, kind, _director.current_stage]))
	_director.gate_requested.connect(func(token, kind): _event("gate", "%s kind=%d" % [token, kind]))
	_offer.offer_started.connect(func(type): _event("offer_started", str(type)))
	_offer.offer_completed.connect(func(type): _event("offer_completed", str(type)))
	_progression.elite_gate_changed.connect(func(active, threat): _event("elite_gate", "%s threat=%d" % [active, threat]))
	var start := Time.get_ticks_msec()
	var driving := false
	while Time.get_ticks_msec() - start < run_seconds * 1000.0:
		await process_frame
		if not is_instance_valid(_ship):
			_event("ship_lost")
			break
		if not driving and not _launch.get("is_launching"):
			driving = true
			_move_input.enabled = false
			_event("autopilot_on")
			if scenario == "late":
				await _apply_late_scenario()
		if driving and not paused:
			_drive()
		_auto_accept()
		_record_frame("play")
	_event("run_timeout")
	var shell := current_scene
	shell.call("_return_to_menu")
	deadline = Time.get_ticks_msec() + 15000
	while (current_scene == null or current_scene.name != "Menu") and Time.get_ticks_msec() < deadline:
		await process_frame
		_record_frame("exit")
	for i in 30:
		await process_frame
		_record_frame("exit")
	_event("back_in_menu")


func _apply_late_scenario() -> void:
	var loadout = _ship.call("get_weapon_loadout")
	loadout.equip_weapon(load("res://resources/weapons/definitions/main_laser.tres"))
	loadout.equip_weapon(load("res://resources/weapons/definitions/aux_homing_missile.tres"))
	var registry := _gameplay.get_node("PlayerAugmentRegistry")
	for card in ["facility_weapon_room", "facility_weapon_room_fire_rate", "facility_radar"]:
		registry.install_augment(load("res://resources/player_augments/facilities/%s.tres" % card))
	_director.stop_sequence()
	var deadline := Time.get_ticks_msec() + 8000
	while _director.is_running and Time.get_ticks_msec() < deadline:
		await process_frame
		_record_frame("play")
	_progression.enemy_augment_tier = 2
	_progression.publish_state()
	var sequence: EncounterSequence = _director.sequence.duplicate()
	var mix: Array[EncounterSequencePhase] = [sequence.phases.back()]
	sequence.phases = mix
	var started: bool = _director.start_sequence(sequence)
	_event("late_scenario", "started=%s threat=%d weapons=%s" % [started, _progression.get_threat_level(), loadout.get_equipped_weapon_ids()])


func _drive() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var rect := _ship.get_viewport_rect()
	if now >= _retarget_at:
		_retarget_at = now + _rng.randf_range(0.6, 1.8)
		_target = Vector2(
			_rng.randf_range(rect.size.x * 0.12, rect.size.x * 0.88),
			_rng.randf_range(rect.size.y * 0.5, rect.size.y * 0.92),
		)
	var to_target := _target - _ship.position
	var speed: float = _move_input.move_stats.speed if _move_input.move_stats != null else 100.0
	if to_target.length() < 4.0:
		_move.velocity = Vector2.ZERO
	else:
		_move.velocity = to_target.normalized() * speed


func _auto_accept() -> void:
	if not paused:
		_paused_frames = 0
		return
	_paused_frames += 1
	if _paused_frames % 45 == 0:
		_press(&"ui_accept")
	if _paused_frames % 400 == 399:
		_press(&"ui_cancel")


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)


func _start_recording() -> void:
	_frame = 0
	_prev_usec = Time.get_ticks_usec()
	_added.clear()
	_removed = 0
	Sentinel.proc_total = 0
	Sentinel.phys_total = 0
	Sentinel.phys_ticks = 0


func _live_sum(keys: Array) -> int:
	var total := 0
	for key in keys:
		total += int(_live.get(key, 0))
	return total


func _record_frame(phase: String) -> void:
	var now := Time.get_ticks_usec()
	var interval := (now - _prev_usec) / 1000.0
	_prev_usec = now
	_frame += 1
	var token := ""
	var stage := 0
	var level := 0
	var gate := false
	if is_instance_valid(_director) and _director.is_inside_tree():
		token = String(_director.current_token)
		stage = _director.current_stage
		level = _progression.level
		gate = _progression.elite_gate_active
	var root_rid := root.get_viewport_rid()
	var playfield_cpu := 0.0
	var playfield_gpu := 0.0
	if _playfield_rid.is_valid() and is_instance_valid(_gameplay) and _gameplay.is_inside_tree():
		playfield_cpu = RenderingServer.viewport_get_measured_render_time_cpu(_playfield_rid)
		playfield_gpu = RenderingServer.viewport_get_measured_render_time_gpu(_playfield_rid)
	var row := [
		_frame,
		now / 1000,
		snappedf(interval, 0.001),
		snappedf(Sentinel.proc_total / 1000.0, 0.001),
		snappedf(Sentinel.phys_total / 1000.0, 0.001),
		Sentinel.phys_ticks,
		snappedf(RenderingServer.viewport_get_measured_render_time_cpu(root_rid), 0.001),
		snappedf(RenderingServer.viewport_get_measured_render_time_gpu(root_rid), 0.001),
		snappedf(playfield_cpu, 0.001),
		snappedf(playfield_gpu, 0.001),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1024),
		_live_sum(["Enemy", "ShootingEnemy", "KamikazeEnemy", "InterceptorEnemy", "SniperEnemy", "TankerEnemy", "BombEnemy"]),
		_live_sum(["FoundationBullet", "CurvedLaser", "SniperBullet", "BaseEnemyProjectile", "TelegraphBeam"]),
		int(_live.get("ExperienceOrb", 0)),
		_live_sum(["player_blaster.gd", "player_shotgun_pellet.gd", "player_homing_missile.gd", "aux_cannon_bolt.gd", "PlasmaBombProjectile"]),
		1 if paused else 0,
		token,
		stage,
		level,
		1 if gate else 0,
		phase,
		_added.duplicate() if not _added.is_empty() else {},
		_removed,
	]
	_file.store_line(JSON.stringify(row))
	_added.clear()
	_removed = 0
	Sentinel.proc_total = 0
	Sentinel.phys_total = 0
	Sentinel.phys_ticks = 0
