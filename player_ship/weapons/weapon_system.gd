class_name WeaponSystem
extends Node2D

signal fired
## Legacy no-op path; ammo depletion no longer unequips weapons.
signal depleted

var _global_fire_rate_multiplier := 1.0
var _facility_fire_rate_multiplier := 1.0
var _global_damage_multiplier := 1.0
## Ship facility (weapon room) channels.
var _facility_damage_multiplier := 1.0
## Temporary overcharge / emergency facility buffs.
var _temp_damage_multiplier := 1.0
## Extra multiplier when the hit target is a boss enemy.
var _boss_damage_multiplier := 1.0
## Deprecated hangar ammo bonus (always 0 under unified weapons).
var _consumable_capacity_bonus := 0

## Bound at setup (private — subclasses must use getters / connect helpers).
var _player_node: Node = null
var _loadout_node: Node = null
var _slot_index: int = 0
var _bound_weapon_id: StringName = &""
## True after shutdown_weapon(); subclasses may read this.
var is_shutdown := false


func setup_weapon(
	player: Node,
	loadout: Node,
	p_slot_index: int,
	p_weapon_id: StringName = &"",
) -> void:
	_player_node = player
	_loadout_node = loadout
	_slot_index = p_slot_index
	_bound_weapon_id = p_weapon_id
	is_shutdown = false
	_on_weapon_setup()


func get_weapon_id() -> StringName:
	return _bound_weapon_id


func get_player_actor() -> Node:
	return _player_node


func get_loadout() -> Node:
	return _loadout_node


func connect_weapon_trait_changed(callback: Callable) -> void:
	if _loadout_node == null or not _loadout_node.has_signal(&"weapon_trait_changed"):
		return
	if not _loadout_node.is_connected(&"weapon_trait_changed", callback):
		_loadout_node.connect(&"weapon_trait_changed", callback)


func disconnect_weapon_trait_changed(callback: Callable) -> void:
	if _loadout_node == null or not _loadout_node.has_signal(&"weapon_trait_changed"):
		return
	if _loadout_node.is_connected(&"weapon_trait_changed", callback):
		_loadout_node.disconnect(&"weapon_trait_changed", callback)


func get_trait_rank(trait_id: StringName) -> int:
	if _loadout_node == null or _bound_weapon_id == &"" or trait_id == &"":
		return 0
	if not _loadout_node.has_method("get_weapon_traits"):
		return 0
	var ranks: Dictionary = _loadout_node.call("get_weapon_traits", _bound_weapon_id)
	return int(ranks.get(trait_id, 0))


func has_trait(trait_id: StringName) -> bool:
	return get_trait_rank(trait_id) > 0


func get_trait_param(trait_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
	var rank := get_trait_rank(trait_id)
	if rank <= 0:
		return default_value
	var definition := _load_trait_definition(trait_id)
	if definition == null:
		return default_value
	return definition.get_param_for_rank(rank, key, default_value)


func _load_trait_definition(trait_id: StringName) -> WeaponTraitDefinition:
	var path := "res://resources/weapons/traits/%s.tres" % String(trait_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as WeaponTraitDefinition


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
	if _loadout_node != null and _loadout_node.has_method("notify_consumable_changed"):
		_loadout_node.call("notify_consumable_changed")


func set_global_fire_rate_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Global fire rate multiplier must be greater than zero.")
	_global_fire_rate_multiplier = multiplier
	_apply_stat_multipliers()


func set_global_damage_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Global damage multiplier must be greater than zero.")
	_global_damage_multiplier = multiplier
	_apply_stat_multipliers()


func set_facility_damage_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Facility damage multiplier must be greater than zero.")
	_facility_damage_multiplier = multiplier
	_apply_stat_multipliers()


func set_facility_fire_rate_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Facility fire rate multiplier must be greater than zero.")
	_facility_fire_rate_multiplier = multiplier
	_apply_stat_multipliers()


func set_temp_damage_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Temp damage multiplier must be greater than zero.")
	_temp_damage_multiplier = multiplier
	_apply_stat_multipliers()


func set_boss_damage_multiplier(multiplier: float) -> void:
	assert(multiplier > 0.0, "Boss damage multiplier must be greater than zero.")
	_boss_damage_multiplier = multiplier
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
	return _global_fire_rate_multiplier * _facility_fire_rate_multiplier


func get_effective_damage_multiplier() -> float:
	return (
		_global_damage_multiplier
		* _facility_damage_multiplier
		* _temp_damage_multiplier
	)


func get_boss_damage_multiplier() -> float:
	return _boss_damage_multiplier


func resolve_hit_damage(base_damage: int, hurtbox: HurtboxComponent = null) -> int:
	var mult := get_effective_damage_multiplier()
	if hurtbox != null and not is_equal_approx(_boss_damage_multiplier, 1.0):
		var node: Node = hurtbox.get_parent()
		while node != null and not (node is Enemy):
			node = node.get_parent()
		if node is Enemy and (node as Enemy).is_boss:
			mult *= _boss_damage_multiplier
	return maxi(1, roundi(base_damage * mult))


func _apply_stat_multipliers() -> void:
	pass


func _on_weapon_setup() -> void:
	pass


func _on_weapon_shutdown() -> void:
	pass
