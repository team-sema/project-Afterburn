extends Node2D

const NORMAL_ENEMY_SCRIPT: Script = preload("res://enemies/normal_enemy.gd")
const KAMIKAZE_ENEMY_SCRIPT: Script = preload("res://enemies/kamikaze_enemy.gd")

@export var augment_registry: EnemyAugmentRegistry
@export var progression: AugmentProgressionController
@export var spawn_sets: Array[EnemySpawnSet] = []

@export_group("Spawn Timing")
@export_range(0.2, 30.0, 0.1) var spawn_interval := 4.0
@export_range(0.0, 5.0, 0.05) var spawn_interval_jitter := 0.5

@export_group("Drone Formation")
@export_range(0.0, 400.0, 1.0) var drone_forward_speed := 72.0
## Shallow dive from +Y (larger = more lateral, slower vertical). Sign is chosen per spawn.
@export_range(0.0, 80.0, 0.5) var drone_dive_angle_degrees := 50.0

@export_group("Awl Formation")
@export_range(0.2, 10.0, 0.05) var awl_descend_duration := 1.4
@export_range(1.0, 120.0, 1.0) var awl_descend_speed := 42.0
@export_range(0.2, 10.0, 0.05) var awl_aim_duration := 1.4
@export_range(40.0, 600.0, 1.0) var awl_charge_speed := 280.0

var current_threat_level := 1
var margin := 8.0

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
	match spawn_set.pattern:
		EnemySpawnSet.Pattern.SINGLE:
			_spawn_single(spawn_set.enemy_scene)
		EnemySpawnSet.Pattern.DRONE_FORMATION:
			_spawn_drone_formation(spawn_set)
		EnemySpawnSet.Pattern.AWL_FORMATION:
			_spawn_awl_formation(spawn_set)


func _spawn_single(enemy_scene: PackedScene) -> void:
	spawner_component.scene = enemy_scene
	spawner_component.spawn(
		Vector2(randf_range(margin, get_viewport_rect().size.x - margin), -16.0),
		null,
		_inject_enemy_dependencies,
	)


func _spawn_drone_formation(spawn_set: EnemySpawnSet) -> void:
	var offsets := spawn_set.formation_offsets
	var half_span := _get_half_span(offsets)
	var x_limits := _get_origin_x_limits(half_span)
	var formation_origin := Vector2(randf_range(x_limits.x, x_limits.y), -16.0)
	var mid_x := (x_limits.x + x_limits.y) * 0.5
	var lateral_sign := 1.0 if formation_origin.x <= mid_x else -1.0
	var movement_settings := {
		"forward_speed": drone_forward_speed,
		"dive_angle_degrees": drone_dive_angle_degrees * lateral_sign,
		"half_span": half_span,
		"edge_margin": margin,
	}

	spawner_component.scene = spawn_set.enemy_scene
	for offset in offsets:
		var formation_offset := offset as Vector2
		var instance := spawner_component.spawn(
			formation_origin + formation_offset,
			null,
			func(enemy: Node) -> void:
				_inject_enemy_dependencies(enemy)
				assert(
					enemy.get_script() == NORMAL_ENEMY_SCRIPT,
					"Drone formation requires normal_enemy.gd.",
				),
		)
		assert(instance.has_method("setup_formation"), "Drone missing setup_formation.")
		instance.call("setup_formation", formation_origin, formation_offset, movement_settings)


func _spawn_awl_formation(spawn_set: EnemySpawnSet) -> void:
	var offsets := spawn_set.formation_offsets
	var half_span := _get_half_span(offsets)
	var half_depth := 0.0
	for offset in offsets:
		half_depth = maxf(half_depth, absf(offset.y))
	var x_limits := _get_origin_x_limits(half_span)
	var formation_origin := Vector2(
		randf_range(x_limits.x, x_limits.y),
		-16.0 - half_depth,
	)
	var movement_settings := {
		"descend_duration": awl_descend_duration,
		"descend_speed": awl_descend_speed,
		"aim_duration": awl_aim_duration,
		"charge_speed": awl_charge_speed,
	}

	spawner_component.scene = spawn_set.enemy_scene
	for offset in offsets:
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
					movement_settings,
				),
		)


func _get_half_span(offsets: Array[Vector2]) -> float:
	var half_span := 0.0
	for offset in offsets:
		half_span = maxf(half_span, absf(offset.x))
	return half_span


func _get_origin_x_limits(half_span: float) -> Vector2:
	var min_x := margin + half_span
	var max_x := get_viewport_rect().size.x - margin - half_span
	if max_x < min_x:
		max_x = min_x
	return Vector2(min_x, max_x)


func _validate_spawn_set(spawn_set: EnemySpawnSet) -> void:
	assert(spawn_set != null, "EnemyGenerator spawn sets cannot contain null.")
	assert(spawn_set.enemy_scene != null, "EnemySpawnSet requires an enemy scene.")
	if spawn_set.pattern != EnemySpawnSet.Pattern.SINGLE:
		assert(
			not spawn_set.formation_offsets.is_empty(),
			"Formation EnemySpawnSet requires at least one offset.",
		)


func _inject_enemy_dependencies(instance: Node) -> void:
	var enemy := instance as Enemy
	assert(enemy != null, "EnemyGenerator can only spawn Enemy scenes.")
	enemy.augment_registry = augment_registry
