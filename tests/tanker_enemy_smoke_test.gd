extends SceneTree

const TANKER_SCENE := preload("res://enemies/tanker_enemy.tscn")
const DRONE_SCENE := preload("res://enemies/normal_enemy.tscn")
const BLASTER_SCENE := preload("res://projectiles/player_blaster.tscn")
const AUX_BOLT_SCENE := preload("res://projectiles/aux_cannon_bolt.tscn")
const LASER_SCENE := preload("res://player_ship/weapons/laser_weapon_system.tscn")
const PRESET := preload("res://resources/encounters/presets/tanker_guard_sniper.tres")

var failures := PackedStringArray()
var world: Node2D
var registry: EnemyAugmentRegistry


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.name = "TankerTestWorld"
	world.add_to_group("gameplay_world")
	root.add_child(world)
	registry = EnemyAugmentRegistry.new()
	registry.name = "TankerTestRegistry"
	root.add_child(registry)

	await _test_independent_health_and_cleanup()
	await _test_spatial_projectile_protection()
	await _test_piercing_projectile_policy()
	await _test_laser_policy()
	await _test_formation_and_encounter_spawn()

	world.queue_free()
	registry.queue_free()
	await process_frame
	if failures.is_empty():
		print("tanker_enemy_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("tanker_enemy_smoke_test: %s" % failure)
	quit(1)


func _test_independent_health_and_cleanup() -> void:
	var tanker := _spawn_tanker(Vector2(120, 100))
	var body_start := tanker.get_body_health()
	var shield_start := tanker.get_shield_health()
	var hit := HitboxComponent.new()
	hit.damage = 7

	tanker.shield_hurtbox.hurt.emit(hit)
	_expect(tanker.get_shield_health() == shield_start - 7, "shield hit reduces only Shield HP")
	_expect(tanker.get_body_health() == body_start, "shield hit leaves Body HP unchanged")

	tanker.hurtbox_component.hurt.emit(hit)
	_expect(tanker.get_body_health() == body_start - 7, "body hit reduces only Body HP")
	_expect(tanker.get_shield_health() == shield_start - 7, "body hit leaves Shield HP unchanged")

	hit.damage = tanker.get_shield_health()
	tanker.shield_hurtbox.hurt.emit(hit)
	await process_frame
	await physics_frame
	_expect(not tanker.is_shield_active(), "zero Shield HP destroys only the shield")
	_expect(is_instance_valid(tanker), "shield destruction does not kill the Tanker body")
	_expect(not tanker.shield_visual.visible, "destroyed shield visual is removed")
	_expect(not tanker.shield_hurtbox.monitorable, "destroyed shield collision is disabled")

	hit.damage = 1
	var exposed_body_hp := tanker.get_body_health()
	tanker.hurtbox_component.hurt.emit(hit)
	_expect(tanker.get_body_health() == exposed_body_hp - 1, "body remains damageable after shield break")

	var body_death_tanker := _spawn_tanker(Vector2(220, 100))
	var owned_shield := body_death_tanker.shield
	hit.damage = body_death_tanker.get_body_health()
	body_death_tanker.hurtbox_component.hurt.emit(hit)
	await process_frame
	await process_frame
	_expect(not is_instance_valid(body_death_tanker), "zero Body HP removes the Tanker root")
	_expect(not is_instance_valid(owned_shield), "Body death cleans up an intact owned shield")

	hit.free()
	if is_instance_valid(tanker):
		tanker.queue_free()
	await process_frame


func _test_spatial_projectile_protection() -> void:
	var tanker := _spawn_tanker(Vector2(120, 100))
	var drone := _spawn_drone(Vector2(140, 72))
	var shield_start := tanker.get_shield_health()
	var drone_start := drone.stats_component.health

	_spawn_blaster(Vector2(140, 150))
	await _wait_physics_frames(24)
	_expect(tanker.get_shield_health() < shield_start, "ordinary projectile physically hits the front shield")
	_expect(drone.stats_component.health == drone_start, "front shield prevents the projectile reaching rear Drone")

	var break_hit := HitboxComponent.new()
	break_hit.damage = tanker.get_shield_health()
	tanker.shield_hurtbox.hurt.emit(break_hit)
	await _wait_physics_frames(2)
	_spawn_blaster(Vector2(140, 150))
	await _wait_physics_frames(30)
	_expect(drone.stats_component.health < drone_start, "same lane reaches rear Drone after shield destruction")

	break_hit.free()
	tanker.queue_free()
	drone.queue_free()
	await process_frame


func _test_piercing_projectile_policy() -> void:
	var tanker := _spawn_tanker(Vector2(120, 100))
	var drone := _spawn_drone(Vector2(140, 72))
	var shield_start := tanker.get_shield_health()
	var drone_start := drone.stats_component.health
	var bolt := AUX_BOLT_SCENE.instantiate() as Node2D
	bolt.call("configure_aux_combat", null, 4, 1, 0.75, 1.0, 0.0, 1.0)
	world.add_child(bolt)
	bolt.global_position = Vector2(140, 150)
	(bolt.get_node("MoveComponent") as MoveComponent).velocity = Vector2.UP * 300.0
	await _wait_physics_frames(30)
	_expect(tanker.get_shield_health() == shield_start - 4, "piercing projectile damages Shield first")
	_expect(drone.stats_component.health == drone_start - 3, "remaining pierce continues with existing falloff")

	tanker.queue_free()
	drone.queue_free()
	if is_instance_valid(bolt):
		bolt.queue_free()
	await process_frame


func _test_laser_policy() -> void:
	var tanker := _spawn_tanker(Vector2(120, 100))
	var body_start := tanker.get_body_health()
	var shield_start := tanker.get_shield_health()
	var laser := LASER_SCENE.instantiate() as LaserWeaponSystem
	world.add_child(laser)
	laser.global_position = Vector2(120, 220)
	await _wait_physics_frames(2)
	laser.apply_damage_tick()
	_expect(tanker.get_shield_health() < shield_start, "piercing Laser damages Shield Hurtbox")
	_expect(tanker.get_body_health() < body_start, "Laser keeps existing all-hurtboxes piercing rule")

	laser.queue_free()
	tanker.queue_free()
	await process_frame


func _test_formation_and_encounter_spawn() -> void:
	var errors := PRESET.get_validation_errors()
	_expect(errors.is_empty(), "Tanker guard EncounterPreset validates: %s" % "; ".join(errors))
	var spawner := EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	root.add_child(spawner)
	var controller := spawner.spawn_encounter(PRESET) as FormationController
	await process_frame
	var members := controller.get_members()
	_expect(members.size() == 2, "EncounterPreset spawns Tanker and protected Sniper")
	var tanker: TankerEnemy
	var sniper: Enemy
	for member in members:
		if member is TankerEnemy:
			tanker = member as TankerEnemy
		elif member.scene_file_path == "res://enemies/sniper_enemy.tscn":
			sniper = member
	_expect(tanker != null and tanker.is_formation_member(), "Tanker uses common FormationController membership")
	_expect(sniper != null and sniper.is_formation_member(), "Sniper rides in the rear formation slot")
	if tanker != null:
		var shield_offset := tanker.to_local(tanker.shield.global_position)
		var before := tanker.global_position
		controller.call("_update_member_positions", 0.1)
		_expect(tanker.to_local(tanker.shield.global_position).is_equal_approx(shield_offset), "Shield transform stays fixed to moving Body")
		_expect(tanker.get_formation_slot().slot_id == &"bottom_inner", "Tanker occupies vertical front slot")
		_expect(tanker.global_position.is_equal_approx(before) or controller.center_movement_controller.is_running(), "formation movement remains controller-owned")
	if sniper != null:
		_expect(sniper.get_formation_slot().slot_id == &"center", "Sniper occupies vertical rear slot")

	controller.queue_free()
	spawner.queue_free()
	await process_frame


func _spawn_tanker(at: Vector2) -> TankerEnemy:
	var tanker := TANKER_SCENE.instantiate() as TankerEnemy
	tanker.augment_registry = registry
	world.add_child(tanker)
	tanker.global_position = at
	return tanker


func _spawn_drone(at: Vector2) -> Enemy:
	var drone := DRONE_SCENE.instantiate() as Enemy
	drone.augment_registry = registry
	world.add_child(drone)
	drone.global_position = at
	return drone


func _spawn_blaster(at: Vector2) -> Node2D:
	var projectile := BLASTER_SCENE.instantiate() as Node2D
	world.add_child(projectile)
	projectile.global_position = at
	(projectile.get_node("MoveComponent") as MoveComponent).velocity = Vector2.UP * 300.0
	return projectile


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
