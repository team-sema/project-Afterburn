class_name WeaponSystem
extends Node2D

signal fired
## Legacy no-op path; ammo depletion no longer unequips weapons.
signal depleted

var _global_fire_rate_multiplier := 1.0
var _local_fire_rate_multiplier := 1.0
var _global_damage_multiplier := 1.0
var _local_damage_multiplier := 1.0
## Ship facility (weapon room) channel, kept apart from weapon levels.
var _facility_damage_multiplier := 1.0
## Deprecated hangar ammo bonus (always 0 under unified weapons).
var _consumable_capacity_bonus := 0

var _player: Node = null
var _loadout: Node = null
var _slot_index: int = 0
## True after shutdown_weapon(); subclasses may read this.
var is_shutdown := false


func setup_weapon(
	player: Node,
	loadout: Node,
	slot_index: int,
) -> void:
	_player = player
	_loadout = loadout
	_slot_index = slot_index
	is_shutdown = false
	_on_weapon_setup()


func shutdown_weapon() -> void:
	is_shutdown = true
	_on_weapon_shutdown()


## Legacy hook; unified weapons do not consume ammo slots.
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


## Subclasses may still emit; loadout no longer clears bays on deplete.
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


## One-line combat stats for STATUS HUD. Subclasses override.
func get_status_stat_line() -> String:
	return ""


func _status_damage(base_damage: int) -> int:
	return maxi(1, roundi(float(base_damage) * get_effective_damage_multiplier()))


func _status_interval(base_interval: float) -> float:
	return base_interval / maxf(0.001, get_effective_fire_rate_multiplier())


func _status_num(value: float, places: int = 2) -> String:
	var scale := pow(10.0, float(places))
	var rounded := roundf(value * scale) / scale
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return ("%." + str(places) + "f") % rounded


func _apply_stat_multipliers() -> void:
	pass


func _on_weapon_setup() -> void:
	pass


func _on_weapon_shutdown() -> void:
	pass
