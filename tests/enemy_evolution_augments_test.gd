extends SceneTree

const EVOLUTION_DIR := "res://resources/enemy_augments/evolutions"
const EVOLVE_DRONE := preload("res://resources/enemy_augments/evolutions/enemy_evolve_drone.tres")
const EVOLVE_STRIKER := preload("res://resources/enemy_augments/evolutions/enemy_evolve_striker.tres")
const EVOLVE_AWL := preload("res://resources/enemy_augments/evolutions/enemy_evolve_awl.tres")
const EVOLVE_BOMB := preload("res://resources/enemy_augments/evolutions/enemy_evolve_bomb.tres")
const EVOLVE_INTERCEPTOR := preload(
	"res://resources/enemy_augments/evolutions/enemy_evolve_interceptor.tres"
)
const EVOLVE_TANKER := preload("res://resources/enemy_augments/evolutions/enemy_evolve_tanker.tres")
const EVOLVE_CASTER := preload("res://resources/enemy_augments/evolutions/enemy_evolve_caster.tres")
const EVOLVE_SNIPER := preload("res://resources/enemy_augments/evolutions/enemy_evolve_sniper.tres")
const DRONE_SCENE := preload("res://enemies/normal_enemy.tscn")
const BOMB_SCENE := preload("res://enemies/bomb_enemy.tscn")
const TANKER_SCENE := preload("res://enemies/tanker_enemy.tscn")
const SNIPER_SCENE := preload("res://enemies/sniper_enemy.tscn")
const DRONE_PRESET := preload("res://resources/encounters/presets/v3_drone_down.tres")
const ATTACK_RUN := preload("res://resources/enemy_movement/sequences/interceptor_attack_run.tres")
const ORIGINALS := {
	&"enemy_evolve_drone": "res://enemies/normal_enemy.tscn",
	&"enemy_evolve_striker": "res://enemies/moving_enemy.tscn",
	&"enemy_evolve_awl": "res://enemies/kamikaze_enemy.tscn",
	&"enemy_evolve_bomb": "res://enemies/bomb_enemy.tscn",
	&"enemy_evolve_interceptor": "res://enemies/interceptor_enemy.tscn",
	&"enemy_evolve_tanker": "res://enemies/tanker_enemy.tscn",
	&"enemy_evolve_caster": "res://enemies/shooting_enemy.tscn",
	&"enemy_evolve_sniper": "res://enemies/sniper_enemy.tscn",
}

var failures: PackedStringArray = []
var world: Node2D
var _registries: Array[EnemyAugmentRegistry] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)

	_check_cards()
	_check_registry_and_offer()
	await _check_spawner_substitution()
	await _check_drone()
	await _check_striker()
	await _check_awl()
	await _check_bomb()
	await _check_interceptor()
	await _check_tanker()
	await _check_caster()
	await _check_sniper()

	world.queue_free()
	for _frame in 3:
		await process_frame
	_free_registries()
	if failures.is_empty():
		print("enemy_evolution_augments_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_evolution_augments_test: %s" % failure)
	quit(1)


func _check_cards() -> void:
	var cards := AugmentPoolLoader.load_enemy_augments(EVOLUTION_DIR)
	_expect(cards.size() == 8, "eight evolution cards exist")
	var pool := AugmentPoolLoader.load_enemy_offer_pool()
	for card in cards:
		_expect(pool.has(card), "%s is in the enemy offer pool" % card.augment_id)
		_expect(card.is_evolution() and card.max_stacks == 1, "%s is a one-time evolution" % card.augment_id)
		_expect(card.icon != null, "%s has an icon" % card.augment_id)
		_expect(
			ORIGINALS.get(card.augment_id, "") == card.evolution_from.resource_path,
			"%s evolves its original scene" % card.augment_id,
		)
		var evolved := card.evolution_to.instantiate() as Enemy
		_expect(evolved != null, "%s evolved scene root is an Enemy" % card.augment_id)
		if evolved != null:
			_expect(
				evolved.get_node_or_null("Anchor/EvolutionMark") is EnemyEvolutionMark,
				"%s evolved scene carries the evolution mark" % card.augment_id,
			)
			evolved.free()


