class_name WeaponSystem
extends Node2D

signal fired
## Aux consumables emit this when fully spent; loadout clears the slot.
signal depleted

var _global_fire_rate_multiplier := 1.0
var _local_fire_rate_multiplier := 1.0
var _global_damage_multiplier := 1.0
var _local_damage_multiplier := 1.0
## Ship facility (weapon room) channel, kept apart from weapon levels.
var _facility_damage_multiplier := 1.0
## Ship facility (hangar) extra uses for consumables.
var _consumable_capacity_bonus := 0

var _player: Node = null
var _loadout: Node = null
var _weapon_category: int = 0
var _slot_index: int = 0
## True after shutdown_weapon(); subclasses may read this.
var is_shutdown := false


func setup_weapon(
	player: Node,
	loadout: Node,
	category: int,
	slot_index: int,
) -> void:
	_player = player
	_loadout = loadout
	_weapon_category = category
	_slot_index = slot_index
	is_shutdown = false
	_on_weapon_setup()


func shutdown_weapon() -> void:
	is_shutdown = true
	_on_weapon_shutdown()


## Restore consumable usage (aux pickup of the same weapon).
func refill_consumable() -> void:
	if is_shutdown:
		return
	_on_refill_consumable()


## Remaining uses for HUD. -1 means not a tracked consumable.
func get_consumable_remaining() -> int:
	return -1


func get_consumable_max() -> int:
	return -1


func _on_refill_consumable() -> void:
	pass


## Subclasses call this when the consumable is fully spent.
func report_depleted() -> void:
	if is_shutdown:
		return
	depleted.emit()


## Subclasses call this when remaining uses change (HUD refresh).
func report_consumable_changed() -> void:
	if _loadout != null and _loadout.has_method("notify_consumable_changed"):
		_loadout.call("notify_consumable_changed")


func set_global_fire_rate_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Global fire rate multiplier must be greater than zero.")
	_global_fire_rate_multiplier = multiplier
	_apply_stat_multipliers()


func set_local_fire_rate_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Local fire rate multiplier must be greater than zero.")
	_local_fire_rate_multiplier = multiplier
	_apply_stat_multipliers()


func set_global_damage_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Global damage multiplier must be greater than zero.")
	_global_damage_multiplier = multiplier
	_apply_stat_multipliers()


func set_local_damage_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Local damage multiplier must be greater than zero.")
	_local_damage_multiplier = multiplier
	_apply_stat_multipliers()


func set_facility_damage_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Facility damage multiplier must be greater than zero.")
	_facility_damage_multiplier = multiplier
	_apply_stat_multipliers()


## Hangar bonus. Only consumables react; the base weapon ignores it.
func set_consumable_capacity_bonus(bonus: int) -> void:
	var clamped_bonus := maxi(0, bonus)
	if clamped_bonus == _consumable_capacity_bonus:
		return
	var delta := clamped_bonus - _consumable_capacity_bonus
	_consumable_capacity_bonus = clamped_bonus
	_on_consumable_capacity_bonus_changed(delta)


func get_consumable_capacity_bonus() -> int:
	return _consumable_capacity_bonus


func _on_consumable_capacity_bonus_changed(_delta: int) -> void:
	pass


func get_effective_fire_rate_multiplier() -> float:
	return _global_fire_rate_multiplier * _local_fire_rate_multiplier


func get_effective_damage_multiplier() -> float:
	return _global_damage_multiplier * _local_damage_multiplier * _facility_damage_multiplier


func _apply_stat_multipliers() -> void:
	pass


func _on_weapon_setup() -> void:
	pass


func _on_weapon_shutdown() -> void:
	pass
