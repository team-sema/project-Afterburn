class_name EncounterRun
extends RefCounted

## Tracks every enemy produced by one spawned encounter until all of them have
## left the tree. Survives formation break (members are reparented, not freed).

signal completed

var controller: FormationController
var _active_enemy_ids: Dictionary = {}
var _member_spawns_finished := false
var _completed := false


static func track(formation_controller: FormationController) -> EncounterRun:
	var run := EncounterRun.new()
	run._attach(formation_controller)
	return run


func is_completed() -> bool:
	return _completed


func get_active_enemy_count() -> int:
	return _active_enemy_ids.size()


func _attach(formation_controller: FormationController) -> void:
	assert(formation_controller != null, "EncounterRun requires a FormationController.")
	controller = formation_controller
	controller.member_added.connect(_on_member_added)
	controller.member_spawns_finished.connect(_on_member_spawns_finished)
	for enemy in controller.get_members():
		_track_enemy(enemy)
	_member_spawns_finished = controller.are_member_spawns_finished()
	_try_complete()


func _on_member_added(enemy: Enemy, _slot_index: int) -> void:
	_track_enemy(enemy)


func _track_enemy(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var instance_id := enemy.get_instance_id()
	if _active_enemy_ids.has(instance_id):
		return
	_active_enemy_ids[instance_id] = true
	_watch_tree_exit(weakref(enemy), instance_id)


func _watch_tree_exit(enemy_reference: WeakRef, instance_id: int) -> void:
	var enemy: Enemy = enemy_reference.get_ref() as Enemy
	if enemy == null:
		return
	enemy.tree_exited.connect(
		_on_enemy_tree_exited.bind(enemy_reference, instance_id),
		CONNECT_ONE_SHOT,
	)


func _on_member_spawns_finished() -> void:
	_member_spawns_finished = true
	_try_complete.call_deferred()


func _on_enemy_tree_exited(enemy_reference: WeakRef, instance_id: int) -> void:
	_resolve_enemy_tree_exit.call_deferred(enemy_reference, instance_id)


func _resolve_enemy_tree_exit(enemy_reference: WeakRef, instance_id: int) -> void:
	# Formation release reparents the enemy: tree_exited fires but the enemy is
	# back in the tree by the next frame. Keep tracking in that case.
	var enemy: Enemy = enemy_reference.get_ref() as Enemy
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		_watch_tree_exit(enemy_reference, instance_id)
		return
	_active_enemy_ids.erase(instance_id)
	_try_complete()


func _try_complete() -> void:
	if _completed or not _member_spawns_finished or not _active_enemy_ids.is_empty():
		return
	_completed = true
	completed.emit()
