class_name ThreatEliteController
extends Node

signal elite_spawned(enemy: Enemy, threat_level: int)
signal elite_defeated(threat_level: int)

@export var progression: AugmentProgressionController
@export var enemy_generator: Node
@export var bullet_cancel_reward: BulletCancelRewardController
@export var elite_preset: EncounterPreset
@export var charge_elite_preset: EncounterPreset = preload("res://resources/encounters/presets/threat_elite_awl.tres")
@export var bomb_elite_preset: EncounterPreset = preload("res://resources/encounters/presets/threat_elite_bomb.tres")
@export var caster_elite_preset: EncounterPreset = preload("res://resources/encounters/presets/threat_elite_caster.tres")
@export_range(1, 10000, 1) var base_elite_health := 420
@export_range(0, 10000, 1) var health_per_threat := 140
## Minimum bullet-cancel XP per kill. Converted bullets count toward it; the
## shortfall pops out of the kill position as 1 XP orbs.
@export_range(0, 1000, 1) var elite_minimum_cancel_experience := 10
@export_range(0, 1000, 1) var boss_minimum_cancel_experience := 20

var active_elite: Enemy
var active_threat_level := 0
var _next_gate_preset: EncounterPreset
var _next_gate_is_boss := false
var _last_elite_preset: EncounterPreset
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	assert(progression != null, "ThreatEliteController requires progression.")
	assert(enemy_generator != null, "ThreatEliteController requires EnemyGenerator.")
	assert(bullet_cancel_reward != null, "ThreatEliteController requires bullet cancel reward.")
	assert(elite_preset != null and elite_preset.validate(true), "Elite preset is invalid.")
	assert(charge_elite_preset != null and charge_elite_preset.validate(true), "Charge elite preset is invalid.")
	assert(bomb_elite_preset != null and bomb_elite_preset.validate(true), "Bomb elite preset is invalid.")
	assert(caster_elite_preset != null and caster_elite_preset.validate(true), "Caster elite preset is invalid.")
	rng.randomize()
	assert(enemy_generator.has_method("spawn_special_encounter"))
	assert(enemy_generator.has_method("set_normal_spawns_paused"))
	progression.elite_milestone_requested.connect(_on_elite_milestone_requested)
	progression.elite_gate_changed.connect(_on_elite_gate_changed)


## Overrides the rotation rule for the next gate only. A null preset keeps
## the rule. Boss gates mark the enemy is_boss and keep the scene's HP.
func set_next_gate(preset: EncounterPreset, is_boss := false) -> void:
	_next_gate_preset = preset
	_next_gate_is_boss = is_boss and preset != null


func _resolve_gate_preset(threat_level: int) -> EncounterPreset:
	if _next_gate_preset != null:
		return _next_gate_preset
	if threat_level <= 2:
		return elite_preset
	if threat_level == 3:
		return charge_elite_preset
	var candidates: Array[EncounterPreset] = []
	for preset in get_rotation_presets():
		if preset != _last_elite_preset:
			candidates.append(preset)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func get_rotation_presets() -> Array[EncounterPreset]:
	return [elite_preset, charge_elite_preset, bomb_elite_preset, caster_elite_preset]


func _on_elite_milestone_requested(threat_level: int) -> void:
	assert(active_elite == null or not is_instance_valid(active_elite), "Only one elite may be active.")
	active_threat_level = threat_level
	var preset := _resolve_gate_preset(threat_level)
	var is_boss := _next_gate_is_boss
	_next_gate_preset = null
	_next_gate_is_boss = false
	if not is_boss:
		_last_elite_preset = preset
	enemy_generator.call("set_normal_spawns_paused", true)
	var controller := enemy_generator.call(
		"spawn_special_encounter",
		preset,
		_configure_gate_enemy.bind(threat_level, is_boss),
	) as FormationController
	assert(controller != null, "Elite encounter failed to spawn.")
	var members := controller.get_members()
	assert(members.size() == 1, "Elite encounter must contain exactly one enemy.")
	active_elite = members[0]
	active_elite.stats_component.no_health.connect(_on_active_elite_defeated, CONNECT_ONE_SHOT)
	if not is_boss:
		_spawn_elite_escorts()
	elite_spawned.emit(active_elite, threat_level)


func _spawn_elite_escorts() -> void:
	var registry := enemy_generator.get("augment_registry") as EnemyAugmentRegistry
	if registry == null:
		return
	for preset in registry.get_elite_escort_presets():
		enemy_generator.call("spawn_special_encounter", preset)


func _configure_gate_enemy(enemy: Enemy, threat_level: int, is_boss: bool) -> void:
	if is_boss:
		enemy.is_boss = true
	else:
		enemy.is_elite = true
		var stats := enemy.get_node("StatsComponent") as StatsComponent
		stats.health = base_elite_health + maxi(0, threat_level - 2) * health_per_threat
	var notifier := enemy.get_node_or_null("VisibleOnScreenNotifier2D") as FreeOffscreenComponent
	if notifier != null:
		notifier.suspend_despawn()


func _on_active_elite_defeated() -> void:
	var completed_threat := active_threat_level
	# no_health fires synchronously, so the enemy is still valid here.
	var kill_position := active_elite.global_position
	var minimum_experience := (
		boss_minimum_cancel_experience if active_elite.is_boss
		else elite_minimum_cancel_experience
	)
	active_elite = null
	active_threat_level = 0
	# The reward runs without pausing the tree: the ship, remaining enemies and
	# their fire keep going while the converted XP flies in. Only player augment
	# input stays locked until the enemy offer opens.
	progression.set_bullet_cancel_reward_active(true)
	await bullet_cancel_reward.collect_projectiles_and_vacuum(minimum_experience, kill_position)
	if not bullet_cancel_reward.has_live_collector():
		# The ship died during the vacuum; the run is ending, so no offer.
		progression.set_bullet_cancel_reward_active(false)
		return
	var milestone_completed := progression.complete_elite_milestone(completed_threat)
	progression.set_bullet_cancel_reward_active(false)
	assert(milestone_completed, "Elite defeat must complete the active Threat milestone.")
	elite_defeated.emit(completed_threat)


func _on_elite_gate_changed(is_active: bool, _threat_level: int) -> void:
	if not is_active:
		enemy_generator.call("set_normal_spawns_paused", false)
