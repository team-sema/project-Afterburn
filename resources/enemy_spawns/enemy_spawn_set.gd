class_name EnemySpawnSet
extends Resource

enum Pattern {
	SINGLE,
	DRONE_FORMATION,
	AWL_FORMATION,
}

@export var spawn_id: StringName
@export_range(1, 100, 1) var minimum_threat_level := 1
@export var enemy_scene: PackedScene
@export var pattern: Pattern = Pattern.SINGLE
@export var formation_offsets: Array[Vector2] = []


func is_available_at(threat_level: int) -> bool:
	return minimum_threat_level <= threat_level
