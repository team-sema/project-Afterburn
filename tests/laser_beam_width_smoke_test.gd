extends SceneTree

## The laser damages hurtboxes inside its hit band, and laser_wide_lens widens
## that band together with the visual beam.


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


const BEAM_X := 80.0
const TARGET_Y := 100.0
const TARGET_RADIUS := 1.0

var failures: PackedStringArray = []
var _hurt_counts: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var laser := (load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene).instantiate() as LaserWeaponSystem
	laser.position = Vector2(BEAM_X, 216.0)
	root.add_child(laser)
	await physics_frame
	laser.setup_weapon(null, loadout, 0, &"main_laser")
	laser.damage_tick_timer.stop()

	# Edge distances from the beam axis: 0 (centre), 0.8 (off-axis but inside
	# the 3px band), 2.0 (outside the base band, inside wide lens Lv.V).
	var centre := _make_target("centre", BEAM_X)
	var off_axis := _make_target("off_axis", BEAM_X + 0.8 + TARGET_RADIUS)
	var wide_only := _make_target("wide_only", BEAM_X + 2.0 + TARGET_RADIUS)
	var far := _make_target("far", BEAM_X + 12.0)
	await physics_frame
	await physics_frame

	_expect(is_equal_approx(laser.get_beam_hit_width(), 3.0), "base hit band is 3px")
	_tick(laser)
	_expect(_hurt_counts["centre"] == 1, "beam hits a target on its axis")
	_expect(_hurt_counts["off_axis"] == 1, "beam hits a target inside the band but off its axis")
	_expect(_hurt_counts["wide_only"] == 0, "base beam misses a target outside its band")
	_expect(_hurt_counts["far"] == 0, "beam misses a distant target")
	_expect(ImpactVfx.get_or_create(laser).get_active_flare_count() == 2, "each beam hit shows one contact flare")

	loadout.traits = {&"laser_wide_lens": 5}
	_expect(is_equal_approx(laser.get_beam_hit_width(), 3.0 * 2.0), "wide lens Lv.V widens the hit band")
	_tick(laser)
	_expect(_hurt_counts["centre"] == 1, "wide beam still hits the centre target once per tick")
	_expect(_hurt_counts["wide_only"] == 1, "wide lens Lv.V hits a target outside the base band")
	_expect(_hurt_counts["far"] == 0, "wide lens still misses a distant target")

	for target in [centre, off_axis, wide_only, far]:
		target.queue_free()
	laser.queue_free()
	loadout.queue_free()
	await process_frame
	if failures.is_empty():
		print("laser_beam_width_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_beam_width_smoke_test: %s" % failure)
	quit(1)


func _make_target(target_name: String, x: float) -> HurtboxComponent:
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = target_name
	hurtbox.collision_layer = 1 << 1
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = TARGET_RADIUS
	shape.shape = circle
	hurtbox.add_child(shape)
	root.add_child(hurtbox)
	hurtbox.global_position = Vector2(x, TARGET_Y)
	_hurt_counts[target_name] = 0
	hurtbox.hurt.connect(func(_hitbox: Variant) -> void: _hurt_counts[target_name] += 1)
	return hurtbox


func _tick(laser: LaserWeaponSystem) -> void:
	for key in _hurt_counts.keys():
		_hurt_counts[key] = 0
	laser.apply_damage_tick()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
