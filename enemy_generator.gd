extends Node2D

@export var augment_registry: EnemyAugmentRegistry
@export var progression: AugmentProgressionController
@export var encounter_pool: EncounterPool

@export_group("Spawn Timing")
@export_range(0.2, 30.0, 0.1) var spawn_interval := 4.0
@export_range(0.0, 5.0, 0.05) var spawn_interval_jitter := 0.5
## Skip the last N encounter ids when alternatives exist (variety without raising difficulty).
@export_range(0, 8, 1) var recent_exclusion_count := 2

var current_threat_level := 1
var _recent_encounter_ids: Array[StringName] = []

@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var spawn_timer: Timer = %SpawnTimer


func _ready() -> void:
	assert(augment_registry != null, "EnemyGenerator requires an EnemyAugmentRegistry.")
	assert(progression != null, "EnemyGenerator requires an AugmentProgressionController.")
	assert(encounter_pool != null, "EnemyGenerator requires the MainEncounterPool.")
	assert(encounter_pool.validate(true), "EnemyGenerator MainEncounterPool is invalid.")
	enemy_spawner.augment_registry = augment_registry

	current_threat_level = progression.get_threat_level()
	assert(
		encounter_pool.get_total_weight(current_threat_level) > 0.0,
		"EnemyGenerator requires an encounter available at the initial Threat level.",
	)
	progression.threat_level_changed.connect(_on_threat_level_changed)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_schedule_next_spawn()


func pick_encounter(
	threat_level: int,
	random_number_generator: RandomNumberGenerator = null,
) -> EncounterPreset:
	return encounter_pool.choose(
		threat_level,
		random_number_generator,
		_recent_encounter_ids,
	)


func _on_threat_level_changed(new_threat_level: int) -> void:
	current_threat_level = new_threat_level


func _on_spawn_timer_timeout() -> void:
	var preset := pick_encounter(current_threat_level)
	if preset == null:
		push_warning(
			"EnemyGenerator skipped spawn: no encounter is available at Threat %d."
			% current_threat_level
		)
		_schedule_next_spawn()
		return
	_spawn(preset)
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	spawn_timer.start(spawn_interval + randf_range(0.0, spawn_interval_jitter))


func _spawn(preset: EncounterPreset) -> FormationController:
	_remember_encounter(preset.encounter_id)
	return enemy_spawner.spawn_encounter(preset)


func _remember_encounter(encounter_id: StringName) -> void:
	if recent_exclusion_count <= 0:
		_recent_encounter_ids.clear()
		return
	_recent_encounter_ids.append(encounter_id)
	while _recent_encounter_ids.size() > recent_exclusion_count:
		_recent_encounter_ids.pop_front()
