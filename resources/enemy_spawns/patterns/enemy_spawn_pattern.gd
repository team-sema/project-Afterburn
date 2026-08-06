class_name EnemySpawnPattern
extends Resource


func spawn(
	_enemy_scene: PackedScene,
	_viewport_rect: Rect2,
	_spawn_enemy: Callable,
	_additional_count: int = 0,
) -> void:
	assert(false, "EnemySpawnPattern subclasses must implement spawn().")


func validate() -> void:
	pass
