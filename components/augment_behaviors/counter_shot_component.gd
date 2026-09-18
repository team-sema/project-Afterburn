class_name CounterShotComponent
extends Node

enum Trigger {
	ON_HIT,
	ON_DEATH,
}

@export var trigger: Trigger = Trigger.ON_HIT
@export var barrage_shot: BarrageShot
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
	assert(barrage_shot != null and barrage_shot.is_valid(), "CounterShotComponent requires a valid BarrageShot.")

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
	if not is_instance_valid(target):
		return
	# Transformed parents can leave a tiny rounding delta at the same position.
	if enemy.global_position.distance_squared_to(target.global_position) < 0.0001:
		return

	var target_direction := targeting_component.get_direction_from(enemy.global_position)
	if target_direction == Vector2.ZERO:
		return

	_fire_projectiles(target_direction)

	if cooldown > 0.0:
		cooldown_timer.start(cooldown)


func _fire_projectiles(target_direction: Vector2) -> void:
	var projectile_parent := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene as Node2D
	if projectile_parent == null:
		return
	var volley := BarrageVolley.new()
	volley.shot = BarrageSequence.clone_settings(barrage_shot) as BarrageShot
	volley.layout = BarrageVolley.Layout.FAN
	volley.count = shot_count
	volley.spread_degrees = spread_degrees
	volley.speed = projectile_speed
	volley.angle_degrees = rad_to_deg(Vector2.DOWN.angle_to(target_direction))
	# A static callback survives emitter deletion (including ON_DEATH), but is
	# scoped to the captured world. No live target/emitter is read after deferral.
	CounterShotComponent._spawn_volley.call_deferred(weakref(projectile_parent), enemy.global_position, volley)


static func _spawn_volley(world_ref: WeakRef, origin: Vector2, volley: BarrageVolley) -> void:
	var parent := world_ref.get_ref() as Node2D
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	for direction in volley.directions():
		volley.shot.spawn(parent, origin, direction, volley.speed)
