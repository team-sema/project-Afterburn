class_name ShipFacilityApplier
extends Node

## 장착된 시설 모듈 → 플레이어 공통 스탯 적용.
## FacilityModuleEffect Kind별로 합산·곱산하고, 무기 고유 성능은 건드리지 않는다.

## 선체 최대치가 바뀔 때 (HUD 갱신용). 현재 선체는 StatsComponent.health_changed로 본다.
signal max_hull_changed(max_hull: int)

@export var augment_applier: PlayerAugmentApplier
@export var weapon_loadout: PlayerWeaponLoadout
@export var stats_component: StatsComponent
@export var shield_component: ShieldComponent
@export var experience_collector: ExperienceCollectorComponent
@export var progression_controller: AugmentProgressionController
@export var combat_buff_controller: ShipCombatBuffController
@export var engine_boost_component: EngineBoostComponent

var facility_registry: PlayerAugmentRegistry
## 시설 적용 전 최대 선체. 선체 시설 보너스와 분리해 둔다.
var base_max_hull := 1
## 시설 적용 전 수집 반경.
var base_collection_radius := 0.0

var _applied_max_hull_bonus := 0


func initialize(registry: PlayerAugmentRegistry) -> void:
	assert(registry != null, "ShipFacilityApplier requires a PlayerAugmentRegistry.")
	facility_registry = registry
	if stats_component != null:
		base_max_hull = maxi(1, stats_component.health)
	if experience_collector != null:
		base_collection_radius = experience_collector.collection_radius
	if not facility_registry.augments_changed.is_connected(refresh):
		facility_registry.augments_changed.connect(refresh)
	if combat_buff_controller != null:
		combat_buff_controller.initialize(facility_registry)
	if engine_boost_component != null:
		engine_boost_component.initialize(facility_registry)
	refresh()


## 기본 최대 선체 + 선체 시설 가산.
func get_max_hull() -> int:
	return maxi(1, base_max_hull + _applied_max_hull_bonus)


func get_max_hull_bonus() -> int:
	return _applied_max_hull_bonus


func get_max_shield() -> int:
	return shield_component.get_max_shield() if shield_component != null else 0


func get_collection_radius() -> float:
	return experience_collector.collection_radius if experience_collector != null else 0.0


func refresh() -> void:
	if facility_registry == null:
		return

	if weapon_loadout != null:
		weapon_loadout.set_facility_damage_multiplier(
			facility_registry.get_module_effect_product(FacilityModuleEffect.Kind.WEAPON_DAMAGE_MULT)
		)
		weapon_loadout.set_facility_fire_rate_multiplier(
			facility_registry.get_module_effect_product(
				FacilityModuleEffect.Kind.WEAPON_FIRE_RATE_MULT
			)
		)
		weapon_loadout.set_boss_damage_multiplier(
			facility_registry.get_module_effect_product(FacilityModuleEffect.Kind.BOSS_DAMAGE_MULT)
		)

	if augment_applier != null:
		augment_applier.set_facility_move_speed_multiplier(
			facility_registry.get_module_effect_product(FacilityModuleEffect.Kind.MOVE_SPEED_MULT)
		)

	if experience_collector != null:
		experience_collector.collection_radius = (
			base_collection_radius
			* facility_registry.get_module_effect_product(FacilityModuleEffect.Kind.PICKUP_RANGE_MULT)
		)

	if progression_controller == null and is_inside_tree():
		var nodes := get_tree().get_nodes_in_group("augment_progression")
		if not nodes.is_empty():
			progression_controller = nodes[0] as AugmentProgressionController
	if progression_controller != null:
		progression_controller.experience_gain_multiplier = (
			facility_registry.get_module_effect_product(FacilityModuleEffect.Kind.XP_GAIN_MULT)
		)

	if shield_component != null:
		shield_component.set_facility_bonus(
			roundi(facility_registry.get_module_effect_sum(FacilityModuleEffect.Kind.MAX_SHIELD_ADD))
		)
		shield_component.set_charge_speed_multiplier(
			facility_registry.get_module_effect_product(
				FacilityModuleEffect.Kind.SHIELD_CHARGE_SPEED_MULT
			)
		)

	_apply_max_hull(roundi(facility_registry.get_module_effect_sum(FacilityModuleEffect.Kind.MAX_HULL_ADD)))

	if combat_buff_controller != null:
		combat_buff_controller.refresh_from_registry()
	if engine_boost_component != null:
		engine_boost_component.refresh_from_registry()


## StatsComponent에는 최대 체력 개념이 없어, 늘어난 최대치만큼만 현재 선체를 함께 올린다.
## 선체는 그 밖의 방법으로 회복되지 않는다.
func _apply_max_hull(bonus: int) -> void:
	if stats_component == null:
		return
	var previous_max := get_max_hull()
	_applied_max_hull_bonus = maxi(0, bonus)
	var delta := get_max_hull() - previous_max
	if delta == 0:
		return
	stats_component.health = clampi(stats_component.health + delta, 1, get_max_hull())
	max_hull_changed.emit(get_max_hull())
