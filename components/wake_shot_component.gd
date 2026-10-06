class_name WakeShotComponent
extends Node

## Evolved Striker: once released from its formation, drops a pair of slow shots
## to both sides of its travel direction at a fixed interval.

@export var barrage_shot: BarrageShot
@export_range(0.05, 5.0, 0.05, "suffix:s") var interval := 0.45
@export_range(1.0, 1000.0, 1.0, "suffix:px/s") var projectile_speed := 55.0
## Shares the ordinary-enemy lower-screen safety line.
@export var apply_shot_threshold := true

var enemy: Enemy
var _last_position := Vector2.ZERO
var _elapsed := 0.0
var _shots_fired := 0


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "WakeShotComponent must be attached directly to an Enemy.")
	assert(barrage_shot != null and barrage_shot.is_valid(), "WakeShotComponent requires a valid BarrageShot.")
	_last_position = enemy.global_position


func get_shots_fired() -> int:
	return _shots_fired


func _process(delta: float) -> void:
	var motion := enemy.global_position - _last_position
	_last_position = enemy.global_position
	if enemy.is_formation_member():
		_elapsed = 0.0
		return
	_elapsed += delta
	if _elapsed < interval:
		return
	_elapsed -= interval
	if motion.length_squared() < 0.0001 or _is_below_shot_threshold():
		return
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null:
		world = get_tree().current_scene as Node2D
	if world == null:
		return
	var side := motion.normalized().orthogonal()
	barrage_shot.spawn(world, enemy.global_position, side, projectile_speed)
	barrage_shot.spawn(world, enemy.global_position, -side, projectile_speed)
	_shots_fired += 2


func _is_below_shot_threshold() -> bool:
	if not apply_shot_threshold or enemy.augment_registry == null:
		return false
	var visible_rect := enemy.get_viewport_rect()
	var threshold_y := (
		visible_rect.position.y
		+ visible_rect.size.y * enemy.augment_registry.shot_threshold_y_ratio
	)
	return enemy.global_position.y > threshold_y
