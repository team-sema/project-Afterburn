class_name EnemySpawnPattern
extends Resource


func spawn(
	_enemy_scene: PackedScene,
	_viewport_rect: Rect2,
	_spawn_enemy: Callable,
) -> void:
	assert(false, "EnemySpawnPattern subclasses must implement spawn().")


func validate() -> void:
	pass
