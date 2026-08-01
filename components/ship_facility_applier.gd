class_name ShipFacilityApplier
extends Node

## 시설 레벨 → 플레이어 공통 스탯 적용.
## 시설은 무기 고유 성능을 바꾸지 않으므로 무기 id로 분기하지 않고,
## 로드아웃·이동·선체·실드·수집 반경의 공통 입력값만 갱신한다.

## 선체 최대치가 바뀔 때 (HUD 갱신용). 현재 선체는 StatsComponent.health_changed로 본다.
signal max_hull_changed(max_hull: int)

@export var augment_applier: PlayerAugmentApplier
@export var weapon_loadout: PlayerWeaponLoadout
@export var stats_component: StatsComponent
@export var shield_component: ShieldComponent
@export var experience_collector: ExperienceCollectorComponent

var facility_registry: ShipFacilityRegistry
## 시설 적용 전 최대 선체. 선체 시설 보너스와 분리해 둔다.
var base_max_hull := 1
## 시설 적용 전 수집 반경.
var base_collection_radius := 0.0

var _applied_max_hull_bonus := 0


func initialize(registry: ShipFacilityRegistry) -> void:
	assert(registry != null, "ShipFacilityApplier requires a ShipFacilityRegistry.")
	facility_registry = registry
	if stats_component != null:
		base_max_hull = maxi(1, stats_component.health)
	if experience_collector != null:
		base_collection_radius = experience_collector.collection_radius
	if not facility_registry.facility_level_changed.is_connected(_on_facility_level_changed):
		facility_registry.facility_level_changed.connect(_on_facility_level_changed)
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
		weapon_loadout.set_facility_main_damage_multiplier(
			facility_registry.get_effect_total(ShipFacilityDefinition.Effect.MAIN_WEAPON_DAMAGE)
		)
		weapon_loadout.set_facility_auxiliary_ammo_bonus(
			roundi(facility_registry.get_effect_total(ShipFacilityDefinition.Effect.AUXILIARY_MAX_AMMO))
		)

	if augment_applier != null:
		augment_applier.set_facility_move_speed_multiplier(
			facility_registry.get_effect_total(ShipFacilityDefinition.Effect.MOVE_SPEED)
		)

	if experience_collector != null:
		experience_collector.collection_radius = (
			base_collection_radius
			* facility_registry.get_effect_total(ShipFacilityDefinition.Effect.PICKUP_RANGE)
		)

	if shield_component != null:
		shield_component.set_facility_bonus(
			roundi(facility_registry.get_effect_total(ShipFacilityDefinition.Effect.MAX_SHIELD))
		)

	_apply_max_hull(roundi(facility_registry.get_effect_total(ShipFacilityDefinition.Effect.MAX_HULL)))


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


func _on_facility_level_changed(_facility_id: StringName, _new_level: int) -> void:
	refresh()
