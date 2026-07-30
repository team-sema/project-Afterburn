extends Node2D

const GREEN_ENEMY_SCENE: PackedScene = preload("uid://bhw7lkvyjx43v")
const YELLOW_ENEMY_SCENE: PackedScene = preload("uid://dxo5ywpsobagu")
const PINK_ENEMY_SCENE: PackedScene = preload("uid://0th6okc5yjpd")
const KAMIKAZE_ENEMY_SCENE: PackedScene = preload("res://enemies/kamikaze_enemy.tscn")
const BOMB_ENEMY_SCENE: PackedScene = preload("res://enemies/bomb_enemy.tscn")
const NORMAL_ENEMY_SCRIPT: Script = preload("res://enemies/normal_enemy.gd")
const KAMIKAZE_ENEMY_SCRIPT: Script = preload("res://enemies/kamikaze_enemy.gd")

@export var game_stats: GameStats
@export var augment_registry: EnemyAugmentRegistry

@export_group("Drone Formation")
@export var drone_enemy_scene: PackedScene = GREEN_ENEMY_SCENE
## Member count follows array length. Default: horizontal row of 5.
@export var drone_formation_offsets: Array[Vector2] = [
	Vector2(-48, 0),
	Vector2(-24, 0),
	Vector2(0, 0),
	Vector2(24, 0),
	Vector2(48, 0),
]
@export_range(0.0, 400.0, 1.0) var drone_forward_speed := 72.0
## Shallow dive from +Y (larger = more lateral, slower vertical). Sign is chosen per spawn.
@export_range(0.0, 80.0, 0.5) var drone_dive_angle_degrees := 50.0
## Higher = rarer formation waves (same score curve as other timers).
@export_range(1.0, 30.0, 0.5) var drone_spawn_time_offset := 5.0
@export_range(1.0, 30.0, 0.5) var striker_spawn_time_offset := 11.0
@export_range(1.0, 30.0, 0.5) var kamikaze_spawn_time_offset := 8.0

@export_group("Awl Formation")
@export var awl_enemy_scene: PackedScene = KAMIKAZE_ENEMY_SCENE
## Tip leads downward (+Y). Array length = wing count (default V of 3).
@export var awl_formation_offsets: Array[Vector2] = [
	Vector2(-32, -14),
	Vector2(0, 14),
	Vector2(32, -14),
]
@export_range(0.2, 10.0, 0.05) var awl_descend_duration := 1.4
@export_range(1.0, 120.0, 1.0) var awl_descend_speed := 42.0
@export_range(0.2, 10.0, 0.05) var awl_aim_duration := 1.4
@export_range(40.0, 600.0, 1.0) var awl_charge_speed := 280.0
@export_range(1.0, 30.0, 0.5) var bomb_spawn_time_offset := 10.0

var margin := 8.0

@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var green_enemy_spawn_timer: Timer = %GreenEnemySpawnTimer
@onready var yellow_enemy_spawn_timer: Timer = %YellowEnemySpawnTimer
@onready var pink_enemy_spawn_timer: Timer = %PinkEnemySpawnTimer
@onready var kamikaze_enemy_spawn_timer: Timer = %KamikazeEnemySpawnTimer
@onready var bomb_enemy_spawn_timer: Timer = %BombEnemySpawnTimer


func _ready() -> void:
	assert(augment_registry != null, "EnemyGenerator requires an EnemyAugmentRegistry.")

	green_enemy_spawn_timer.timeout.connect(handle_drone_formation_spawn)
	yellow_enemy_spawn_timer.timeout.connect(
		handle_spawn.bind(YELLOW_ENEMY_SCENE, yellow_enemy_spawn_timer, striker_spawn_time_offset)
	)
	pink_enemy_spawn_timer.timeout.connect(handle_spawn.bind(PINK_ENEMY_SCENE, pink_enemy_spawn_timer, 10.0))
	kamikaze_enemy_spawn_timer.timeout.connect(handle_awl_formation_spawn)
	bomb_enemy_spawn_timer.timeout.connect(
		handle_spawn.bind(BOMB_ENEMY_SCENE, bomb_enemy_spawn_timer, bomb_spawn_time_offset)
	)

	game_stats.score_changed.connect(func(new_score: int):
		if new_score > 50:
			pink_enemy_spawn_timer.process_mode = Node.PROCESS_MODE_INHERIT
	)


