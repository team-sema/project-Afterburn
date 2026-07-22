class_name PlayerAugmentApplier
extends Node

@export var move_component: MoveComponent

var augment_registry: PlayerAugmentRegistry
var weapon_systems: Array[WeaponSystem] = []
var base_move_speed_multiplier: float


func _ready() -> void:
	assert(move_component != null, "PlayerAugmentApplier requires a MoveComponent.")
	base_move_speed_multiplier = move_component.velocity_multiplier


func initialize(registry: PlayerAugmentRegistry, equipped_weapons: Array[WeaponSystem]) -> void:
	assert(registry != null, "PlayerAugmentApplier requires a PlayerAugmentRegistry.")
	assert(not equipped_weapons.is_empty(), "PlayerAugmentApplier requires at least one WeaponSystem.")
	augment_registry = registry
	weapon_systems = equipped_weapons.duplicate()
	augment_registry.augment_added.connect(_on_augment_added)
	augment_registry.augments_cleared.connect(refresh)
	refresh()


func refresh() -> void:
	var move_speed_multiplier := 1.0
	var fire_rate_multiplier := 1.0
	var weapon_damage_multiplier := 1.0

	for augment in augment_registry.get_active_augments():
		for modifier in augment.stat_modifiers:
			match modifier.stat:
				PlayerStatModifier.Stat.MOVE_SPEED:
					move_speed_multiplier *= modifier.multiplier
				PlayerStatModifier.Stat.FIRE_RATE:
					fire_rate_multiplier *= modifier.multiplier
				PlayerStatModifier.Stat.WEAPON_DAMAGE:
					weapon_damage_multiplier *= modifier.multiplier

	move_component.velocity_multiplier = base_move_speed_multiplier * move_speed_multiplier
	for weapon_system in weapon_systems:
		weapon_system.set_global_fire_rate_multiplier(fire_rate_multiplier)
		weapon_system.set_global_damage_multiplier(weapon_damage_multiplier)


func _on_augment_added(_augment: PlayerAugment) -> void:
	refresh()
