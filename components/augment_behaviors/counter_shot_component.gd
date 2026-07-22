class_name CounterShotComponent
extends Node

enum Trigger {
	ON_HIT,
	ON_DEATH,
}

@export var trigger: Trigger = Trigger.ON_HIT
@export var projectile_scene: PackedScene
@export_range(1, 16, 1) var shot_count := 1
@export_range(0.0, 360.0, 1.0) var spread_degrees := 0.0
@export_range(1.0, 1000.0, 1.0) var projectile_speed := 40.0
@export_range(0.0, 10.0, 0.05) var cooldown := 0.25

var enemy: Enemy
var targeting_component: TargetingComponent
var cooldown_timer := Timer.new()


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "CounterShotComponent must be attached directly to an Enemy.")
	assert(projectile_scene != null, "CounterShotComponent must have a projectile scene set.")

	targeting_component = enemy.get_node_or_null("TargetingComponent") as TargetingComponent
	assert(targeting_component != null, "CounterShotComponent requires a TargetingComponent on its Enemy.")

	cooldown_timer.one_shot = true
	add_child(cooldown_timer)

	match trigger:
		Trigger.ON_HIT:
			var hurtbox := enemy.get_node("HurtboxComponent") as HurtboxComponent
			hurtbox.hurt.connect(_on_enemy_hurt)
		Trigger.ON_DEATH:
			var stats := enemy.get_node("StatsComponent") as StatsComponent
			stats.no_health.connect(_try_fire)


func _on_enemy_hurt(_hitbox: HitboxComponent) -> void:
	_try_fire()


func _try_fire() -> void:
	if not cooldown_timer.is_stopped():
		return

	var target := targeting_component.get_target()
	if target == null:
		return

	var target_direction := targeting_component.get_direction_from(enemy.global_position)
	if target_direction == Vector2.ZERO:
		return

	_fire_projectiles(target_direction)

	if cooldown > 0.0:
		cooldown_timer.start(cooldown)


func _fire_projectiles(target_direction: Vector2) -> void:
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		return

	for index in shot_count:
		var angle_offset := 0.0
		if shot_count > 1:
			var weight := float(index) / float(shot_count - 1)
			angle_offset = lerpf(-spread_degrees * 0.5, spread_degrees * 0.5, weight)

		var direction := target_direction.rotated(deg_to_rad(angle_offset))
		var projectile := projectile_scene.instantiate() as Node2D
		projectile.global_position = enemy.global_position

		if projectile.has_method("launch"):
			projectile_parent.add_child.call_deferred(projectile)
			projectile.call_deferred("launch", direction, projectile_speed)
		else:
			push_error("Counter-shot projectile must implement launch(direction, speed).")
			projectile.queue_free()