func handle_spawn(enemy_scene: PackedScene, timer: Timer, time_offset: float = 1.0) -> void:
	spawner_component.scene = enemy_scene
	spawner_component.spawn(
		Vector2(randf_range(margin, get_viewport_rect().size.x - margin), -16.0),
		null,
		_inject_enemy_dependencies,
	)
	var spawn_rate = time_offset / (0.5 + (game_stats.score * 0.01))
	timer.start(spawn_rate + randf_range(0.25, 0.5))


func handle_drone_formation_spawn() -> void:
	assert(drone_enemy_scene != null, "drone_enemy_scene must be set.")
	assert(not drone_formation_offsets.is_empty(), "drone_formation_offsets must not be empty.")

	var half_span := 0.0
	for offset in drone_formation_offsets:
		half_span = maxf(half_span, absf(offset.x))

	var viewport_width := get_viewport_rect().size.x
	var min_x := margin + half_span
	var max_x := viewport_width - margin - half_span
	if max_x < min_x:
		max_x = min_x

	# Prefer diving toward the open side so the first leg crosses the playfield.
	var formation_origin := Vector2(randf_range(min_x, max_x), -16.0)
	var mid_x := (min_x + max_x) * 0.5
	var lateral_sign := 1.0 if formation_origin.x <= mid_x else -1.0
	var formation_start_time := Time.get_ticks_msec() * 0.001
	var movement_settings := {
		"forward_speed": drone_forward_speed,
		"dive_angle_degrees": drone_dive_angle_degrees * lateral_sign,
		"half_span": half_span,
		"edge_margin": margin,
	}

	spawner_component.scene = drone_enemy_scene
	for offset in drone_formation_offsets:
		var formation_offset := offset as Vector2
		spawner_component.spawn(
			formation_origin + formation_offset,
			null,
			func(instance: Node) -> void:
				_inject_enemy_dependencies(instance)
				assert(
					instance.get_script() == NORMAL_ENEMY_SCRIPT,
					"Drone formation requires normal_enemy.gd.",
				)
				assert(instance.has_method("setup_formation"), "Drone missing setup_formation.")
				instance.call(
					"setup_formation",
					formation_origin,
					formation_offset,
					formation_start_time,
					movement_settings,
				),
		)

	var spawn_rate := drone_spawn_time_offset / (0.5 + (game_stats.score * 0.01))
	green_enemy_spawn_timer.start(spawn_rate + randf_range(0.4, 1.2))


func handle_awl_formation_spawn() -> void:
	assert(awl_enemy_scene != null, "awl_enemy_scene must be set.")
	assert(not awl_formation_offsets.is_empty(), "awl_formation_offsets must not be empty.")

	var half_span := 0.0
	var half_depth := 0.0
	for offset in awl_formation_offsets:
		half_span = maxf(half_span, absf(offset.x))
		half_depth = maxf(half_depth, absf(offset.y))

	var viewport_width := get_viewport_rect().size.x
	var min_x := margin + half_span
	var max_x := viewport_width - margin - half_span
	if max_x < min_x:
		max_x = min_x

	var formation_origin := Vector2(randf_range(min_x, max_x), -16.0 - half_depth)
	var formation_start_time := Time.get_ticks_msec() * 0.001
	var movement_settings := {
		"descend_duration": awl_descend_duration,
		"descend_speed": awl_descend_speed,
		"aim_duration": awl_aim_duration,
		"charge_speed": awl_charge_speed,
	}

	spawner_component.scene = awl_enemy_scene
	for offset in awl_formation_offsets:
		var formation_offset := offset as Vector2
		spawner_component.spawn(
			formation_origin + formation_offset,
			null,
			func(instance: Node) -> void:
				_inject_enemy_dependencies(instance)
				assert(
					instance.get_script() == KAMIKAZE_ENEMY_SCRIPT,
					"Awl formation requires kamikaze_enemy.gd.",
				)
				assert(instance.has_method("setup_formation"), "Awl missing setup_formation.")
				instance.call(
					"setup_formation",
					formation_origin,
					formation_offset,
					formation_start_time,
					movement_settings,
				),
		)

	var spawn_rate := kamikaze_spawn_time_offset / (0.5 + (game_stats.score * 0.01))
	kamikaze_enemy_spawn_timer.start(spawn_rate + randf_range(0.5, 1.5))


func _inject_enemy_dependencies(instance: Node) -> void:
	var enemy := instance as Enemy
	assert(enemy != null, "EnemyGenerator can only spawn Enemy scenes.")
	enemy.augment_registry = augment_registry
