class_name PlayerAugmentApplier
extends Node

@export var move_component: MoveComponent
@export var weapon_loadout: PlayerWeaponLoadout

var augment_registry: PlayerAugmentRegistry
var base_move_speed_multiplier: float
## Engine facility bonus. Move speed is composed in one place, so it enters here.
var facility_move_speed_multiplier := 1.0


func _ready() -> void:
	assert(move_component != null, "PlayerAugmentApplier requires a MoveComponent.")
	base_move_speed_multiplier = move_component.velocity_multiplier


func initialize(registry: PlayerAugmentRegistry) -> void:
	assert(registry != null, "PlayerAugmentApplier requires a PlayerAugmentRegistry.")
	assert(weapon_loadout != null, "PlayerAugmentApplier requires a PlayerWeaponLoadout.")
	augment_registry = registry
	if not augment_registry.augments_changed.is_connected(refresh):
		augment_registry.augments_changed.connect(refresh)
	refresh()


func set_facility_move_speed_multiplier(multiplier: float) -> void:
	facility_move_speed_multiplier = maxf(0.01, multiplier)
	refresh()


func refresh() -> void:
	var move_speed_multiplier := 1.0
	var fire_rate_multiplier := 1.0
	var weapon_damage_multiplier := 1.0

	if augment_registry != null:
		for module in augment_registry.get_installed_modules():
			var augment := module.augment
			if augment.augment_type == PlayerAugmentKind.Kind.WEAPON_TRAIT:
				# Trait ranks are applied at install time onto weapon progress; nothing to stack here.
				continue
			if augment.augment_type != PlayerAugmentKind.Kind.STAT_MULTIPLIER:
				continue
			for modifier in augment.stat_modifiers:
				match modifier.stat:
					PlayerStatModifier.Stat.MOVE_SPEED:
						move_speed_multiplier *= modifier.multiplier
					PlayerStatModifier.Stat.FIRE_RATE:
						fire_rate_multiplier *= modifier.multiplier
					PlayerStatModifier.Stat.WEAPON_DAMAGE:
						weapon_damage_multiplier *= modifier.multiplier

	move_component.velocity_multiplier = (
		base_move_speed_multiplier * move_speed_multiplier * facility_move_speed_multiplier
	)
	if weapon_loadout != null:
		weapon_loadout.set_global_stat_multipliers(weapon_damage_multiplier, fire_rate_multiplier)
