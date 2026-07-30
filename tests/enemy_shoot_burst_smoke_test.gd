extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shoot_scene := load("res://components/enemy_shoot_component.tscn") as PackedScene
	var shoot := shoot_scene.instantiate() as EnemyShootComponent
	_expect(shoot.burst_count == 1, "default shooting preserves one volley per burst")

	shoot.burst_count = 3
	shoot.fire_interval = 1.2
	shoot.burst_interval = 0.1
	shoot.fire_timer = Timer.new()
	shoot.fire_timer.one_shot = true
	root.add_child(shoot.fire_timer)

	shoot.call("_start_burst")
	_expect(is_equal_approx(shoot.fire_timer.wait_time, 0.1), "first volley schedules burst interval")
	shoot.fire_timer.stop()
	shoot.call("_on_fire_timer_timeout")
	_expect(is_equal_approx(shoot.fire_timer.wait_time, 0.1), "middle volley keeps burst interval")
	shoot.fire_timer.stop()
	shoot.call("_on_fire_timer_timeout")
	_expect(is_equal_approx(shoot.fire_timer.wait_time, 1.2), "last volley schedules fire interval")
	shoot.fire_timer.stop()

	shoot.set("_base_fire_interval", 1.2)
	shoot.set("_base_burst_interval", 0.1)
	shoot.apply_action_rate_multiplier(2.0)
	_expect(is_equal_approx(shoot.fire_interval, 0.6), "action rate scales fire interval")
	_expect(is_equal_approx(shoot.burst_interval, 0.05), "action rate scales burst interval")

	shoot.fire_timer.free()
	shoot.free()
	shoot = null
	shoot_scene = null
	await process_frame

	if failures.is_empty():
		print("enemy shoot burst smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy shoot burst smoke test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
