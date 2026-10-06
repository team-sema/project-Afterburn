extends SceneTree

## Laser damage rules: hit band and wide lens, laser_whip curved hits,
## laser_heat_stack contact bonus and the gameplay clock it runs on.
## Each check uses a fresh laser instance.


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


const LASER_SCENE := preload("res://player_ship/weapons/laser_weapon_system.tscn")
const BEAM_X := 80.0
const TARGET_Y := 100.0
const TARGET_RADIUS := 1.0
const WHIP_START := Vector2(150.0, 300.0)
const SHIP_SPEED := 100.0
const HEAT_TICK := 0.1

var failures: PackedStringArray = []
var _hurt_counts: Dictionary = {}
var _heat_laser: LaserWeaponSystem
var _heat_enemy: Node2D
var _heat_base_time := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_hit_band_and_wide_lens()
	await _test_whip()
	await _test_heat_stack()
	await _test_heat_clock_pauses()

	if failures.is_empty():
		print("laser_damage_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_damage_smoke_test: %s" % failure)
	quit(1)


## The laser damages hurtboxes inside its hit band, and laser_wide_lens widens
## that band together with the visual beam.
func _test_hit_band_and_wide_lens() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var laser := LASER_SCENE.instantiate() as LaserWeaponSystem
	laser.position = Vector2(BEAM_X, 216.0)
	root.add_child(laser)
	await physics_frame
	laser.setup_weapon(null, loadout, 0, &"main_laser")
	laser.damage_tick_timer.stop()

	# Edge distances from the beam axis: 0 (centre), 0.8 (off-axis but inside
	# the 3px band), 2.0 (outside the base band, inside wide lens Lv.V).
	var centre := _make_target("centre", Vector2(BEAM_X, TARGET_Y))
	var off_axis := _make_target("off_axis", Vector2(BEAM_X + 0.8 + TARGET_RADIUS, TARGET_Y))
	var wide_only := _make_target("wide_only", Vector2(BEAM_X + 2.0 + TARGET_RADIUS, TARGET_Y))
	var far := _make_target("far", Vector2(BEAM_X + 12.0, TARGET_Y))
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
	_hurt_counts.clear()
	await process_frame


## laser_whip: the beam tip lags the ship's sideways movement on a spring,
## stays inside its sway limit, settles back to straight, and the curved beam
## is what deals damage.
func _test_whip() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var laser := LASER_SCENE.instantiate() as LaserWeaponSystem
	laser.position = WHIP_START
	root.add_child(laser)
	await physics_frame
	laser.setup_weapon(null, loadout, 0, &"main_laser")
	laser.damage_tick_timer.stop()
	await physics_frame
	_expect(laser.get_beam_points().size() == 2, "without the module the beam is a straight two-point line")

	loadout.traits = {&"laser_whip": 1}
	for _i in 3:
		await physics_frame
	_expect(laser.get_whip_shape().is_zero_approx(), "a resting ship keeps the whip beam straight")

	# Fly right for 0.5s at ship speed: the tip lags to the left.
	for _i in 30:
		laser.position.x += SHIP_SPEED / 60.0
		await physics_frame
	var endpoint: Vector2 = laser.call("_full_beam_endpoint")
	var limit := LaserWeaponSystem.BEAM_LOCAL_START.distance_to(endpoint) * 0.18
	var sway := laser.get_whip_shape()
	_expect(sway.x < -1.0, "moving right swings the tip left (got %.2f)" % sway.x)
	_expect(absf(sway.x) <= limit + 0.001, "sway stays inside 18%% of the beam length")
	_expect(laser.get_beam_points().size() == 13, "the swaying beam is drawn and hit-tested in 12 segments")
	var glow := laser.get_node("GlowLine") as Sprite2D
	_expect(glow.scale.x >= laser.glow_body_scale_x, "the glow sprite widens to fit the curve")

	# A sudden jump pins the tip at the sway limit.
	laser.position.x += 120.0
	await physics_frame
	_expect(is_equal_approx(laser.get_whip_shape().x, -limit), "a sudden jump clamps the tip at the limit")

	# Freeze the bent beam, then check the curve is what hits.
	laser.set_physics_process(false)
	var points := laser.get_beam_points()
	var bent_point := laser.to_global(points[10])
	var axis_point := Vector2(laser.global_position.x, bent_point.y)
	var on_curve := _make_target("on_curve", bent_point)
	var on_axis := _make_target("on_axis", axis_point)
	await physics_frame
	await physics_frame
	_expect(bent_point.distance_to(axis_point) > 8.0, "the test beam is visibly bent at the probe height")
	laser.apply_damage_tick()
	_expect(_hurt_counts["on_curve"] == 1, "an enemy on the bent beam is hit once")
	_expect(_hurt_counts["on_axis"] == 0, "the old straight axis no longer hits")
	on_curve.queue_free()
	on_axis.queue_free()

	# Stop moving: it rebounds and settles back to straight.
	laser.set_physics_process(true)
	for _i in 240:
		await physics_frame
	_expect(absf(laser.get_whip_shape().x) < 1.0, "after stopping the beam settles back to straight")

	# Pause freezes the springs.
	laser.position.x -= 60.0
	await physics_frame
	var before := laser.get_whip_shape()
	paused = true
	await create_timer(0.2).timeout
	_expect(laser.get_whip_shape().is_equal_approx(before), "tree pause freezes the whip springs")
	paused = false

	laser.queue_free()
	loadout.queue_free()
	_hurt_counts.clear()
	await process_frame


