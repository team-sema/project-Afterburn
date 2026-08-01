class_name SingleEnemySpawnPattern
extends EnemySpawnPattern

@export_range(0.0, 128.0, 1.0) var edge_margin := 8.0
@export_range(-256.0, 0.0, 1.0) var spawn_y_offset := -16.0


func spawn(
	enemy_scene: PackedScene,
	viewport_rect: Rect2,
	spawn_enemy: Callable,
) -> void:
	var min_x := viewport_rect.position.x + edge_margin
	var max_x := maxf(min_x, viewport_rect.end.x - edge_margin)
	var spawn_position := Vector2(
		randf_range(min_x, max_x),
		viewport_rect.position.y + spawn_y_offset,
	)
	spawn_enemy.call(enemy_scene, spawn_position, Callable())
