class_name EnemyModifierFactory
extends Node

@export var local_stat_modifiers: Array[EnemyStatModifier] = []
@export var local_behavior_components: Array[PackedScene] = []


func _ready() -> void:
	var enemy := _find_enemy_ancestor()
	assert(enemy != null, "EnemyModifierFactory must be placed under an Enemy node.")
	apply_spawn_modifiers(enemy)


func apply_spawn_modifiers(enemy: Enemy) -> void:
	var augment_registry := enemy.augment_registry
	assert(augment_registry != null, "Enemy requires an injected EnemyAugmentRegistry.")

	var multipliers := {}
	var behavior_components := local_behavior_components.duplicate()
	_accumulate_multipliers(multipliers, local_stat_modifiers)

	for augment in augment_registry.get_active_augments():
		if augment.target_spawn_id != &"" and augment.target_spawn_id != enemy.spawn_id:
			continue
		_accumulate_multipliers(multipliers, augment.stat_modifiers)
		behavior_components.append_array(augment.behavior_components)

	_apply_health_multiplier(enemy, _get_multiplier(multipliers, EnemyStatModifier.Stat.HEALTH))
	_apply_move_speed_multiplier(enemy, _get_multiplier(multipliers, EnemyStatModifier.Stat.MOVE_SPEED))
	_apply_action_rate_multiplier(enemy, _get_multiplier(multipliers, EnemyStatModifier.Stat.ACTION_RATE))
	_apply_arming_rate_multiplier(enemy, _get_multiplier(multipliers, EnemyStatModifier.Stat.ARMING_RATE))
	# Elite and boss patterns mix launch speeds with absolute speed_to targets,
	# so only ordinary enemies take the projectile speed multiplier.
	if not (enemy.is_elite or enemy.is_boss):
		_apply_projectile_speed_multiplier(
			enemy,
			_get_multiplier(multipliers, EnemyStatModifier.Stat.PROJECTILE_SPEED),
		)
	_apply_experience_drop_multipliers(
		enemy,
		_get_multiplier(multipliers, EnemyStatModifier.Stat.XP_DRIFT_SPEED),
		_get_multiplier(multipliers, EnemyStatModifier.Stat.XP_DROP_CHANCE),
	)
	_attach_behavior_components(enemy, behavior_components)


func _accumulate_multipliers(multipliers: Dictionary, modifiers: Array[EnemyStatModifier]) -> void:
	for modifier in modifiers:
		multipliers[modifier.stat] = _get_multiplier(multipliers, modifier.stat) * modifier.multiplier


func _get_multiplier(multipliers: Dictionary, stat: EnemyStatModifier.Stat) -> float:
	return float(multipliers.get(stat, 1.0))


func _apply_health_multiplier(enemy: Enemy, multiplier: float) -> void:
	for node in enemy.find_children("*", "", true, false):
		if node is StatsComponent:
			var stats_component := node as StatsComponent
			stats_component.health = maxi(1, roundi(stats_component.health * multiplier))
			return


func _apply_move_speed_multiplier(enemy: Enemy, multiplier: float) -> void:
	for node in enemy.find_children("*", "", true, false):
		if node is MoveComponent:
			var move_component := node as MoveComponent
			move_component.velocity_multiplier *= multiplier


func _apply_action_rate_multiplier(enemy: Enemy, multiplier: float) -> void:
	for node in enemy.find_children("*", "", true, false):
		if node is TimedStateComponent:
			var timed_state := node as TimedStateComponent
			timed_state.duration /= multiplier
	# Shoot component may not have finished _ready yet.
	call_deferred("_apply_shoot_action_rate", enemy, multiplier)


func _apply_shoot_action_rate(enemy: Enemy, multiplier: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	for node in enemy.find_children("*", "", true, false):
		if node is EnemyShootComponent:
			(node as EnemyShootComponent).apply_action_rate_multiplier(multiplier)
	var sniper := enemy.get_node_or_null("SniperAttackComponent")
	if sniper != null and sniper.has_method("apply_action_rate_multiplier"):
		sniper.call("apply_action_rate_multiplier", multiplier)


func _apply_arming_rate_multiplier(enemy: Enemy, multiplier: float) -> void:
	var bomb_fuse := enemy.get_node_or_null("BombProximityFuseComponent")
	if bomb_fuse != null and bomb_fuse.has_method("apply_arming_rate_multiplier"):
		bomb_fuse.call("apply_arming_rate_multiplier", multiplier)
	var shoot := enemy.get_node_or_null("EnemyShootComponent")
	if shoot != null and shoot.has_method("apply_arming_rate_multiplier"):
		shoot.call("apply_arming_rate_multiplier", multiplier)


func _apply_projectile_speed_multiplier(enemy: Enemy, multiplier: float) -> void:
	if is_equal_approx(multiplier, 1.0):
		return
	for node in enemy.find_children("*", "", true, false):
		if node is EnemyShootComponent:
			(node as EnemyShootComponent).apply_projectile_speed_multiplier(multiplier)
	var sniper := enemy.get_node_or_null("SniperAttackComponent")
	if sniper != null and sniper.has_method("apply_projectile_speed_multiplier"):
		sniper.call("apply_projectile_speed_multiplier", multiplier)


func _apply_experience_drop_multipliers(
	enemy: Enemy,
	drift_speed_multiplier: float,
	drop_chance_multiplier: float,
) -> void:
	for node in enemy.find_children("*", "", true, false):
		if node is ExperienceDropComponent:
			var drop := node as ExperienceDropComponent
			drop.drift_speed_multiplier *= drift_speed_multiplier
			# Guaranteed drops (elite rewards) stay guaranteed.
			if drop.drop_chance < 1.0:
				drop.drop_chance *= drop_chance_multiplier


func _attach_behavior_components(enemy: Enemy, behavior_components: Array[PackedScene]) -> void:
	for component_scene in behavior_components:
		if component_scene == null:
			continue
		enemy.add_child.call_deferred(component_scene.instantiate())


func _find_enemy_ancestor() -> Enemy:
	var current := get_parent()

	while current != null:
		if current is Enemy:
			return current as Enemy
		current = current.get_parent()

	return null