func _check_registry_and_offer() -> void:
	var registry := _registry([])
	_expect(registry.resolve_enemy_scene(DRONE_SCENE) == DRONE_SCENE, "unevolved scenes resolve to themselves")
	var offer := AugmentOfferController.new()
	offer.enemy_registry = registry
	_expect(not offer._is_enemy_augment_available(EVOLVE_DRONE), "evolution is withheld before the enemy appears")
	registry.note_enemy_scene_spawned(DRONE_SCENE)
	_expect(registry.has_seen_enemy_scene(DRONE_SCENE), "registry records a spawned original scene")
	_expect(offer._is_enemy_augment_available(EVOLVE_DRONE), "evolution is offered once the enemy has appeared")
	_expect(not offer._is_enemy_augment_available(EVOLVE_BOMB), "other evolutions stay withheld")
	registry.add_augment(EVOLVE_DRONE)
	_expect(
		registry.resolve_enemy_scene(DRONE_SCENE) == EVOLVE_DRONE.evolution_to,
		"an active evolution resolves the original to the evolved scene",
	)
	_expect(not offer._is_enemy_augment_available(EVOLVE_DRONE), "a chosen evolution is not offered again")
	_expect(
		registry.resolve_enemy_scene(BOMB_SCENE) == BOMB_SCENE,
		"evolutions only replace their own original scene",
	)
	registry.clear_augments()
	_expect(not registry.has_seen_enemy_scene(DRONE_SCENE), "clearing the run forgets appearances")
	offer.free()


func _check_spawner_substitution() -> void:
	var registry := _registry([])
	var spawner := EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	root.add_child(spawner)
	var spawned: Array[Enemy] = []
	spawner.enemy_spawned.connect(func(enemy: Enemy) -> void: spawned.append(enemy))
	spawner.spawn_encounter(DRONE_PRESET, 0)
	await _wait(1.0)
	_expect(registry.has_seen_enemy_scene(DRONE_SCENE), "spawning a drone encounter records the drone")
	var all_plain := not spawned.is_empty()
	for enemy in spawned:
		all_plain = all_plain and enemy.scene_file_path == DRONE_SCENE.resource_path
	_expect(all_plain, "drones spawn unevolved before the evolution")
	registry.add_augment(EVOLVE_DRONE)
	spawned.clear()
	spawner.spawn_encounter(DRONE_PRESET, 0)
	await _wait(1.0)
	var all_evolved := not spawned.is_empty()
	for enemy in spawned:
		all_evolved = all_evolved and enemy.scene_file_path == EVOLVE_DRONE.evolution_to.resource_path
		_expect(enemy.spawn_id == DRONE_PRESET.encounter_id, "evolved members keep the encounter spawn id")
	_expect(all_evolved, "drones spawn evolved after the evolution")
	spawner.queue_free()
	_clear_world()
	await process_frame


func _check_drone() -> void:
	var drone := await _spawn(EVOLVE_DRONE.evolution_to, _registry([]))
	_expect(drone.stats_component.health == 40, "evolved drone has 40 HP")
	var shoot := drone.get_node("EnemyShootComponent") as EnemyShootComponent
	var fire_steps := 0
	for step in shoot._pattern.steps:
		if step.action == BarrageStep.Action.FIRE:
			fire_steps += 1
	_expect(fire_steps == 3, "evolved drone fires a three-shot burst")
	_clear_world()
	await process_frame


func _check_striker() -> void:
	var striker := await _spawn(EVOLVE_STRIKER.evolution_to, _registry([]), Vector2(320, 80))
	var wake := striker.get_node("WakeShotComponent") as WakeShotComponent
	await _wait(1.0)
	_expect(wake.get_shots_fired() >= 2, "released evolved striker drops wake shots while moving")
	_expect(wake.get_shots_fired() % 2 == 0, "wake shots leave in side pairs")
	_clear_world()
	await process_frame