## laser_heat_stack grows with continuous contact time and resets after a gap.
func _test_heat_stack() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	_heat_laser = LASER_SCENE.instantiate() as LaserWeaponSystem
	root.add_child(_heat_laser)
	await physics_frame
	_heat_laser.setup_weapon(null, loadout, 0, &"main_laser")
	_heat_laser.set_physics_process(false)
	_heat_laser.damage_tick_timer.stop()
	_heat_enemy = Node2D.new()
	root.add_child(_heat_enemy)

	loadout.traits = {&"laser_heat_stack": 1}
	_heat_restart(10.0)
	_expect(is_zero_approx(_heat_hit_at(0.0)), "first contact has no heat bonus")
	_expect(is_zero_approx(_heat_contact(0.1, 0.4)), "no bonus before the first 0.5s of contact")
	_expect(is_equal_approx(_heat_contact(0.5, 0.5), 0.15), "0.5s of continuous contact adds +15%")
	_expect(is_equal_approx(_heat_contact(0.6, 1.5), 0.45), "1.5s of continuous contact adds +45%")
	_expect(is_equal_approx(_heat_contact(1.6, 3.0), 0.9), "Lv.I reaches the +90% cap after 3s")
	_expect(is_equal_approx(_heat_contact(3.1, 5.0), 0.9), "bonus stays at the cap")

	_heat_restart(100.0)
	_heat_contact(0.0, 1.0)
	# Pulse OFF window: last ON tick, 0.35s off, next tick lands 0.45s later.
	_expect(is_equal_approx(_heat_hit_at(1.45), 0.3), "a 0.45s pulse gap keeps the contact run")

	_heat_restart(200.0)
	_heat_contact(0.0, 2.0)
	_expect(is_zero_approx(_heat_hit_at(2.6)), "a gap over 0.5s restarts heat from zero")
	_expect(is_equal_approx(_heat_contact(2.7, 3.1), 0.15), "heat builds again after the restart")

	_heat_restart(300.0)
	_heat_contact(0.0, 1.0)
	_expect(is_zero_approx(_heat_hit_at(30.0)), "a long absence does not bank heat")

	loadout.traits = {&"laser_heat_stack": 3}
	_heat_restart(400.0)
	_expect(is_equal_approx(_heat_contact(0.0, 0.5), 0.25), "Lv.III adds +25% per 0.5s")
	_expect(is_equal_approx(_heat_contact(0.6, 3.0), 1.5), "Lv.III reaches the +150% cap after 3s")

	_heat_laser.set("_clock", 400.0 + 3.0 + 0.6)
	_heat_laser.call("_prune_heat_stacks")
	_expect((_heat_laser.get("_heat_stacks") as Dictionary).is_empty(), "stale heat entries are pruned")

	_heat_laser.queue_free()
	loadout.queue_free()
	_heat_enemy.queue_free()
	await process_frame


## Heat intervals run on gameplay time: a paused tree (augment pick / bullet
## cancel) leaves the laser clock untouched.
func _test_heat_clock_pauses() -> void:
	var laser := LASER_SCENE.instantiate() as LaserWeaponSystem
	root.add_child(laser)
	await physics_frame
	await physics_frame
	var before: float = laser.get("_clock")
	_expect(before > 0.0, "laser clock advances while the tree runs")

	paused = true
	await create_timer(0.2).timeout
	var during: float = laser.get("_clock")
	_expect(is_equal_approx(before, during), "paused tree does not advance the laser heat clock")

	paused = false
	await physics_frame
	await physics_frame
	var after: float = laser.get("_clock")
	_expect(after > during, "laser clock resumes after unpause")

	laser.queue_free()
	await process_frame


func _make_target(target_name: String, position: Vector2) -> HurtboxComponent:
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
	hurtbox.global_position = position
	_hurt_counts[target_name] = 0
	hurtbox.hurt.connect(func(_hitbox: Variant) -> void: _hurt_counts[target_name] += 1)
	return hurtbox


func _tick(laser: LaserWeaponSystem) -> void:
	for key in _hurt_counts.keys():
		_hurt_counts[key] = 0
	laser.apply_damage_tick()


func _heat_restart(base_time: float) -> void:
	_heat_base_time = base_time
	_heat_laser.set("_heat_stacks", {})


func _heat_hit_at(offset: float) -> float:
	_heat_laser.set("_clock", _heat_base_time + offset)
	return float(_heat_laser.call("_heat_bonus_for", _heat_enemy))


## Beam ticks every 0.1s from `from_offset` through `to_offset`; returns the last bonus.
func _heat_contact(from_offset: float, to_offset: float) -> float:
	var bonus := 0.0
	var steps := roundi((to_offset - from_offset) / HEAT_TICK)
	for step in steps + 1:
		bonus = _heat_hit_at(from_offset + step * HEAT_TICK)
	return bonus


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
