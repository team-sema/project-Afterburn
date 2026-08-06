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

	var health_multiplier := 1.0
	var move_speed_multiplier := 1.0
	var action_rate_multiplier := 1.0
	var arming_rate_multiplier := 1.0
	var behavior_components := local_behavior_components.duplicate()

	for modifier in local_stat_modifiers:
		match modifier.stat:
			EnemyStatModifier.Stat.HEALTH:
				health_multiplier *= modifier.multiplier
			EnemyStatModifier.Stat.MOVE_SPEED:
				move_speed_multiplier *= modifier.multiplier
			EnemyStatModifier.Stat.ACTION_RATE:
				action_rate_multiplier *= modifier.multiplier
			EnemyStatModifier.Stat.ARMING_RATE:
				arming_rate_multiplier *= modifier.multiplier

	for augment in augment_registry.get_active_augments():
		if augment.target_spawn_id != &"" and augment.target_spawn_id != enemy.spawn_id:
			continue
		for modifier in augment.stat_modifiers:
			match modifier.stat:
				EnemyStatModifier.Stat.HEALTH:
					health_multiplier *= modifier.multiplier
				EnemyStatModifier.Stat.MOVE_SPEED:
					move_speed_multiplier *= modifier.multiplier
				EnemyStatModifier.Stat.ACTION_RATE:
					action_rate_multiplier *= modifier.multiplier
				EnemyStatModifier.Stat.ARMING_RATE:
					arming_rate_multiplier *= modifier.multiplier
		behavior_components.append_array(augment.behavior_components)

	_apply_health_multiplier(enemy, health_multiplier)
	_apply_move_speed_multiplier(enemy, move_speed_multiplier)
	_apply_action_rate_multiplier(enemy, action_rate_multiplier)
	_apply_arming_rate_multiplier(enemy, arming_rate_multiplier)
	_attach_behavior_components(enemy, behavior_components)


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
	var shoot := enemy.get_node_or_null("EnemyShootComponent") as EnemyShootComponent
	if shoot != null:
		shoot.apply_action_rate_multiplier(multiplier)
	var radial := enemy.get_node_or_null("RadialBarrageShootComponent")
	if radial != null and radial.has_method("apply_action_rate_multiplier"):
		radial.call("apply_action_rate_multiplier", multiplier)


func _apply_arming_rate_multiplier(enemy: Enemy, multiplier: float) -> void:
	var bomb_fuse := enemy.get_node_or_null("BombProximityFuseComponent")
	if bomb_fuse != null and bomb_fuse.has_method("apply_arming_rate_multiplier"):
		bomb_fuse.call("apply_arming_rate_multiplier", multiplier)


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