func _check_awl() -> void:
	var awl := await _spawn(EVOLVE_AWL.evolution_to, _registry([]), Vector2(320, 40), func(enemy: Enemy) -> void:
		enemy.set("charge_duration", 0.2)
		enemy.set("redash_delay", 0.2)
		enemy.set("recharge_duration", 0.2)
	)
	awl.call("_begin_charging")
	await _wait(1.4)
	_expect(int(awl.call("get_dash_count")) == 2, "evolved awl dashes a second time")
	_clear_world()
	await process_frame


func _check_bomb() -> void:
	var plain := await _spawn(BOMB_SCENE, _registry([]), Vector2(200, 100))
	var before := _bullet_count()
	(plain.get_node("BombProximityFuseComponent") as BombProximityFuseComponent)._detonate()
	await process_frame
	_expect(_bullet_count() == before, "a plain bomb detonation releases no ring")
	var evolved := await _spawn(EVOLVE_BOMB.evolution_to, _registry([]), Vector2(400, 100))
	before = _bullet_count()
	(evolved.get_node("BombProximityFuseComponent") as BombProximityFuseComponent)._detonate()
	await process_frame
	_expect(_bullet_count() - before == 12, "an evolved bomb detonation releases a 12-shot ring")
	var killed := await _spawn(EVOLVE_BOMB.evolution_to, _registry([]), Vector2(300, 60))
	before = _bullet_count()
	killed.stats_component.health = 0
	await process_frame
	await process_frame
	_expect(_bullet_count() == before, "an evolved bomb killed before detonating releases no ring")
	_clear_world()
	await process_frame


func _check_interceptor() -> void:
	var interceptor := await _spawn(EVOLVE_INTERCEPTOR.evolution_to, _registry([]), Vector2(520, 120))
	var return_pass := interceptor.get_node("ReturnPassComponent") as ReturnPassComponent
	interceptor.set_movement_sequence(ATTACK_RUN, {"attack_run_direction": Vector2.RIGHT})
	var saw_hold := false
	for _tick in 60:
		await _wait(0.05)
		saw_hold = saw_hold or return_pass.is_holding()
		if return_pass.get_passes_done() > 0:
			break
	_expect(saw_hold, "evolved interceptor holds offscreen before returning")
	_expect(return_pass.get_passes_done() == 1, "evolved interceptor starts a return pass")
	var start_x := interceptor.global_position.x
	await _wait(0.5)
	_expect(is_instance_valid(interceptor) and interceptor.global_position.x < start_x, "return pass runs back")
	if is_instance_valid(interceptor):
		var shoot := interceptor.get_node("EnemyShootComponent") as EnemyShootComponent
		_expect(shoot.has_visible_pass_started(), "return pass reopens the fire window on entry")
	_clear_world()
	await process_frame


func _check_tanker() -> void:
	var configure := func(enemy: Enemy) -> void: enemy.set("shield_regen_delay", 0.2)
	var plain_enemy := await _spawn(TANKER_SCENE, _registry([]), Vector2(200, 100))
	var evolved_enemy := await _spawn(
		EVOLVE_TANKER.evolution_to, _registry([]), Vector2(400, 100), configure
	)
	var plain := plain_enemy as TankerEnemy
	var evolved := evolved_enemy as TankerEnemy
	var full := evolved.get_shield_health()
	plain.shield_stats.health -= 300
	evolved.shield_stats.health -= 300
	await _wait(0.1)
	_expect(evolved.get_shield_health() == full - 300, "shield waits out the regen delay")
	await _wait(0.6)
	_expect(evolved.get_shield_health() > full - 300, "evolved tanker shield regenerates")
	_expect(plain.get_shield_health() == full - 300, "plain tanker shield does not regenerate")
	await _wait(2.0)
	_expect(evolved.get_shield_health() == full, "regeneration stops at the full shield")
	evolved.shield_stats.health = 0
	await _wait(0.6)
	_expect(not evolved.is_shield_active() and evolved.get_shield_health() == 0, "a broken shield stays broken")
	_clear_world()
	await process_frame


