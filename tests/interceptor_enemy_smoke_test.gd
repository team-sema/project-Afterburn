extends SceneTree

const PAIR := preload("res://resources/encounters/presets/interceptor_pair.tres")
const TRIO := preload("res://resources/encounters/presets/interceptor_trio.tres")
const POOL := preload("res://resources/encounters/pools/main_encounter_pool.tres")

var failures := PackedStringArray()
var world: Node2D
var registry: EnemyAugmentRegistry
var spawner: EnemySpawner


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.name = "InterceptorTestWorld"
	world.add_to_group("gameplay_world")
	root.add_child(world)
	registry = EnemyAugmentRegistry.new()
	root.add_child(registry)
	spawner = EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	root.add_child(spawner)

	_test_resources_and_roster()
	await _test_pair_warning_attack_exit_and_reward()
	await _test_trio_formation()
	await _test_forward_turning_contract()

	if is_instance_valid(spawner):
		spawner.queue_free()
	if is_instance_valid(registry):
		registry.queue_free()
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	if failures.is_empty():
		print("interceptor_enemy_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("interceptor_enemy_smoke_test: %s" % failure)
	quit(1)


func _test_resources_and_roster() -> void:
	_expect(PAIR.validate(), "pair EncounterPreset validates")
	_expect(TRIO.validate(), "trio EncounterPreset validates")
	_expect(PAIR.members.size() == 2, "pair always contains two Interceptors")
	_expect(TRIO.members.size() == 3, "trio always contains three Interceptors")
	_expect(PAIR.start_delay >= 0.85, "pair provides a longer offscreen entry warning delay")
	_expect(TRIO.start_delay >= 0.85, "trio provides a longer offscreen entry warning delay")
	var run := PAIR.formation_movement_sequence
	_expect(run.steps.size() == 1, "attack run has one continuous movement step")
	_expect(run.steps[0] is ForwardAttackRunMovementStep, "attack run uses forward-only flight")

	var drone := (load("res://enemies/normal_enemy.tscn") as PackedScene).instantiate() as Enemy
	var interceptor := (
		(load("res://enemies/interceptor_enemy.tscn") as PackedScene).instantiate()
		as InterceptorEnemy
	)
	_expect(
		(interceptor.get_node("StatsComponent") as StatsComponent).health == 40,
		"Interceptor uses raised health (40)",
	)
	_expect(
		(drone.get_node("StatsComponent") as StatsComponent).health == 20,
		"Drone baseline health remains 20",
	)
	var shoot := interceptor.get_node("EnemyShootComponent") as EnemyShootComponent
	_expect(not shoot.use_actor_forward_direction, "Interceptor aims projectiles at the player")
	_expect(shoot.burst_count >= 10, "Interceptor fires a denser single burst")
	_expect(shoot.burst_interval <= 0.06, "Interceptor burst spacing is rapid")
	_expect(shoot.active_duration <= 0.85, "Interceptor fire window fits one burst only")
	_expect(shoot.fire_interval >= 5.0, "Interceptor does not schedule a second burst")
	var warning := interceptor.get_node("EntryWarningComponent") as EntryWarningComponent
	_expect(warning.warning_duration >= 0.85, "Interceptor warning lasts longer before entry")
	_expect(warning.face_spawn_side, "Interceptor warning points at the spawn side")
	drone.free()
	interceptor.free()

	var interceptor_encounters := 0
	for entry in POOL.entries:
		var preset := entry.preset
		if preset == null or preset.members.is_empty():
			continue
		var first_scene := preset.members[0].enemy_scene
		if first_scene.resource_path != "res://enemies/interceptor_enemy.tscn":
			continue
		interceptor_encounters += 1
		_expect(
			preset.encounter_id in [&"interceptor_pair", &"interceptor_trio"],
			"MainEncounterPool has no solo Interceptor preset",
		)
		_expect(preset.members.size() in [2, 3], "pooled Interceptors are always grouped")
	_expect(interceptor_encounters == 2, "MainEncounterPool exposes pair and trio only")


func _test_pair_warning_attack_exit_and_reward() -> void:
	var player := Node2D.new()
	player.name = "InterceptorTestPlayer"
	player.add_to_group("player")
	player.global_position = Vector2(320.0, 280.0)
	world.add_child(player)

	var run_direction := Vector2(1.0, 0.4).normalized()
	var controller := spawner.spawn_encounter(
		PAIR,
		-1,
		Callable(),
		{"attack_run_direction": run_direction},
	) as FormationController
	var members := controller.get_members()
	_expect(members.size() == 2, "pair spawns two members")
	var start_center := controller.global_position
	var visible := controller.get_viewport_rect()
	_expect(start_center.x < visible.position.x, "rightward pair spawns off the left edge")
	_expect(run_direction.y > 0.2, "forced lane includes a downward dive angle")
	_expect(
		start_center.y >= visible.position.y + visible.size.y * 0.10,
		"pair spawn Y stays out of the deep rear band",
	)
	_expect(
		start_center.y <= visible.position.y + visible.size.y * 0.45,
		"pair spawn Y stays in the upper play band",
	)
	for member in members:
		_expect(member is InterceptorEnemy, "pair member uses InterceptorEnemy")
		_expect(member.global_position.x < visible.position.x, "pair member starts off left")
		var warning := member.get_node_or_null("EntryWarningComponent") as EntryWarningComponent
		_expect(warning != null and warning.is_warning_active(), "each entry lane has a warning")
		var shoot := member.get_node("EnemyShootComponent") as EnemyShootComponent
		_expect(shoot.get_volleys_fired() == 0, "offscreen Interceptor has not fired")
		_expect(shoot.projectile_speed > 210.0, "projectile outruns the Interceptor")

	await process_frame
	members = controller.get_members()
	for member in members:
		var warning := member.get_node_or_null("EntryWarningComponent") as EntryWarningComponent
		_expect(warning != null and warning.is_warning_active(), "warning remains after slot settle")
		if warning != null:
			_expect(visible.has_point(warning.global_position), "warning is placed just inside the edge")
			_expect(
				warning.entry_direction.normalized().dot(Vector2.RIGHT) > 0.999,
				"warning is placed from the left entry edge inward",
			)
			_expect(warning.face_spawn_side, "warning facing swaps to the spawn side")
			var face_left := Vector2.LEFT.angle() - Vector2.DOWN.angle()
			_expect(
				absf(angle_difference(warning.global_rotation, face_left)) < 0.02,
				"left-side entry warning points left",
			)
			_expect(
				absf(warning.global_position.y - member.global_position.y) < 1.0,
				"warning marks the spawn entry Y, not a projected dive crossing",
			)
			_expect(
				warning.global_position.x <= visible.position.x + 20.0,
				"warning sits on the left entry edge",
			)

	await create_timer(0.4).timeout
	_expect(
		controller.global_position.distance_to(start_center) < 0.01,
		"formation remains offscreen during warning",
	)
	for member in controller.get_members():
		var shoot := member.get_node("EnemyShootComponent") as EnemyShootComponent
		_expect(shoot.get_volleys_fired() == 0, "warning phase cannot fire from offscreen")

	await create_timer(1.0).timeout
	_expect(controller.global_position.x > start_center.x + 30.0, "pair makes a high-speed entry")
	_expect(controller.global_position.y > start_center.y + 10.0, "angled pass also descends")
	var velocity := controller.center_move_component.velocity
	_expect(is_equal_approx(velocity.length(), 210.0), "attack-run speed is 210 px/s")
	var controller_forward := Vector2.DOWN.rotated(controller.global_rotation)
	_expect(controller_forward.dot(velocity.normalized()) > 0.999, "formation forward matches velocity")
	_expect(velocity.normalized().dot(run_direction) > 0.999, "pair travels along the forced angled lane")
	members = controller.get_members()
	for member in members:
		var member_forward := Vector2.DOWN.rotated(member.global_rotation)
		_expect(member_forward.dot(velocity.normalized()) > 0.999, "member faces formation travel")
		var shoot := member.get_node("EnemyShootComponent") as EnemyShootComponent
		_expect(shoot.has_visible_pass_started(), "fire window starts only after visible entry")
		_expect(shoot.get_volleys_fired() > 0, "visible Interceptor fires its short burst")
		_expect(member.get_node_or_null("EntryWarningComponent") == null, "warning ends before attack")
	if members.size() == 2:
		_expect(
			is_equal_approx(members[0].global_position.distance_to(members[1].global_position), 36.0),
			"pair preserves its 36 px slot spacing after angled facing",
		)

	var projectile := _find_first_enemy_projectile()
	_expect(projectile != null, "aimed burst spawns the shared enemy projectile")
	if projectile != null:
		var projectile_velocity := (projectile.get_node("MoveComponent") as MoveComponent).velocity
		var aim := projectile.global_position.direction_to(player.global_position)
		_expect(
			projectile_velocity.normalized().dot(aim) > 0.98,
			"projectile launches toward the player",
		)
		_expect(
			projectile_velocity.length() > velocity.length(),
			"projectile speed exceeds Interceptor speed",
		)

	# One dense burst only: let the short fire window finish, then confirm no more shots.
	await create_timer(1.0).timeout
	var volleys_after_burst: Array[int] = []
	members = controller.get_members()
	for member in members:
		var shoot := member.get_node("EnemyShootComponent") as EnemyShootComponent
		_expect(not shoot.is_fire_window_active(), "fire window closes after the single burst")
		_expect(
			shoot.get_volleys_fired() == shoot.burst_count,
			"Interceptor spent its full single burst",
		)
		volleys_after_burst.append(shoot.get_volleys_fired())
	await create_timer(0.6).timeout
	members = controller.get_members()
	for index in members.size():
		if index >= volleys_after_burst.size():
			break
		var shoot := members[index].get_node("EnemyShootComponent") as EnemyShootComponent
		_expect(
			shoot.get_volleys_fired() == volleys_after_burst[index],
			"Interceptor fires only one burst per pass",
		)

	var victim := members[0]
	var drops := victim.get_node("ExperienceDropComponent") as ExperienceDropComponent
	drops.drop_chance = 1.0
	var orbs_before := _count_experience_orbs()
	victim.stats_component.health = 0
	await process_frame
	await process_frame
	_expect(_count_experience_orbs() == orbs_before + 1, "destroyed Interceptor grants normal XP")

	await create_timer(1.45).timeout
	if is_instance_valid(controller):
		for survivor in controller.get_members():
			var shoot := survivor.get_node("EnemyShootComponent") as EnemyShootComponent
			_expect(not shoot.is_fire_window_active(), "attack window ends while the pass continues")
	var orbs_after_kill := _count_experience_orbs()
	await create_timer(4.5).timeout
	_expect(not is_instance_valid(controller), "surviving Interceptor exits DespawnArea once")
	_expect(
		_count_experience_orbs() == orbs_after_kill,
		"normal offscreen exit grants no XP or kill reward",
	)
	player.queue_free()
	await process_frame


func _test_trio_formation() -> void:
	var controller := spawner.spawn_encounter(
		TRIO,
		-1,
		Callable(),
		{"attack_run_direction": Vector2(-1.0, 0.35).normalized()},
	) as FormationController
	var members := controller.get_members()
	_expect(members.size() == 3, "trio spawns three members")
	var layout := controller.get_layout()
	_expect(
		layout.get_slot(0).position.is_equal_approx(Vector2(0.0, 11.0)),
		"trio has a forward point slot",
	)
	_expect(
		layout.get_slot(1).position.is_equal_approx(Vector2(-16.0, -11.0)),
		"trio has a left wing slot",
	)
	_expect(
		layout.get_slot(2).position.is_equal_approx(Vector2(16.0, -11.0)),
		"trio has a right wing slot",
	)
	await create_timer(1.1).timeout
	if is_instance_valid(controller):
		var velocity := controller.center_move_component.velocity.normalized()
		_expect(velocity.y > 0.2, "trio dive includes downward angle")
		for member in controller.get_members():
			_expect(
				Vector2.DOWN.rotated(member.global_rotation).dot(velocity) > 0.999,
				"trio members share one facing direction",
			)
	controller.queue_free()
	await process_frame


func _test_forward_turning_contract() -> void:
	var actor := Node2D.new()
	var move := MoveComponent.new()
	move.actor = actor
	var controller := MovementController.new()
	controller.actor = actor
	controller.move_component = move
	controller.auto_start = false
	actor.add_child(move)
	actor.add_child(controller)
	root.add_child(actor)
	await process_frame

	var step := ForwardAttackRunMovementStep.new()
	step.speed = 100.0
	step.target_direction = Vector2.RIGHT
	step.turn_speed_degrees = 90.0
	step.face_direction_on_start = false
	var sequence := MovementSequence.new()
	sequence.steps.append(step)
	controller.set_sequence(sequence)
	controller.start()
	controller.set_process(false)
	controller.update_movement(0.25)
	var first_forward := Vector2.DOWN.rotated(actor.global_rotation)
	_expect(actor.global_rotation < 0.0, "aircraft begins rotating toward the requested path")
	_expect(first_forward.dot(move.velocity.normalized()) > 0.999, "turning velocity remains forward-only")
	_expect(move.velocity.normalized().dot(Vector2.RIGHT) < 0.999, "velocity does not snap ahead of rotation")
	for _index in 3:
		controller.update_movement(0.25)
	var final_forward := Vector2.DOWN.rotated(actor.global_rotation)
	_expect(final_forward.dot(Vector2.RIGHT) > 0.999, "aircraft completes the physical turn")
	_expect(move.velocity.normalized().dot(Vector2.RIGHT) > 0.999, "velocity follows completed rotation")
	actor.queue_free()
	await process_frame


func _find_first_enemy_projectile() -> Node2D:
	for node in get_nodes_in_group("enemy_projectiles"):
		if node is Node2D and node.get_viewport() == world.get_viewport():
			return node as Node2D
	return null


func _count_experience_orbs() -> int:
	var count := 0
	for child in world.get_children():
		if child is ExperienceOrb:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
