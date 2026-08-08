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
## Starts the fire window only after the actor center enters VisibleRect. Useful
## for one-pass encounters that must never attack from offscreen.
@export var activate_on_visible_entry := false
## Zero keeps firing indefinitely after activation.
@export_range(0.0, 20.0, 0.05, "suffix:s") var active_duration := 0.0

var enemy: Enemy
## When enabled, projectiles receive launch(direction, speed). When disabled,
## projectile scenes are spawned without directional configuration.
@export var inject_target_direction := true
## Overrides target aiming and launches along this actor-local forward axis.
@export var use_actor_forward_direction := false
@export var local_forward_direction := Vector2.DOWN
@export var targeting_component: TargetingComponent
var fire_timer: Timer
var _base_fire_interval := 2.0
var _base_burst_interval := 0.15
var _burst_volleys_remaining := 0
var _visible_pass_started := false
var _fire_window_active := false
var _active_elapsed := 0.0
var _volleys_fired := 0


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "EnemyShootComponent must be attached directly to an Enemy.")
	assert(projectile_scene != null, "EnemyShootComponent requires projectile_scene.")
	if inject_target_direction and not use_actor_forward_direction:
		assert(targeting_component != null, "Targeted EnemyShootComponent requires TargetingComponent.")
	if use_actor_forward_direction:
		assert(
			not local_forward_direction.is_zero_approx(),
			"Forward EnemyShootComponent requires a non-zero local forward direction.",
		)

	_base_fire_interval = fire_interval
	_base_burst_interval = burst_interval
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

	if activate_on_visible_entry:
		process_priority = 20
		set_process(true)
		return
	_fire_window_active = true
	_schedule_initial_burst()


func _process(delta: float) -> void:
	if not activate_on_visible_entry or enemy == null or not is_instance_valid(enemy):
		return
	if not _visible_pass_started:
		if enemy.get_viewport_rect().has_point(enemy.global_position):
			_visible_pass_started = true
			_fire_window_active = true
			_active_elapsed = 0.0
			_schedule_initial_burst()
		return
	if not _fire_window_active:
		return
	_active_elapsed += delta
	if active_duration > 0.0 and _active_elapsed >= active_duration:
		_fire_window_active = false
		_burst_volleys_remaining = 0
		fire_timer.stop()
		set_process(false)


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
	if activate_on_visible_entry and not _fire_window_active:
		return
	if _burst_volleys_remaining > 0:
		_fire_next_burst_volley()
	else:
		_start_burst()


func _start_burst() -> void:
	if activate_on_visible_entry and not _fire_window_active:
		return
	_burst_volleys_remaining = maxi(1, burst_count)
	_fire_next_burst_volley()


func _fire_next_burst_volley() -> void:
	if activate_on_visible_entry and not _fire_window_active:
		return
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
	if activate_on_visible_entry and not _fire_window_active:
		return
	if use_actor_forward_direction:
		var forward := local_forward_direction.normalized().rotated(enemy.global_rotation)
		_fire_projectiles(forward)
	elif inject_target_direction:
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
	_volleys_fired += 1

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


func has_visible_pass_started() -> bool:
	return _visible_pass_started


func is_fire_window_active() -> bool:
	return _fire_window_active


func get_volleys_fired() -> int:
	return _volleys_fired


func _schedule_initial_burst() -> void:
	if initial_delay > 0.0:
		fire_timer.start(initial_delay)
	else:
		_start_burst()
