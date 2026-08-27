class_name ThreatEliteController
extends Node

signal elite_spawned(enemy: Enemy, threat_level: int)
signal elite_defeated(threat_level: int)

@export var progression: AugmentProgressionController
@export var enemy_generator: Node
@export var elite_preset: EncounterPreset
@export_range(1, 10000, 1) var base_elite_health := 180
@export_range(0, 10000, 1) var health_per_threat := 60

var active_elite: Enemy
var active_threat_level := 0


func _ready() -> void:
	assert(progression != null, "ThreatEliteController requires progression.")
	assert(enemy_generator != null, "ThreatEliteController requires EnemyGenerator.")
	assert(elite_preset != null and elite_preset.validate(true), "Elite preset is invalid.")
	assert(enemy_generator.has_method("spawn_special_encounter"))
	assert(enemy_generator.has_method("set_normal_spawns_paused"))
	progression.elite_milestone_requested.connect(_on_elite_milestone_requested)
	progression.elite_gate_changed.connect(_on_elite_gate_changed)


func _on_elite_milestone_requested(threat_level: int) -> void:
	assert(active_elite == null or not is_instance_valid(active_elite), "Only one elite may be active.")
	active_threat_level = threat_level
	enemy_generator.call("set_normal_spawns_paused", true)
	var controller := enemy_generator.call(
		"spawn_special_encounter",
		elite_preset,
		_configure_elite.bind(threat_level),
	) as FormationController
	assert(controller != null, "Elite encounter failed to spawn.")
	var members := controller.get_members()
	assert(members.size() == 1, "Elite encounter must contain exactly one enemy.")
	active_elite = members[0]
	active_elite.stats_component.no_health.connect(_on_active_elite_defeated, CONNECT_ONE_SHOT)
	elite_spawned.emit(active_elite, threat_level)


func _configure_elite(enemy: Enemy, threat_level: int) -> void:
	enemy.is_elite = true
	var stats := enemy.get_node("StatsComponent") as StatsComponent
	stats.health = base_elite_health + maxi(0, threat_level - 2) * health_per_threat
	var notifier := enemy.get_node_or_null("VisibleOnScreenNotifier2D") as FreeOffscreenComponent
	if notifier != null:
		notifier.suspend_despawn()


func _on_active_elite_defeated() -> void:
	var completed_threat := active_threat_level
	active_elite = null
	active_threat_level = 0
	assert(
		progression.complete_elite_milestone(completed_threat),
		"Elite defeat must complete the active Threat milestone.",
	)
	elite_defeated.emit(completed_threat)


func _on_elite_gate_changed(is_active: bool, _threat_level: int) -> void:
	if not is_active:
		enemy_generator.call("set_normal_spawns_paused", false)
