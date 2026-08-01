class_name PlayerAugmentApplier
extends Node

@export var move_component: MoveComponent
@export var weapon_loadout: PlayerWeaponLoadout

var augment_registry: PlayerAugmentRegistry
var base_move_speed_multiplier: float
## Engine facility bonus. Move speed is composed in one place, so it enters here.
var facility_move_speed_multiplier := 1.0
var pending_auxiliary_slot_index := -1


func _ready() -> void:
	assert(move_component != null, "PlayerAugmentApplier requires a MoveComponent.")
	base_move_speed_multiplier = move_component.velocity_multiplier


func initialize(registry: PlayerAugmentRegistry) -> void:
	assert(registry != null, "PlayerAugmentApplier requires a PlayerAugmentRegistry.")
	assert(weapon_loadout != null, "PlayerAugmentApplier requires a PlayerWeaponLoadout.")
	augment_registry = registry
	if not augment_registry.augment_added.is_connected(_on_augment_added):
		augment_registry.augment_added.connect(_on_augment_added)
	if not augment_registry.augments_cleared.is_connected(refresh):
		augment_registry.augments_cleared.connect(refresh)
	refresh()


func set_pending_auxiliary_slot(slot_index: int) -> void:
	pending_auxiliary_slot_index = slot_index


func set_facility_move_speed_multiplier(multiplier: float) -> void:
	facility_move_speed_multiplier = maxf(0.01, multiplier)
	refresh()


func refresh() -> void:
	var move_speed_multiplier := 1.0
	var fire_rate_multiplier := 1.0
	var weapon_damage_multiplier := 1.0

	if augment_registry != null:
		for augment in augment_registry.get_active_augments():
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


func _on_augment_added(augment: PlayerAugment) -> void:
	if augment == null:
		return
	match augment.augment_type:
		PlayerAugmentKind.Kind.STAT_MULTIPLIER:
			pass
		PlayerAugmentKind.Kind.UPGRADE_MAIN_SLOT:
			weapon_loadout.upgrade_main_slot()
		PlayerAugmentKind.Kind.UPGRADE_AUXILIARY_SLOT:
			weapon_loadout.upgrade_auxiliary_slot(pending_auxiliary_slot_index)
			pending_auxiliary_slot_index = -1
		PlayerAugmentKind.Kind.UPGRADE_FACILITY:
			# 시설 레벨은 ShipFacilityRegistry가 갖고, 적용은 ShipFacilityApplier가 한다.
			pass
		_:
			push_warning("PlayerAugmentApplier: ignored non-performance augment type %s" % augment.augment_type)
	refresh()
