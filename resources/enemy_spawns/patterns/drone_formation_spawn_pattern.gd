class_name DroneFormationSpawnPattern
extends EnemySpawnPattern

const NORMAL_ENEMY_SCRIPT: Script = preload("res://enemies/normal_enemy.gd")

@export var formation_offsets: Array[Vector2] = []
@export_range(0.0, 128.0, 1.0) var edge_margin := 8.0
@export_range(-256.0, 0.0, 1.0) var spawn_y_offset := -16.0
@export_range(0.0, 400.0, 1.0) var forward_speed := 72.0
@export_range(0.0, 80.0, 0.5) var dive_angle_degrees := 50.0


func spawn(
	enemy_scene: PackedScene,
	viewport_rect: Rect2,
	spawn_enemy: Callable,
) -> void:
	var half_span := _get_half_span()
	var min_x := viewport_rect.position.x + edge_margin + half_span
	var max_x := maxf(min_x, viewport_rect.end.x - edge_margin - half_span)
	var formation_origin := Vector2(
		randf_range(min_x, max_x),
		viewport_rect.position.y + spawn_y_offset,
	)
	var lateral_sign := 1.0 if formation_origin.x <= (min_x + max_x) * 0.5 else -1.0
	var movement_settings := {
		"forward_speed": forward_speed,
		"dive_angle_degrees": dive_angle_degrees * lateral_sign,
		"half_span": half_span,
		"edge_margin": edge_margin,
	}

	for offset in formation_offsets:
		var formation_offset := offset as Vector2
		spawn_enemy.call(
			enemy_scene,
			formation_origin + formation_offset,
			func(enemy: Node) -> void:
				assert(
					enemy.get_script() == NORMAL_ENEMY_SCRIPT,
					"Drone formation requires normal_enemy.gd.",
				)
				assert(enemy.has_method("setup_formation"), "Drone missing setup_formation.")
				enemy.call("setup_formation", formation_origin, formation_offset, movement_settings),
		)


func validate() -> void:
	assert(not formation_offsets.is_empty(), "Drone formation requires at least one offset.")


func _get_half_span() -> float:
	var half_span := 0.0
	for offset in formation_offsets:
		half_span = maxf(half_span, absf(offset.x))
	return half_span
