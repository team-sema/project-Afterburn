extends Node2D

const GREEN_ENEMY_SCENE: PackedScene = preload("uid://bhw7lkvyjx43v")
const YELLOW_ENEMY_SCENE: PackedScene = preload("uid://dxo5ywpsobagu")
const PINK_ENEMY_SCENE: PackedScene = preload("uid://0th6okc5yjpd")

@export var game_stats: GameStats
@export var augment_registry: EnemyAugmentRegistry

var margin := 8.0
var screen_width = ProjectSettings.get_setting("display/window/size/viewport_width")

@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var green_enemy_spawn_timer: Timer = %GreenEnemySpawnTimer
@onready var yellow_enemy_spawn_timer: Timer = %YellowEnemySpawnTimer
@onready var pink_enemy_spawn_timer: Timer = %PinkEnemySpawnTimer


func _ready() -> void:
	assert(augment_registry != null, "EnemyGenerator requires an EnemyAugmentRegistry.")

	green_enemy_spawn_timer.timeout.connect(handle_spawn.bind(GREEN_ENEMY_SCENE, green_enemy_spawn_timer))
	yellow_enemy_spawn_timer.timeout.connect(handle_spawn.bind(YELLOW_ENEMY_SCENE, yellow_enemy_spawn_timer, 5.0))
	pink_enemy_spawn_timer.timeout.connect(handle_spawn.bind(PINK_ENEMY_SCENE, pink_enemy_spawn_timer, 10.0))

	game_stats.score_changed.connect(func(new_score: int):
		if new_score > 50:
			pink_enemy_spawn_timer.process_mode = Node.PROCESS_MODE_INHERIT
	)


func handle_spawn(enemy_scene: PackedScene, timer: Timer, time_offset: float = 1.0) -> void:
	spawner_component.scene = enemy_scene
	spawner_component.spawn(
		Vector2(randf_range(margin, screen_width - margin), -16.0),
		get_tree().current_scene,
		_inject_enemy_dependencies,
	)
	var spawn_rate = time_offset / (0.5 + (game_stats.score * 0.01))
	timer.start(spawn_rate + randf_range(0.25, 0.5))


func _inject_enemy_dependencies(instance: Node) -> void:
	var enemy := instance as Enemy
	assert(enemy != null, "EnemyGenerator can only spawn Enemy scenes.")
	enemy.augment_registry = augment_registry
