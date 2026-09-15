extends Node2D

const TANKER_GUARD_SNIPER_ID := &"tanker_guard_sniper"
const SNIPER_REINFORCEMENT_PRESET := preload("res://resources/encounters/presets/sniper_single.tres")

@export var augment_registry: EnemyAugmentRegistry
@export var progression: AugmentProgressionController
@export var encounter_pool: EncounterPool
## Timer-driven random spawning. An EncounterDirector turns this off when it
## starts and drives spawns explicitly instead.
@export var automatic_spawning_enabled := true

@export_group("Spawn Timing")
@export_range(0.2, 30.0, 0.1) var spawn_interval := 2.8
@export_range(0.0, 5.0, 0.05) var spawn_interval_jitter := 0.3
## Skip the last N encounter ids when alternatives exist (variety without raising difficulty).
@export_range(0, 8, 1) var recent_exclusion_count := 2

var current_threat_level := 1
var normal_spawns_paused := false
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
	if automatic_spawning_enabled:
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
	if normal_spawns_paused or not automatic_spawning_enabled:
		return
	var preset := pick_encounter(current_threat_level)
	if preset == null:
		push_warning(
			"EnemyGenerator skipped spawn: no encounter is available at Threat %d."
			% current_threat_level
		)
		_schedule_next_spawn()
		return
	_spawn(resolve_normal_preset(preset))
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	if normal_spawns_paused or not automatic_spawning_enabled:
		return
	spawn_timer.start(spawn_interval + randf_range(0.0, spawn_interval_jitter))


func _spawn(preset: EncounterPreset) -> FormationController:
	_remember_encounter(preset.encounter_id)
	return enemy_spawner.spawn_encounter(preset)


## Threat-weighted pick from an arbitrary pool, honoring the recent-id exclusion.
func pick_from_pool(
	pool: EncounterPool,
	random_number_generator: RandomNumberGenerator = null,
) -> EncounterPreset:
	var selected_pool := pool if pool != null else encounter_pool
	return selected_pool.choose(
		current_threat_level,
		random_number_generator,
		_recent_encounter_ids,
	)


## Explicit spawn used by EncounterDirector. Applies the same preset substitution
## as timer spawns and returns a run that completes when every member is gone.
func spawn_preset_tracked(preset: EncounterPreset) -> EncounterRun:
	if preset == null:
		return null
	return EncounterRun.track(_spawn(resolve_normal_preset(preset)))


func set_automatic_spawning_enabled(is_enabled: bool) -> void:
	if automatic_spawning_enabled == is_enabled:
		return
	automatic_spawning_enabled = is_enabled
	if not automatic_spawning_enabled:
		spawn_timer.stop()
	elif not normal_spawns_paused:
		_schedule_next_spawn()


func resolve_normal_preset(preset: EncounterPreset) -> EncounterPreset:
	if preset != null and preset.encounter_id == TANKER_GUARD_SNIPER_ID and _has_active_tanker():
		return SNIPER_REINFORCEMENT_PRESET
	return preset


func _has_active_tanker() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is TankerEnemy and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			return true
	return false


func spawn_special_encounter(
	preset: EncounterPreset,
	configure_before_add: Callable = Callable(),
) -> FormationController:
	return enemy_spawner.spawn_encounter(preset, 0, configure_before_add)


func set_normal_spawns_paused(is_paused: bool) -> void:
	if normal_spawns_paused == is_paused:
		return
	normal_spawns_paused = is_paused
	if normal_spawns_paused:
		spawn_timer.stop()
	elif automatic_spawning_enabled:
		_schedule_next_spawn()


func _remember_encounter(encounter_id: StringName) -> void:
	if recent_exclusion_count <= 0:
		_recent_encounter_ids.clear()
		return
	_recent_encounter_ids.append(encounter_id)
	while _recent_encounter_ids.size() > recent_exclusion_count:
		_recent_encounter_ids.pop_front()
