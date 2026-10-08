class_name BombCourierComponent
extends Node

## Carries one Bomb and leaves it behind as a stationary, already lit mine: as
## the courier passes beside the player, or wherever it is shot down first.

signal bomb_dropped(bomb: Enemy)

@export var actor: Enemy
@export var stats_component: StatsComponent
@export var movement_controller: MovementController
## Hidden once the bomb is released; the bomb drops from its position.
@export var carried_visual: Node2D
@export var bomb_scene: PackedScene
@export var mine_movement: MovementSequence
## Drop once the carried bomb comes down to this far above the player, which
## is where the arc passes beside them.
@export_range(0.0, 400.0, 1.0) var drop_height_above_player := 30.0
## Never drop above this distance below the top of the visible rect.
@export_range(0.0, 200.0, 1.0) var min_drop_depth := 40.0
## Drop line as a fraction of visible height when there is no player.
@export_range(0.0, 1.0, 0.01) var fallback_drop_ratio := 0.6
@export var steer_release_context_key: StringName = &"steer_released"

var _dropped := false


func _ready() -> void:
	assert(actor != null, "BombCourierComponent requires actor.")
	assert(stats_component != null, "BombCourierComponent requires StatsComponent.")
	assert(bomb_scene != null, "BombCourierComponent requires bomb_scene.")
	assert(mine_movement != null, "BombCourierComponent requires mine_movement.")
	# Connected before Enemy._ready() hooks no_health, so the drop is queued
	# while the courier is still in the tree.
	stats_component.no_health.connect(_drop_bomb)


func _process(_delta: float) -> void:
	if _dropped or not is_instance_valid(actor):
		return
	if _get_bomb_position().y >= get_drop_line_y():
		_drop_bomb()


func has_dropped() -> bool:
	return _dropped


func get_drop_line_y() -> float:
	var visible_rect := actor.get_viewport_rect()
	var line := visible_rect.position.y + visible_rect.size.y * fallback_drop_ratio
	var player := actor.get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		line = player.global_position.y - drop_height_above_player
	return maxf(line, visible_rect.position.y + min_drop_depth)


func _drop_bomb() -> void:
	if _dropped or not is_instance_valid(actor):
		return
	_dropped = true
	if carried_visual != null:
		carried_visual.visible = false
	if movement_controller != null:
		movement_controller.set_context_value(steer_release_context_key, true)
	var parent := actor.get_parent()
	if parent == null:
		return
	var bomb := _create_bomb()
	var drop_position := _get_bomb_position()
	if parent is Node2D:
		bomb.position = (parent as Node2D).to_local(drop_position)
	else:
		bomb.position = drop_position
	# no_health can fire inside a physics callback, and the courier may be freed
	# this frame, so defer on the parent rather than on this component.
	parent.add_child.call_deferred(bomb)
	bomb_dropped.emit(bomb)


func _get_bomb_position() -> Vector2:
	if carried_visual != null:
		return carried_visual.global_position
	return actor.global_position


func _create_bomb() -> Enemy:
	var registry := actor.augment_registry
	var scene := bomb_scene
	if registry != null:
		registry.note_enemy_scene_spawned(bomb_scene)
		scene = registry.resolve_enemy_scene(bomb_scene)
	var bomb := scene.instantiate() as Enemy
	assert(bomb != null, "BombCourierComponent bomb_scene root must be an Enemy.")
	# EnemyModifierFactory reads both in _ready(), so set them before add_child.
	bomb.augment_registry = registry
	bomb.spawn_id = actor.spawn_id
	bomb.set_movement_sequence(mine_movement)
	var fuse := bomb.get_node_or_null("BombProximityFuseComponent") as BombProximityFuseComponent
	if fuse != null:
		fuse.arm_on_ready = true
	return bomb
