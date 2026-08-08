class_name NearDeathExperienceComponent
extends Node

const USED_META := &"near_death_experience_used"

@export_range(0.1, 5.0, 0.1) var near_death_duration := 1.0

var enemy: Enemy
var stats_component: StatsComponent
var hurt_component: HurtComponent
var _triggered := false


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "NearDeathExperienceComponent must be attached to an Enemy.")
	stats_component = enemy.get_node("StatsComponent") as StatsComponent
	hurt_component = enemy.get_node("HurtComponent") as HurtComponent
	assert(stats_component != null, "NearDeathExperienceComponent requires StatsComponent.")
	assert(hurt_component != null, "NearDeathExperienceComponent requires HurtComponent.")
	stats_component.health_changed.connect(_on_health_changed)


func _on_health_changed() -> void:
	if _triggered or stats_component.health > 0:
		return
	if bool(enemy.get_meta(USED_META, false)):
		return
	_triggered = true
	enemy.set_meta(USED_META, true)
	stats_component.health = 1
	_disconnect_offscreen_free()
	hurt_component.invincibility_ended.connect(_finish_near_death, CONNECT_ONE_SHOT)
	hurt_component.start_invincibility(near_death_duration)


func _finish_near_death() -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	stats_component.health = 0


func _disconnect_offscreen_free() -> void:
	var notifier := enemy.get_node_or_null("VisibleOnScreenNotifier2D") as FreeOffscreenComponent
	if notifier == null:
		return
	if notifier.has_method("suspend_despawn"):
		notifier.suspend_despawn()
	var free_actor := Callable(enemy, "queue_free")
	if notifier.screen_exited.is_connected(free_actor):
		notifier.screen_exited.disconnect(free_actor)
