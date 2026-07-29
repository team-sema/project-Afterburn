class_name EnemyShootComponent
extends Node

## Periodic aimed fire used as the default enemy offense.

@export var projectile_scene: PackedScene
@export_range(0.2, 20.0, 0.05) var fire_interval := 2.0
@export_range(20.0, 400.0, 1.0) var projectile_speed := 100.0
@export_range(1, 12, 1) var shot_count := 1
@export_range(0.0, 90.0, 1.0) var spread_degrees := 0.0
@export_range(0.0, 5.0, 0.05) var initial_delay := 0.75

var enemy: Enemy
var targeting_component: TargetingComponent
var fire_timer: Timer
var _base_fire_interval := 2.0


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "EnemyShootComponent must be attached directly to an Enemy.")
	assert(projectile_scene != null, "EnemyShootComponent requires projectile_scene.")

	targeting_component = enemy.get_node_or_null("TargetingComponent") as TargetingComponent
	assert(targeting_component != null, "EnemyShootComponent requires TargetingComponent.")

	_base_fire_interval = fire_interval
	fire_timer = Timer.new()
	fire_timer.one_shot = false
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(fire)
	add_child(fire_timer)

	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay, false).timeout
		if not is_instance_valid(self) or not is_instance_valid(enemy):
			return
	fire()
	fire_timer.start()


func configure_baseline(interval: float, speed: float = -1.0) -> void:
	_base_fire_interval = interval
	fire_interval = interval
	if speed > 0.0:
		projectile_speed = speed
	if fire_timer != null:
		fire_timer.wait_time = fire_interval


func apply_action_rate_multiplier(multiplier: float) -> void:
	var rate := maxf(0.01, multiplier)
	fire_interval = _base_fire_interval / rate
	if fire_timer != null:
		fire_timer.wait_time = fire_interval


func fire() -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var target := targeting_component.get_target()
	if target == null:
		return
	var target_direction := targeting_component.get_direction_from(enemy.global_position)
	if target_direction == Vector2.ZERO:
		return
	_fire_projectiles(target_direction)


func _fire_projectiles(target_direction: Vector2) -> void:
	var projectile_parent := get_tree().get_first_node_in_group("gameplay_world")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	if projectile_parent == null:
		return

	var count := maxi(1, shot_count)
	for index in count:
		var angle_offset := 0.0
		if count > 1:
			var weight := float(index) / float(count - 1)
			angle_offset = lerpf(-spread_degrees * 0.5, spread_degrees * 0.5, weight)
		var direction := target_direction.rotated(deg_to_rad(angle_offset))
		var projectile := projectile_scene.instantiate() as Node2D
		projectile.global_position = enemy.global_position
		if projectile.has_method("launch"):
			projectile_parent.add_child.call_deferred(projectile)
			projectile.call_deferred("launch", direction, projectile_speed)
		else:
			push_error("EnemyShootComponent projectile must implement launch(direction, speed).")
			projectile.queue_free()
