extends Node2D

@export var augment_registry: PlayerAugmentRegistry

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var augment_applier: PlayerAugmentApplier = $PlayerAugmentApplier
@onready var weapon_systems: Array[WeaponSystem] = _get_weapon_systems()


func _ready() -> void:
	assert(augment_registry != null, "Ship requires an injected PlayerAugmentRegistry.")
	assert(not weapon_systems.is_empty(), "Ship requires at least one WeaponSystem under WeaponMount.")
	augment_applier.initialize(augment_registry, weapon_systems)

	for weapon_system in weapon_systems:
		weapon_system.fired.connect(scale_component.tween_scale)


func _get_weapon_systems() -> Array[WeaponSystem]:
	var systems: Array[WeaponSystem] = []

	for child in $WeaponMount.get_children():
		if child is WeaponSystem:
			systems.append(child as WeaponSystem)

	return systems
