class_name EnemySpawnSet
extends Resource

@export var spawn_id: StringName
@export_range(1, 100, 1) var minimum_threat_level := 1
@export var enemy_scene: PackedScene
@export var spawn_pattern: EnemySpawnPattern


func is_available_at(threat_level: int) -> bool:
	return minimum_threat_level <= threat_level


func spawn(viewport_rect: Rect2, spawn_enemy: Callable) -> void:
	assert(spawn_pattern != null, "EnemySpawnSet requires an EnemySpawnPattern.")
	spawn_pattern.spawn(enemy_scene, viewport_rect, spawn_enemy)


func validate() -> void:
	assert(enemy_scene != null, "EnemySpawnSet requires an enemy scene.")
	assert(spawn_pattern != null, "EnemySpawnSet requires an EnemySpawnPattern.")
	spawn_pattern.validate()
