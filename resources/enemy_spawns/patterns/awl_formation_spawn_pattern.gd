class_name AwlFormationSpawnPattern
extends EnemySpawnPattern

const KAMIKAZE_ENEMY_SCRIPT: Script = preload("res://enemies/kamikaze_enemy.gd")

@export var formation_offsets: Array[Vector2] = []
@export_range(0.0, 128.0, 1.0) var edge_margin := 8.0
@export_range(-256.0, 0.0, 1.0) var spawn_y_offset := -16.0
@export_range(0.2, 10.0, 0.05) var descend_duration := 1.4
@export_range(1.0, 120.0, 1.0) var descend_speed := 42.0
@export_range(0.2, 10.0, 0.05) var aim_duration := 1.4
@export_range(40.0, 600.0, 1.0) var charge_speed := 280.0


func spawn(
	enemy_scene: PackedScene,
	viewport_rect: Rect2,
	spawn_enemy: Callable,
) -> void:
	var half_span := 0.0
	var half_depth := 0.0
	for offset in formation_offsets:
		half_span = maxf(half_span, absf(offset.x))
		half_depth = maxf(half_depth, absf(offset.y))
	var min_x := viewport_rect.position.x + edge_margin + half_span
	var max_x := maxf(min_x, viewport_rect.end.x - edge_margin - half_span)
	var formation_origin := Vector2(
		randf_range(min_x, max_x),
		viewport_rect.position.y + spawn_y_offset - half_depth,
	)
	var movement_settings := {
		"descend_duration": descend_duration,
		"descend_speed": descend_speed,
		"aim_duration": aim_duration,
		"charge_speed": charge_speed,
	}

	for offset in formation_offsets:
		var formation_offset := offset as Vector2
		spawn_enemy.call(
			enemy_scene,
			formation_origin + formation_offset,
			func(enemy: Node) -> void:
				assert(
					enemy.get_script() == KAMIKAZE_ENEMY_SCRIPT,
					"Awl formation requires kamikaze_enemy.gd.",
				)
				assert(enemy.has_method("setup_formation"), "Awl missing setup_formation.")
				enemy.call(
					"setup_formation",
					formation_origin,
					formation_offset,
					movement_settings,
				),
		)


func validate() -> void:
	assert(not formation_offsets.is_empty(), "Awl formation requires at least one offset.")
