extends SceneTree

const NEAR_DEATH := preload("res://resources/enemy_augments/enemy_near_death_experience.tres")
const DRONE_REINFORCEMENT := preload(
	"res://resources/enemy_augments/enemy_drone_formation_reinforcement.tres"
)
const HEALTH_BOOST := preload("res://resources/enemy_augments/enemy_health_boost_1_2.tres")
const MOVE_BOOST := preload("res://resources/enemy_augments/enemy_move_speed_boost_1_2.tres")
const FIRE_BOOST := preload("res://resources/enemy_augments/enemy_fire_volume_boost.tres")
const BOMB_FAST_FUSE := preload("res://resources/enemy_augments/enemy_bomb_fast_fuse.tres")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	var gameplay_offer := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	_expect(
		gameplay_offer.enemy_augment_pool.has(DRONE_REINFORCEMENT),
		"drone reinforcement is registered in the gameplay offer pool",
	)
	_expect(
		gameplay_offer.enemy_augment_pool.has(BOMB_FAST_FUSE),
		"bomb fast fuse is registered in the gameplay offer pool",
	)
	gameplay.free()

	var registry := EnemyAugmentRegistry.new()
	_expect(NEAR_DEATH.max_stacks == 1, "near-death is configured as one-time")
	_expect(registry.can_add_augment(NEAR_DEATH), "one-time augment starts available")
	registry.add_augment(NEAR_DEATH)
	registry.add_augment(NEAR_DEATH)
	_expect(registry.get_stack_count(NEAR_DEATH.augment_id) == 1, "registry enforces max stacks")
	_expect(not registry.can_add_augment(NEAR_DEATH), "one-time augment becomes unavailable")

	var offer := AugmentOfferController.new()
	offer.enemy_registry = registry
	offer.choices_per_offer = 3
	offer.enemy_augment_pool = [
		NEAR_DEATH,
		DRONE_REINFORCEMENT,
		HEALTH_BOOST,
		MOVE_BOOST,
		FIRE_BOOST,
		BOMB_FAST_FUSE,
	]
	var choices := offer._pick_enemy_choices()
	_expect(choices.size() == 3, "enemy offer still returns three available choices")
	_expect(not choices.has(NEAR_DEATH), "capped augment is excluded from enemy offers")
	offer.free()

	registry.add_augment(DRONE_REINFORCEMENT)
	_expect(
		registry.get_additional_spawn_count(&"drone_formation") == 1,
		"drone reinforcement adds one member to its target spawn set",
	)
	_expect(
		registry.get_additional_spawn_count(&"awl_formation") == 0,
		"spawn bonus does not affect other enemy groups",
	)
	_expect(DRONE_REINFORCEMENT.icon != null, "drone reinforcement references an SVG icon")
	_expect(BOMB_FAST_FUSE.max_stacks == 1, "bomb fast fuse is configured as one-time")
	_expect(BOMB_FAST_FUSE.target_spawn_id == &"bomb", "fast fuse targets only bomb spawns")
	_expect(BOMB_FAST_FUSE.icon != null, "bomb fast fuse references the Bomb SVG icon")
	_expect(
		BOMB_FAST_FUSE.stat_modifiers[0].stat == EnemyStatModifier.Stat.ARMING_RATE,
		"bomb fast fuse uses the isolated arming-rate stat",
	)
	var action_rate_modifier := EnemyStatModifier.new()
	action_rate_modifier.stat = EnemyStatModifier.Stat.ACTION_RATE
	action_rate_modifier.multiplier = 1.25
	var action_rate_augment := EnemyAugment.new()
	action_rate_augment.augment_id = &"test_action_rate_only"
	action_rate_augment.stat_modifiers = [action_rate_modifier]
	var action_only_registry := EnemyAugmentRegistry.new()
	action_only_registry.add_augment(action_rate_augment)
	var action_only_bomb := (
		load("res://enemies/bomb_enemy.tscn") as PackedScene
	).instantiate() as Enemy
	action_only_bomb.augment_registry = action_only_registry
	action_only_bomb.spawn_id = &"bomb"
	root.add_child(action_only_bomb)
	await process_frame
	var action_only_fuse := action_only_bomb.get_node("BombProximityFuseComponent")
	_expect(
		is_equal_approx(float(action_only_fuse.get("arm_duration")), 2.0),
		"general action rate does not accelerate the Bomb fuse",
	)
	action_only_bomb.queue_free()
	await process_frame
	action_only_registry.free()

	var overlay := (
		load("res://menus/augment_selection_overlay.tscn") as PackedScene
	).instantiate() as AugmentSelectionOverlay
	root.add_child(overlay)
	await process_frame
	overlay._set_choices([DRONE_REINFORCEMENT])
	var first_button := overlay.choice_buttons[0]
	_expect(first_button.icon == DRONE_REINFORCEMENT.icon, "enemy SVG appears on its offer card")
	_expect(
		first_button.get_theme_constant("icon_max_width") == 48,
		"enemy offer uses the temporary larger SVG preview size",
	)
	overlay.queue_free()
	await process_frame
	registry.free()

	if failures.is_empty():
		print("enemy_augment_policy_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_augment_policy_smoke_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
