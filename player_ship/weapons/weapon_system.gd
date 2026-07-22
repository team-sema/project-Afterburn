class_name WeaponSystem
extends Node2D

signal fired

var _global_fire_rate_multiplier := 1.0
var _local_fire_rate_multiplier := 1.0
var _global_damage_multiplier := 1.0
var _local_damage_multiplier := 1.0


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


func get_effective_fire_rate_multiplier() -> float:
	return _global_fire_rate_multiplier * _local_fire_rate_multiplier


func get_effective_damage_multiplier() -> float:
	return _global_damage_multiplier * _local_damage_multiplier


func _apply_stat_multipliers() -> void:
	pass