func _check_caster() -> void:
	var caster := await _spawn(EVOLVE_CASTER.evolution_to, _registry([]))
	var shoot := caster.get_node("EnemyShootComponent") as EnemyShootComponent
	var first_angles: Array[float] = []
	var last_angles: Array[float] = []
	var ring_steps := 0
	for step in shoot._pattern.steps:
		if step.action != BarrageStep.Action.FIRE:
			continue
		var volleys := step.get_volleys()
		ring_steps += 1
		_expect(volleys.size() == 2, "each evolved caster beat fires two rings")
		var angles: Array[float] = []
		for volley in volleys:
			_expect(volley.layout == BarrageVolley.Layout.RING and volley.count == 12, "evolved rings hold 12 shots")
			angles.append(volley.angle_degrees)
		if ring_steps == 1:
			first_angles = angles
		last_angles = angles
	_expect(ring_steps == 5, "evolved caster fires five beats")
	if first_angles.size() == 2 and last_angles.size() == 2:
		_expect(
			last_angles[0] > first_angles[0] and last_angles[1] < first_angles[1],
			"the two rings spin in opposite directions",
		)
	_clear_world()
	await process_frame


func _check_sniper() -> void:
	var configure := func(enemy: Enemy) -> void:
		var attack := enemy.get_node("SniperAttackComponent") as SniperAttackComponent
		attack.follow_up_aim_duration = 0.2
	var plain := await _spawn(SNIPER_SCENE, _registry([]), Vector2(200, 48))
	var evolved := await _spawn(EVOLVE_SNIPER.evolution_to, _registry([]), Vector2(400, 48), configure)
	for enemy in [plain, evolved]:
		var attack := enemy.get_node("SniperAttackComponent") as SniperAttackComponent
		attack.set_combat_timings(0.2, 0.05, 3.0, 0.0)
	# A target moving right at 140px/s, smooth per frame so velocity reads cleanly.
	var target := Node2D.new()
	target.add_to_group("player")
	target.position = Vector2(150, 300)
	world.add_child(target)
	target.create_tween().tween_property(target, "position:x", 500.0, 2.5)
	var evolved_attack := evolved.get_node("SniperAttackComponent") as SniperAttackComponent
	var locked_directions: Array[Vector2] = []
	var target_x_at_lock := 0.0
	for _tick in 30:
		await _wait(0.05)
		if evolved_attack.is_follow_up_aiming():
			if locked_directions.is_empty():
				target_x_at_lock = target.position.x
			locked_directions.append(evolved_attack.get_follow_up_aim_direction())
	var plain_attack := plain.get_node("SniperAttackComponent") as SniperAttackComponent
	_expect(not locked_directions.is_empty(), "evolved sniper re-aims for a follow-up shot")
	if not locked_directions.is_empty():
		var locked := locked_directions[0]
		var steady := true
		for direction in locked_directions:
			steady = steady and direction.is_equal_approx(locked)
		_expect(steady, "the follow-up trap line stays locked while the target moves")
		var line_x := evolved.global_position.x + locked.x / locked.y * (300.0 - evolved.global_position.y)
		_expect(line_x > target_x_at_lock + 40.0, "the trap line lies ahead of the moving target")
	_expect(evolved_attack.get_shots_fired() == 2, "evolved sniper fires two shots per cycle")
	_expect(plain_attack.get_shots_fired() == 1, "plain sniper fires one shot per cycle")
	_clear_world()
	await process_frame


func _spawn(
	scene: PackedScene,
	registry: EnemyAugmentRegistry,
	position := Vector2(320, 80),
	configure := Callable(),
) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.spawn_id = &"enemy_evolution_test"
	enemy.position = position
	if configure.is_valid():
		configure.call(enemy)
	world.add_child(enemy)
	await process_frame
	return enemy


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _clear_world() -> void:
	# The world keeps its shared bullet renderer; later shots register with it.
	for child in world.get_children():
		if child.name != &"ProjectileBatchRenderer":
			child.queue_free()


func _registry(augments: Array) -> EnemyAugmentRegistry:
	var registry := EnemyAugmentRegistry.new()
	for augment in augments:
		registry.add_augment(augment)
	_registries.append(registry)
	return registry


func _free_registries() -> void:
	for registry in _registries:
		registry.free()
	_registries.clear()


func _bullet_count() -> int:
	return get_nodes_in_group(EnemyBullets.GROUP).size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
