extends SceneTree

var failures := PackedStringArray()
var seen := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(320, 280)
	world.add_child(player)
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	var elite := (load("res://enemies/elite_caster.tscn") as PackedScene).instantiate() as Enemy
	elite.augment_registry = registry
	elite.position = Vector2(320, -30)
	world.add_child(elite)
	await process_frame
	var attack = elite.get_node("EnemyShootComponent")
	attack.set_process(false)
	_expect(elite.is_elite, "elite caster is marked elite")
	_expect(elite.movement_controller.sequence.resource_path.ends_with("elite_caster_hover.tres"), "caster hovers slowly")
	attack._process(1.0)
	_expect(attack.get_volleys_fired() == 0, "entry does not shoot")
	elite.position.y = 80
	elite.movement_controller.update_movement(0.1)
	attack._process(0.01)
	_expect(attack.phase == attack.Phase.READY, "hover begins the ready delay")
	attack._process(0.6)
	_expect(attack.phase == attack.Phase.SPELL and attack.spell == attack.Spell.BREATHING_RINGS, "first spell is breathing rings")
	_expect(attack.reference_direction.is_equal_approx(Vector2.DOWN), "spell locks the player direction")

	# 1. Breathing rings
	for i in 4:
		attack._process(0.46)
	await process_frame
	var rings := _new_bullets()
	_expect(rings.size() == 100, "breathing rings fire five rings of twenty")
	if rings.size() == 100:
		_expect_lane(rings.slice(0, 20), 0.0, 20.0, "first ring leaves a forty-degree lane")
		_expect_lane(rings.slice(80, 100), 36.0, 20.0, "lane turns nine degrees per ring")
		var first: BulletBehaviorState = rings[0].behavior_state
		var last: BulletBehaviorState = rings[99].behavior_state
		_expect(absf(first.velocity_at(2.85).length() - 25.0) < 1.0 and absf(last.velocity_at(1.05).length() - 25.0) < 1.0, "rings wait at the braking speed")
		_expect(first.velocity_at(3.3).length() > 40.0 and last.velocity_at(1.5).length() > 40.0, "all rings re-accelerate at the same moment")
	_expect(attack.phase == attack.Phase.REST and attack.spell == attack.Spell.PETAL_LATTICE, "rest follows the first spell")
	attack._process(1.39)
	_expect(attack.phase == attack.Phase.REST, "rest lasts 1.4s")

	# 2. Petal lattice
	attack._process(0.02)
	for i in 3:
		attack._process(0.71)
	await process_frame
	var petals := _new_bullets()
	_expect(petals.size() == 96, "petal lattice fires four double rings")
	if petals.size() == 96:
		var pink: BulletBehaviorState = petals[0].behavior_state
		var violet: BulletBehaviorState = petals[12].behavior_state
		_expect(absf(rad_to_deg(pink.velocity_at(0.0).angle_to(pink.velocity_at(1.8))) - 100.0) < 1.0, "pink petals bend +100 degrees")
		_expect(absf(rad_to_deg(violet.velocity_at(0.0).angle_to(violet.velocity_at(1.8))) + 100.0) < 1.0, "violet petals bend -100 degrees")
		_expect(pink.velocity_at(0.0).normalized().is_equal_approx(violet.velocity_at(0.0).normalized()), "both rings leave together")

	# 3. Halt and aim
	attack._process(1.41)
	attack._process(1.01)
	await process_frame
	var knives := _new_bullets()
	_expect(knives.size() == 32, "halt and aim fires two rings of sixteen")
	_expect(attack.cycle == 1 and attack.spell == attack.Spell.BREATHING_RINGS, "cycle wraps after the third spell")
	_expect(is_equal_approx(attack.get_lane_spin(), -9.0), "next cycle turns the lane the other way")
	if knives.size() == 32:
		var knife = knives[3]
		var start_tint: Color = knife.render_tint
		_advance(knife, 0.75)
		_expect(knife.get_travel_velocity().length() < 1.0, "needles halt")
		_expect(knife.appearance.collision_size == Vector2(6, 12), "halt needles use the 1.5x elite needle")
		_expect(knife.render_tint.g < 0.5 and start_tint.g > 0.5, "halted needles turn red")
		var aimed := 0
		for bullet in knives.slice(0, 16):
			_advance(bullet, 1.6)
			var to_player: Vector2 = (player.global_position - bullet.global_position).normalized()
			if bullet.get_travel_velocity().normalized().dot(to_player) > 0.95: aimed += 1
		_expect(aimed == 16, "needles snap toward the player")

	# Action rate, rest floor and volume augment
	attack.apply_action_rate_multiplier(10.0)
	attack.shot_count += 2
	attack._remaining = 0.0
	attack._process(0.01)
	for i in 4:
		attack._process(0.31)
	await process_frame
	_expect(_new_bullets().size() == 100, "volume augment leaves breathing rings unchanged")
	_expect(attack.phase == attack.Phase.REST, "action rate is capped at 1.5x")
	_expect(is_equal_approx(attack._remaining, 0.8), "action rate keeps the minimum rest")
	attack.spell = attack.Spell.HALT_AND_AIM
	attack._remaining = 0.0
	attack._process(0.01)
	await process_frame
	_expect(_new_bullets().size() == 18, "volume augment adds needles")
	elite.stats_component.health = 0
	attack._process(0.1)
	_expect(not attack.barrage_player.running, "death stops future fire")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("elite caster smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_bullets() -> Array:
	var result := []
	for bullet in get_nodes_in_group("enemy_projectiles"):
		if not seen.has(bullet):
			seen[bullet] = true
			result.append(bullet)
	return result


func _advance(bullet: Node, age: float) -> void:
	while bullet.age < age - 0.0001:
		bullet._physics_process(minf(1.0 / 60.0, age - bullet.age))


## The nearest bullets on both sides sit half the lane width from its centre.
func _expect_lane(ring: Array, lane_degrees: float, half_width: float, message: String) -> void:
	var lane := Vector2.DOWN.rotated(deg_to_rad(lane_degrees))
	var left := 999.0
	var right := 999.0
	for bullet in ring:
		var angle := rad_to_deg(lane.angle_to((bullet.get_travel_velocity() as Vector2)))
		if angle >= 0.0: right = minf(right, angle)
		else: left = minf(left, -angle)
	_expect(absf(left - half_width) < 0.5 and absf(right - half_width) < 0.5, message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
