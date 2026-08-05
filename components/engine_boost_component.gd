class_name EngineBoostComponent
extends Node

## Optional facility ENGINE_BOOST: brief move-speed surge on the engine_boost action.

signal boost_activated
signal boost_ended
signal cooldown_changed(remaining: float, total: float)

const ACTION_ENGINE_BOOST := &"engine_boost"

@export var augment_applier: PlayerAugmentApplier

var facility_registry: PlayerAugmentRegistry

var _enabled := false
var _speed_mult := 1.0
var _duration := 0.8
var _cooldown := 7.0
var _active := false
var _remaining := 0.0
var _cd_remaining := 0.0


func initialize(registry: PlayerAugmentRegistry) -> void:
	facility_registry = registry
	refresh_from_registry()


func refresh_from_registry() -> void:
	if facility_registry == null:
		_enabled = false
		_clear_boost(false)
		return
	_enabled = facility_registry.has_module_effect_kind(FacilityModuleEffect.Kind.ENGINE_BOOST)
	if not _enabled:
		_clear_boost(false)
		return
	_speed_mult = facility_registry.get_module_effect_product(FacilityModuleEffect.Kind.ENGINE_BOOST)
	var first := facility_registry.get_first_module_effect(FacilityModuleEffect.Kind.ENGINE_BOOST)
	_duration = maxf(0.05, first.secondary)
	_cooldown = maxf(0.05, first.tertiary)


func is_boost_active() -> bool:
	return _active


func get_cooldown_remaining() -> float:
	return _cd_remaining


func get_cooldown_total() -> float:
	return _cooldown


func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		_cd_remaining = maxf(0.0, _cd_remaining - delta)
		cooldown_changed.emit(_cd_remaining, _cooldown)

	if _active:
		_remaining -= delta
		if _remaining <= 0.0:
			_clear_boost(true)
		return

	if not _enabled:
		return
	if _cd_remaining > 0.0:
		return
	if Input.is_action_just_pressed(ACTION_ENGINE_BOOST):
		_activate()


func _activate() -> void:
	_active = true
	_remaining = _duration
	_cd_remaining = _cooldown
	if augment_applier != null:
		augment_applier.set_boost_move_speed_multiplier(_speed_mult)
	boost_activated.emit()
	cooldown_changed.emit(_cd_remaining, _cooldown)


func _clear_boost(emit_ended: bool) -> void:
	var was_active := _active
	_active = false
	_remaining = 0.0
	if augment_applier != null:
		augment_applier.set_boost_move_speed_multiplier(1.0)
	if emit_ended and was_active:
		boost_ended.emit()
