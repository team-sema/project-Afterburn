extends SceneTree

## Delayed trait actions (shotgun burst extra shot) wait on gameplay time:
## a paused tree (augment pick / bullet cancel) must not fire them.


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


var failures: PackedStringArray = []
var _fired_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var loadout := MockLoadout.new()
	world.add_child(loadout)
	# Lv.III burst: every 2nd real shot schedules an extra shot 0.06s later.
	loadout.traits = {&"shotgun_burst_device": 3}
	var shotgun := (load("res://player_ship/weapons/shotgun_weapon_system.tscn") as PackedScene).instantiate() as ShotgunWeaponSystem
	shotgun.base_fire_interval = 100.0
	world.add_child(shotgun)
	await process_frame
	shotgun.setup_weapon(null, loadout, 0, &"main_shotgun")
	shotgun.fire_rate_timer.stop()
	shotgun.fired.connect(func() -> void: _fired_count += 1)

	shotgun.fire()
	shotgun.fire()
	_expect(_fired_count == 2, "two real shots fire immediately")

	paused = true
	await create_timer(0.25).timeout
	_expect(_fired_count == 2, "burst extra shot waits while the tree is paused")

	paused = false
	await create_timer(0.25).timeout
	_expect(_fired_count == 3, "burst extra shot fires after unpause")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon_trait_pause_timer_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon_trait_pause_timer_smoke_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
