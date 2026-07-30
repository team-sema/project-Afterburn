extends SceneTree

## V held through aim; after charge each member flies independently.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var scene: PackedScene = load("res://enemies/kamikaze_enemy.tscn")
	var script: Script = load("res://enemies/kamikaze_enemy.gd")
	var offsets: Array[Vector2] = [
		Vector2(-32, -14),
		Vector2(0, 14),
		Vector2(32, -14),
	]
	var origin := Vector2(120, -16)
	var start_time := Time.get_ticks_msec() * 0.001
	var settings := {
		"descend_duration": 0.35,
		"descend_speed": 50.0,
		"aim_duration": 0.25,
		"charge_speed": 280.0,
	}

	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(140, 220)
	root.add_child(player)

	var members: Array[Node2D] = []
	for offset in offsets:
		var enemy: Node2D = scene.instantiate() as Node2D
		enemy.set("augment_registry", EnemyAugmentRegistry.new())
		root.add_child(enemy)
		enemy.call("setup_formation", origin, offset, start_time, settings)
		members.append(enemy)

	# Still in aim / just before charge — V should hold.
	await create_timer(0.5).timeout
	var tip := members[1].global_position
	for index in members.size():
		var expected := offsets[index] - offsets[1]
		var actual := members[index].global_position - tip
		if actual.distance_to(expected) > 1.5:
			failures.append("pre-charge V broken at %d" % index)

	# Into independent charge
	await create_timer(0.4).timeout
	var move0: MoveComponent = members[0].get_node("MoveComponent") as MoveComponent
	var move1: MoveComponent = members[1].get_node("MoveComponent") as MoveComponent
	if not move0.is_processing() or move0.velocity.length() < 100.0:
		failures.append("charge should enable independent MoveComponent flight")
	# Directions from different start slots toward same player should differ.
	if move0.velocity.normalized().dot(move1.velocity.normalized()) > 0.999:
		failures.append("independent charge directions should diverge from V slots")

	for member in members:
		if is_instance_valid(member):
			member.queue_free()
	player.queue_free()

	if failures.is_empty():
		print("kamikaze_aim_charge_smoke_test: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("kamikaze_aim_charge_smoke_test: FAIL")
		quit(1)
