extends SceneTree

## Every lab showcase pattern loads through the Lab loader, validates, and
## fires bullets when played against a target for a few seconds.

const LOADER := preload("res://labs/bullet/pattern_loader.gd")
const DIRECTORY := "res://patterns/showcase"
const PLAY_SECONDS := 3.0

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths := LOADER.list_patterns(DIRECTORY)
	_expect(paths.size() >= 8, "showcase has at least eight patterns (got %d)" % paths.size())
	for path in paths:
		await _check_pattern(path)
	if failures.is_empty():
		print("showcase_patterns_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("showcase_patterns_smoke_test: %s" % failure)
	quit(1)


func _check_pattern(path: String) -> void:
	var loaded := LOADER.load_pattern(path)
	if not String(loaded.get("error", "")).is_empty():
		_expect(false, "%s loads (%s)" % [path, loaded["error"]])
		return
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var emitter := Node2D.new()
	emitter.position = Vector2(208, 60)
	world.add_child(emitter)
	var target := Node2D.new()
	target.position = Vector2(208, 330)
	world.add_child(target)
	var player := BarragePlayer.new()
	world.add_child(player)
	var fired := [0]
	player.volley_fired.connect(func(projectiles: Array) -> void: fired[0] += projectiles.size())
	_expect(player.play(loaded["sequence"], emitter, world, target), "%s plays (%s)" % [path, player.last_error])
	for _i in int(PLAY_SECONDS * 60.0):
		await physics_frame
	_expect(fired[0] > 0, "%s fires bullets" % path)
	_expect(player.running, "%s keeps running (repeating pattern)" % path)
	world.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
