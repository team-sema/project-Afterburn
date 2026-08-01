extends Node2D

@export var augment_registry: EnemyAugmentRegistry
@export var progression: AugmentProgressionController
@export var spawn_sets: Array[EnemySpawnSet] = []

@export_group("Spawn Timing")
@export_range(0.2, 30.0, 0.1) var spawn_interval := 4.0
@export_range(0.0, 5.0, 0.05) var spawn_interval_jitter := 0.5

var current_threat_level := 1

@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var spawn_timer: Timer = %SpawnTimer


func _ready() -> void:
	assert(augment_registry != null, "EnemyGenerator requires an EnemyAugmentRegistry.")
	assert(progression != null, "EnemyGenerator requires an AugmentProgressionController.")
	assert(not spawn_sets.is_empty(), "EnemyGenerator requires at least one EnemySpawnSet.")
	for spawn_set in spawn_sets:
		_validate_spawn_set(spawn_set)

	current_threat_level = progression.get_threat_level()
	assert(
		not get_eligible_spawn_sets(current_threat_level).is_empty(),
		"EnemyGenerator requires a spawn set available at the initial Threat level.",
	)
	progression.threat_level_changed.connect(_on_threat_level_changed)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_schedule_next_spawn()


func get_eligible_spawn_sets(threat_level: int) -> Array[EnemySpawnSet]:
	var eligible: Array[EnemySpawnSet] = []
	for spawn_set in spawn_sets:
		if spawn_set.is_available_at(threat_level):
			eligible.append(spawn_set)
	return eligible


func pick_spawn_set(threat_level: int) -> EnemySpawnSet:
	var eligible := get_eligible_spawn_sets(threat_level)
	if eligible.is_empty():
		return null
	return eligible.pick_random()


func _on_threat_level_changed(new_threat_level: int) -> void:
	current_threat_level = new_threat_level


func _on_spawn_timer_timeout() -> void:
	var spawn_set := pick_spawn_set(current_threat_level)
	assert(spawn_set != null, "No EnemySpawnSet is available for the current Threat level.")
	_spawn(spawn_set)
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	spawn_timer.start(spawn_interval + randf_range(0.0, spawn_interval_jitter))


func _spawn(spawn_set: EnemySpawnSet) -> void:
	spawn_set.spawn(get_viewport_rect(), Callable(self, "_spawn_enemy"))


func _spawn_enemy(
	enemy_scene: PackedScene,
	spawn_position: Vector2,
	configure: Callable,
) -> Node:
	spawner_component.scene = enemy_scene
	return spawner_component.spawn(
		spawn_position,
		null,
		func(instance: Node) -> void:
			_inject_enemy_dependencies(instance)
			if configure.is_valid():
				configure.call(instance),
	)


func _validate_spawn_set(spawn_set: EnemySpawnSet) -> void:
	assert(spawn_set != null, "EnemyGenerator spawn sets cannot contain null.")
	spawn_set.validate()


func _inject_enemy_dependencies(instance: Node) -> void:
	var enemy := instance as Enemy
	assert(enemy != null, "EnemyGenerator can only spawn Enemy scenes.")
	enemy.augment_registry = augment_registry
