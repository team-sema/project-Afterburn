extends Node2D

@export var augment_registry: PlayerAugmentRegistry

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var augment_applier: PlayerAugmentApplier = $PlayerAugmentApplier
@onready var weapon_loadout: PlayerWeaponLoadout = $PlayerWeaponLoadout


func _ready() -> void:
	assert(augment_registry != null, "Ship requires an injected PlayerAugmentRegistry.")
	assert(weapon_loadout != null, "Ship requires a PlayerWeaponLoadout.")
	augment_applier.weapon_loadout = weapon_loadout
	augment_applier.initialize(augment_registry)
	weapon_loadout.loadout_changed.connect(_on_loadout_changed)
	_connect_weapon_fired_signals()


func get_weapon_loadout() -> PlayerWeaponLoadout:
	return weapon_loadout


func _on_loadout_changed() -> void:
	_connect_weapon_fired_signals()


func _connect_weapon_fired_signals() -> void:
	for weapon_system in weapon_loadout.get_all_weapon_systems():
		if not weapon_system.fired.is_connected(scale_component.tween_scale):
			weapon_system.fired.connect(scale_component.tween_scale)
