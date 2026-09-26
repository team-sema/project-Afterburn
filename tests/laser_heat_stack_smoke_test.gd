extends SceneTree

## laser_heat_stack grows with continuous contact time and resets after a gap.


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


const TICK := 0.1

var failures: PackedStringArray = []
var _laser: LaserWeaponSystem
var _enemy: Node2D
var _base_time := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	_laser = (load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene).instantiate() as LaserWeaponSystem
	root.add_child(_laser)
	await physics_frame
	_laser.setup_weapon(null, loadout, 0, &"main_laser")
	_laser.set_physics_process(false)
	_laser.damage_tick_timer.stop()
	_enemy = Node2D.new()
	root.add_child(_enemy)

	loadout.traits = {&"laser_heat_stack": 1}
	_restart(10.0)
	_expect(is_zero_approx(_hit_at(0.0)), "first contact has no heat bonus")
	_expect(is_zero_approx(_contact(0.1, 0.4)), "no bonus before the first 0.5s of contact")
	_expect(is_equal_approx(_contact(0.5, 0.5), 0.15), "0.5s of continuous contact adds +15%")
	_expect(is_equal_approx(_contact(0.6, 1.5), 0.45), "1.5s of continuous contact adds +45%")
	_expect(is_equal_approx(_contact(1.6, 3.0), 0.9), "Lv.I reaches the +90% cap after 3s")
	_expect(is_equal_approx(_contact(3.1, 5.0), 0.9), "bonus stays at the cap")

	_restart(100.0)
	_contact(0.0, 1.0)
	# Pulse OFF window: last ON tick, 0.35s off, next tick lands 0.45s later.
	_expect(is_equal_approx(_hit_at(1.45), 0.3), "a 0.45s pulse gap keeps the contact run")

	_restart(200.0)
	_contact(0.0, 2.0)
	_expect(is_zero_approx(_hit_at(2.6)), "a gap over 0.5s restarts heat from zero")
	_expect(is_equal_approx(_contact(2.7, 3.1), 0.15), "heat builds again after the restart")

	_restart(300.0)
	_contact(0.0, 1.0)
	_expect(is_zero_approx(_hit_at(30.0)), "a long absence does not bank heat")

	loadout.traits = {&"laser_heat_stack": 3}
	_restart(400.0)
	_expect(is_equal_approx(_contact(0.0, 0.5), 0.25), "Lv.III adds +25% per 0.5s")
	_expect(is_equal_approx(_contact(0.6, 3.0), 1.5), "Lv.III reaches the +150% cap after 3s")

	_laser.set("_clock", 400.0 + 3.0 + 0.6)
	_laser.call("_prune_heat_stacks")
	_expect((_laser.get("_heat_stacks") as Dictionary).is_empty(), "stale heat entries are pruned")

	_laser.queue_free()
	loadout.queue_free()
	_enemy.queue_free()
	await process_frame
	if failures.is_empty():
		print("laser_heat_stack_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_heat_stack_smoke_test: %s" % failure)
	quit(1)


func _restart(base_time: float) -> void:
	_base_time = base_time
	_laser.set("_heat_stacks", {})


func _hit_at(offset: float) -> float:
	_laser.set("_clock", _base_time + offset)
	return float(_laser.call("_heat_bonus_for", _enemy))


## Beam ticks every 0.1s from `from_offset` through `to_offset`; returns the last bonus.
func _contact(from_offset: float, to_offset: float) -> float:
	var bonus := 0.0
	var steps := roundi((to_offset - from_offset) / TICK)
	for step in steps + 1:
		bonus = _hit_at(from_offset + step * TICK)
	return bonus


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
