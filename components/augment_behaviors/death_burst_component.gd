class_name DeathBurstComponent
extends Node

## Releases a slow ring of shots when an ordinary enemy is destroyed.

@export var barrage_shot: BarrageShot
@export_range(1, 32, 1) var shot_count := 4
## Ring start angle from world-down. 45 keeps every shot off the straight-down lane.
@export_range(0.0, 360.0, 1.0) var angle_degrees := 45.0
@export_range(1.0, 1000.0, 1.0) var projectile_speed := 60.0

var enemy: Enemy


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "DeathBurstComponent must be attached directly to an Enemy.")
	assert(barrage_shot != null and barrage_shot.is_valid(), "DeathBurstComponent requires a valid BarrageShot.")
	var stats := enemy.get_node("StatsComponent") as StatsComponent
	stats.no_health.connect(_on_no_health, CONNECT_ONE_SHOT)


func _on_no_health() -> void:
	# Elite and boss kills convert every enemy bullet into XP; a burst would
	# land after that cancel, so only ordinary enemies burst.
	if enemy.is_elite or enemy.is_boss:
		return
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null:
		world = get_tree().current_scene as Node2D
	if world == null:
		return
	var volley := BarrageVolley.new()
	volley.shot = BarrageSequence.clone_settings(barrage_shot) as BarrageShot
	volley.layout = BarrageVolley.Layout.RING
	volley.count = shot_count
	volley.angle_degrees = angle_degrees
	volley.speed = projectile_speed
	# Static so the burst survives the enemy's queue_free in the same frame.
	DeathBurstComponent._spawn_volley.call_deferred(weakref(world), enemy.global_position, volley)


static func _spawn_volley(world_ref: WeakRef, origin: Vector2, volley: BarrageVolley) -> void:
	var parent := world_ref.get_ref() as Node2D
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	for direction in volley.directions():
		volley.shot.spawn(parent, origin, direction, volley.speed)
