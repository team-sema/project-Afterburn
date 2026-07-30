class_name RadialBarrageShootComponent
extends Node

## Periodic full-circle rings of projectiles ("뿅뿅뿅" multi-ring bursts).

@export var projectile_scene: PackedScene
@export_range(4, 48, 1) var pellets_per_ring := 20
@export_range(1, 12, 1) var ring_count := 5
@export_range(0.04, 1.0, 0.01) var ring_interval := 0.1
@export_range(0.5, 20.0, 0.05) var fire_interval := 2.4
@export_range(20.0, 400.0, 1.0) var projectile_speed := 95.0
@export_range(0.0, 45.0, 0.5) var spin_degrees_per_ring := 7.0
@export_range(0.0, 5.0, 0.05) var initial_delay := 1.0

var enemy: Enemy
var fire_timer: Timer
var _base_fire_interval := 2.4
var _base_ring_interval := 0.1
var _rings_remaining := 0
var _ring_spin_degrees := 0.0


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "RadialBarrageShootComponent must be attached to an Enemy.")
	assert(projectile_scene != null, "RadialBarrageShootComponent requires projectile_scene.")

	_base_fire_interval = fire_interval
	_base_ring_interval = ring_interval
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay, false).timeout
		if not is_instance_valid(self) or not is_instance_valid(enemy):
			return
	_start_barrage()


func apply_action_rate_multiplier(multiplier: float) -> void:
	var rate := maxf(0.01, multiplier)
	fire_interval = _base_fire_interval / rate
	ring_interval = _base_ring_interval / rate
	if fire_timer != null and _rings_remaining <= 0:
		fire_timer.wait_time = fire_interval


func _on_fire_timer_timeout() -> void:
	if _rings_remaining > 0:
		_fire_next_ring()
	else:
		_start_barrage()


func _start_barrage() -> void:
	_rings_remaining = maxi(1, ring_count)
	_ring_spin_degrees = 0.0
	_fire_next_ring()


func _fire_next_ring() -> void:
	_fire_ring(_ring_spin_degrees)
	_rings_remaining -= 1
	_ring_spin_degrees += spin_degrees_per_ring
	if _rings_remaining > 0:
		fire_timer.start(ring_interval)
	else:
		fire_timer.start(fire_interval)


func _fire_ring(spin_degrees: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var projectile_parent := get_tree().get_first_node_in_group("gameplay_world")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	if projectile_parent == null:
		return

	var count := maxi(1, pellets_per_ring)
	for index in count:
		var angle := TAU * (float(index) / float(count)) + deg_to_rad(spin_degrees)
		var direction := Vector2(cos(angle), sin(angle))
		var projectile := projectile_scene.instantiate() as Node2D
		projectile.global_position = enemy.global_position
		if not projectile.has_method("launch"):
			push_error("RadialBarrage projectile must implement launch(direction, speed).")
			projectile.queue_free()
			continue
		projectile_parent.add_child.call_deferred(projectile)
		projectile.call_deferred("launch", direction, projectile_speed)
