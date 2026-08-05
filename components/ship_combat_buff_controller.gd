class_name ShipCombatBuffController
extends Node

## Facility timed damage buffs: periodic overcharge and hull-hit emergency output.
## Timing params come from the first module of each Kind; strength is the product of primaries.

signal buff_activated(buff_id: StringName)
signal buff_ended(buff_id: StringName)
signal buff_state_changed

const BUFF_OVERCHARGE := &"overcharge"
const BUFF_EMERGENCY := &"emergency"

@export var weapon_loadout: PlayerWeaponLoadout
@export var stats_component: StatsComponent

var facility_registry: PlayerAugmentRegistry

var _has_overcharge := false
var _overcharge_mult := 1.0
var _overcharge_duration := 5.0
var _overcharge_interval := 20.0
var _overcharge_timer := 0.0
var _overcharge_active := false
var _overcharge_remaining := 0.0

var _has_emergency := false
var _emergency_mult := 1.0
var _emergency_duration := 5.0
var _emergency_cooldown := 15.0
var _emergency_cd_remaining := 0.0
var _emergency_active := false
var _emergency_remaining := 0.0
var _last_hull := -1


func initialize(registry: PlayerAugmentRegistry) -> void:
	facility_registry = registry
	if stats_component != null:
		_last_hull = stats_component.health
		if not stats_component.health_changed.is_connected(_on_hull_changed):
			stats_component.health_changed.connect(_on_hull_changed)
	refresh_from_registry()


func refresh_from_registry() -> void:
	if facility_registry == null:
		return

	_has_overcharge = facility_registry.has_module_effect_kind(
		FacilityModuleEffect.Kind.PERIODIC_DAMAGE_BUFF
	)
	if _has_overcharge:
		_overcharge_mult = facility_registry.get_module_effect_product(
			FacilityModuleEffect.Kind.PERIODIC_DAMAGE_BUFF
		)
		var first := facility_registry.get_first_module_effect(
			FacilityModuleEffect.Kind.PERIODIC_DAMAGE_BUFF
		)
		_overcharge_duration = maxf(0.05, first.secondary)
		_overcharge_interval = maxf(0.05, first.tertiary)
	else:
		_overcharge_mult = 1.0
		if _overcharge_active:
			_end_buff(BUFF_OVERCHARGE)

	_has_emergency = facility_registry.has_module_effect_kind(
		FacilityModuleEffect.Kind.HULL_HIT_DAMAGE_BUFF
	)
	if _has_emergency:
		_emergency_mult = facility_registry.get_module_effect_product(
			FacilityModuleEffect.Kind.HULL_HIT_DAMAGE_BUFF
		)
		var emergency_first := facility_registry.get_first_module_effect(
			FacilityModuleEffect.Kind.HULL_HIT_DAMAGE_BUFF
		)
		_emergency_duration = maxf(0.05, emergency_first.secondary)
		_emergency_cooldown = maxf(0.05, emergency_first.tertiary)
	else:
		_emergency_mult = 1.0
		if _emergency_active:
			_end_buff(BUFF_EMERGENCY)

	_apply_temp_multiplier()
	buff_state_changed.emit()


## Called from HurtComponent after hull takes damage (shield absorb does not count).
func notify_hull_damage() -> void:
	if not _has_emergency:
		return
	if _emergency_active or _emergency_cd_remaining > 0.0:
		return
	_start_buff(BUFF_EMERGENCY)


func is_buff_active(buff_id: StringName) -> bool:
	match buff_id:
		BUFF_OVERCHARGE:
			return _overcharge_active
		BUFF_EMERGENCY:
			return _emergency_active
		_:
			return false


func get_temp_damage_multiplier() -> float:
	var mult := 1.0
	if _overcharge_active:
		mult *= _overcharge_mult
	if _emergency_active:
		mult *= _emergency_mult
	return mult


func _process(delta: float) -> void:
	if _emergency_cd_remaining > 0.0:
		_emergency_cd_remaining = maxf(0.0, _emergency_cd_remaining - delta)

	if _overcharge_active:
		_overcharge_remaining -= delta
		if _overcharge_remaining <= 0.0:
			_end_buff(BUFF_OVERCHARGE)
	elif _has_overcharge:
		_overcharge_timer += delta
		if _overcharge_timer >= _overcharge_interval:
			_overcharge_timer = 0.0
			_start_buff(BUFF_OVERCHARGE)

	if _emergency_active:
		_emergency_remaining -= delta
		if _emergency_remaining <= 0.0:
			_end_buff(BUFF_EMERGENCY)


func _on_hull_changed() -> void:
	if stats_component == null:
		return
	var current := stats_component.health
	if _last_hull < 0:
		_last_hull = current
		return
	if current < _last_hull:
		notify_hull_damage()
	_last_hull = current


func _start_buff(buff_id: StringName) -> void:
	match buff_id:
		BUFF_OVERCHARGE:
			if not _has_overcharge:
				return
			_overcharge_active = true
			_overcharge_remaining = _overcharge_duration
			_overcharge_timer = 0.0
		BUFF_EMERGENCY:
			if not _has_emergency:
				return
			_emergency_active = true
			_emergency_remaining = _emergency_duration
			_emergency_cd_remaining = _emergency_cooldown
		_:
			return
	_apply_temp_multiplier()
	buff_activated.emit(buff_id)
	buff_state_changed.emit()


func _end_buff(buff_id: StringName) -> void:
	match buff_id:
		BUFF_OVERCHARGE:
			if not _overcharge_active:
				return
			_overcharge_active = false
			_overcharge_remaining = 0.0
		BUFF_EMERGENCY:
			if not _emergency_active:
				return
			_emergency_active = false
			_emergency_remaining = 0.0
		_:
			return
	_apply_temp_multiplier()
	buff_ended.emit(buff_id)
	buff_state_changed.emit()


func _apply_temp_multiplier() -> void:
	if weapon_loadout == null:
		return
	weapon_loadout.set_temp_damage_multiplier(get_temp_damage_multiplier())
