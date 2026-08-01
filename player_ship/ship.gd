extends Node2D

@export var augment_registry: PlayerAugmentRegistry
@export var facility_registry: ShipFacilityRegistry

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var augment_applier: PlayerAugmentApplier = $PlayerAugmentApplier
@onready var facility_applier: ShipFacilityApplier = $ShipFacilityApplier
@onready var weapon_loadout: PlayerWeaponLoadout = $PlayerWeaponLoadout
@onready var stats_component: StatsComponent = $StatsComponent
@onready var shield_component: ShieldComponent = $ShieldComponent


func _ready() -> void:
	assert(augment_registry != null, "Ship requires an injected PlayerAugmentRegistry.")
	assert(weapon_loadout != null, "Ship requires a PlayerWeaponLoadout.")
	augment_applier.weapon_loadout = weapon_loadout
	augment_applier.initialize(augment_registry)
	if facility_registry != null:
		facility_applier.initialize(facility_registry)
	else:
		push_warning("Ship: no ShipFacilityRegistry injected; facilities stay at Lv.1.")
	weapon_loadout.loadout_changed.connect(_on_loadout_changed)
	_connect_weapon_fired_signals()


func get_weapon_loadout() -> PlayerWeaponLoadout:
	return weapon_loadout


func get_facility_applier() -> ShipFacilityApplier:
	return facility_applier


func get_stats_component() -> StatsComponent:
	return stats_component


func get_shield_component() -> ShieldComponent:
	return shield_component


func _on_loadout_changed() -> void:
	_connect_weapon_fired_signals()


func _connect_weapon_fired_signals() -> void:
	for weapon_system in weapon_loadout.get_all_weapon_systems():
		if not weapon_system.fired.is_connected(scale_component.tween_scale):
			weapon_system.fired.connect(scale_component.tween_scale)
