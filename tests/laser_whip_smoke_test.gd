extends SceneTree

## laser_whip: the beam tip lags the ship's sideways movement on a spring,
## stays inside its sway limit, settles back to straight, and the curved beam
## is what deals damage.


class MockLoadout:
	extends Node

	signal weapon_trait_changed(weapon_id: StringName, trait_id: StringName, new_rank: int)

	var traits: Dictionary = {}


	func get_weapon_traits(_weapon_id: StringName) -> Dictionary:
		return traits


const START := Vector2(150.0, 300.0)
const SHIP_SPEED := 100.0

var failures: PackedStringArray = []
var _hurt_counts: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loadout := MockLoadout.new()
	root.add_child(loadout)
	var laser := (load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene).instantiate() as LaserWeaponSystem
	laser.position = START
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
	await process_frame
	if failures.is_empty():
		print("laser_whip_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_whip_smoke_test: %s" % failure)
	quit(1)


func _make_target(target_name: String, position: Vector2) -> HurtboxComponent:
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = target_name
	hurtbox.collision_layer = 1 << 1
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 1.0
	shape.shape = circle
	hurtbox.add_child(shape)
	root.add_child(hurtbox)
	hurtbox.global_position = position
	_hurt_counts[target_name] = 0
	hurtbox.hurt.connect(func(_hitbox: Variant) -> void: _hurt_counts[target_name] += 1)
	return hurtbox


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
