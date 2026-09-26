extends SceneTree

## Silver `<weapon_id>_power` modules scale only their own weapon's damage.


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var blaster := (load("res://player_ship/weapons/blaster_weapon_system.tscn") as PackedScene).instantiate() as WeaponSystem
	var laser := (load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene).instantiate() as WeaponSystem
	root.add_child(blaster)
	root.add_child(laser)
	await process_frame
	blaster.setup_weapon(null, loadout, 0, &"main_blaster")
	laser.setup_weapon(null, loadout, 1, &"main_laser")

	_expect(is_equal_approx(blaster.get_effective_damage_multiplier(), 1.0), "no power module keeps ×1.0")
	loadout.traits = {&"main_blaster_power": 3}
	_expect(is_equal_approx(blaster.get_effective_damage_multiplier(), 1.24), "blaster power Lv.III is ×1.24")
	_expect(
		is_equal_approx(float(blaster.get_projectile_damage_snapshot()["damage_multiplier"]), 1.24),
		"projectile launch snapshot carries the power bonus",
	)
	_expect(is_equal_approx(laser.get_effective_damage_multiplier(), 1.0), "another weapon ignores the blaster power module")

	blaster.set_rule_damage_multiplier(0.85)
	_expect(
		is_equal_approx(blaster.get_effective_damage_multiplier(), 1.24 * 0.85),
		"rule and power channels multiply",
	)

	blaster.queue_free()
	laser.queue_free()
	loadout.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon_power_module_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon_power_module_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
