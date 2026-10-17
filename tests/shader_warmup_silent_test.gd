extends SceneTree

## 첫 시작 셰이더 워밍업은 소리를 내지 않는다: 관문 경고·폭발 등 워밍업이 그리는
## 어떤 노드도 스트림이 있는 AudioStreamPlayer를 갖지 않는다.
## 규칙: docs/design/scene-flow.md「Menu」.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSettings.instance.save_enabled = false
	var warmup := (load("res://effects/shader_warmup.gd") as GDScript).new() as Node
	root.add_child(warmup)
	await process_frame
	var players := warmup.find_children("*", "AudioStreamPlayer", true, false)
	for player: AudioStreamPlayer in players:
		_expect(player.stream == null, "warm-up node %s has no sound to play" % warmup.get_path_to(player))
	var warnings := warmup.find_children("*", "EncounterStepWarning", true, false)
	_expect(not warnings.is_empty(), "warm-up still draws the step warning")
	for warning: EncounterStepWarning in warnings:
		_expect(not warning.play_sound, "warm-up step warning is silent")
	var real := EncounterStepWarning.new()
	_expect(real.play_sound, "step warnings play the klaxon by default")
	real.free()
	if is_instance_valid(warmup):
		warmup.queue_free()
	await process_frame
	if failures.is_empty():
		print("shader_warmup_silent_test: PASS")
		quit()
		return
	for failure in failures:
		printerr("shader_warmup_silent_test: %s" % failure)
	print("shader_warmup_silent_test: FAIL (%d)" % failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
