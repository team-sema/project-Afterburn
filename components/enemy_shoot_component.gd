class_name EnemyShootComponent
extends Node

## Periodic aimed fire used as the default enemy offense.

@export var projectile_scene: PackedScene
## Delay from the end of one burst to the start of the next burst.
@export_range(0.2, 20.0, 0.05) var fire_interval := 2.0
## Number of aimed volleys fired in one burst. One preserves the original behavior.
@export_range(1, 12, 1) var burst_count := 1
## Delay between volleys within a burst.
@export_range(0.05, 2.0, 0.05) var burst_interval := 0.15
@export_range(20.0, 400.0, 1.0) var projectile_speed := 100.0
@export_range(1, 12, 1) var shot_count := 1
@export_range(0.0, 90.0, 1.0) var spread_degrees := 0.0
@export_range(0.0, 5.0, 0.05) var initial_delay := 0.75

var enemy: Enemy
## When enabled, projectiles receive launch(direction, speed). When disabled,
## projectile scenes are spawned without directional configuration.
@export var inject_target_direction := true
@export var targeting_component: TargetingComponent
var fire_timer: Timer
var _base_fire_interval := 2.0
var _base_burst_interval := 0.15
var _burst_volleys_remaining := 0


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "EnemyShootComponent must be attached directly to an Enemy.")
	assert(projectile_scene != null, "EnemyShootComponent requires projectile_scene.")
	if inject_target_direction:
		assert(targeting_component != null, "Targeted EnemyShootComponent requires TargetingComponent.")

	_base_fire_interval = fire_interval
	_base_burst_interval = burst_interval
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay, false).timeout
		if not is_instance_valid(self) or not is_instance_valid(enemy):
			return
	_start_burst()


func configure_baseline(interval: float, speed: float = -1.0) -> void:
	_base_fire_interval = interval
	fire_interval = interval
	if speed > 0.0:
		projectile_speed = speed
	if fire_timer != null:
		fire_timer.wait_time = _get_next_fire_delay()


func apply_action_rate_multiplier(multiplier: float) -> void:
	var rate := maxf(0.01, multiplier)
	fire_interval = _base_fire_interval / rate
	burst_interval = _base_burst_interval / rate
	if fire_timer != null:
		fire_timer.wait_time = _get_next_fire_delay()


func _on_fire_timer_timeout() -> void:
	if _burst_volleys_remaining > 0:
		_fire_next_burst_volley()
	else:
		_start_burst()


func _start_burst() -> void:
	_burst_volleys_remaining = maxi(1, burst_count)
	_fire_next_burst_volley()


func _fire_next_burst_volley() -> void:
	fire()
	_burst_volleys_remaining -= 1
	fire_timer.start(_get_next_fire_delay())


func _get_next_fire_delay() -> float:
	if _burst_volleys_remaining > 0:
		return burst_interval
	return fire_interval


func fire() -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if inject_target_direction:
		if targeting_component == null:
			push_error("Targeted EnemyShootComponent requires TargetingComponent.")
			return
		var target := targeting_component.get_target()
		if target == null:
			return
		var target_direction := targeting_component.get_direction_from(enemy.global_position)
		if target_direction == Vector2.ZERO:
			return
		_fire_projectiles(target_direction)
	else:
		_fire_projectiles()


func _fire_projectiles(target_direction: Variant = null) -> void:
	var projectile_parent := get_tree().get_first_node_in_group("gameplay_world")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	if projectile_parent == null:
		return

	var count := maxi(1, shot_count)
	for index in count:
		var projectile := projectile_scene.instantiate() as Node2D
		projectile.global_position = enemy.global_position

		if target_direction != null and not projectile.has_method("launch"):
			push_error("EnemyShootComponent projectile must implement launch(direction, speed).")
			projectile.queue_free()
			continue

		projectile_parent.add_child.call_deferred(projectile)
		if target_direction != null:
			var direction: Vector2 = target_direction
			if count > 1:
				var weight := float(index) / float(count - 1)
				var angle_offset := lerpf(
					-spread_degrees * 0.5,
					spread_degrees * 0.5,
					weight,
				)
				direction = direction.rotated(deg_to_rad(angle_offset))
			projectile.call_deferred("launch", direction, projectile_speed)
