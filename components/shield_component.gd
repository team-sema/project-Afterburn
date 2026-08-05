class_name ShieldComponent
extends Node

## 선체(StatsComponent.health)와 분리된 방어 자원(버퍼 HP).
## 피해는 실드를 먼저 깎고, 남는 양만 선체로 넘긴다.
## 현재 < 최대이면 충전 게이지가 차며, 꽉 차면 실드 +1.

signal shield_changed(current_shield: int, max_shield: int)
## 실드가 피해를 일부라도 흡수했을 때 (HUD·연출용). 인자는 흡수한 양.
signal shield_absorbed(damage: int)
## 다음 실드 칸 충전률 0~1 (HUD 소형 게이지)
signal charge_changed(progress: float)

## 시설 보너스를 뺀 기본 최대 실드. 런 시작 시 현재=최대.
@export var base_max_shield := 1
## 실드 1칸을 채우는 데 걸리는 초 (현재 < 최대일 때).
@export_range(0.5, 120.0, 0.1) var regen_charge_duration := 30.0

var _facility_bonus := 0
var _current_shield := 0
var _charge_progress := 0.0
## Facility SHIELD_CHARGE_SPEED_MULT product. Higher = faster charge.
var charge_speed_multiplier := 1.0


func _ready() -> void:
	_current_shield = get_max_shield()
	_charge_progress = 0.0
	set_process(false)
	shield_changed.emit(_current_shield, get_max_shield())
	charge_changed.emit(_charge_progress)


func _process(delta: float) -> void:
	if not _needs_regen():
		_set_charge_progress(0.0)
		set_process(false)
		return
	var duration := maxf(0.05, regen_charge_duration / maxf(0.01, charge_speed_multiplier))
	_set_charge_progress(_charge_progress + delta / duration)
	if _charge_progress < 1.0:
		return
	_set_charge_progress(0.0)
	restore_shield(1)
	if not _needs_regen():
		set_process(false)


func get_max_shield() -> int:
	return maxi(0, base_max_shield + _facility_bonus)


func get_current_shield() -> int:
	return _current_shield


func get_charge_progress() -> float:
	return _charge_progress


## 최대 실드를 늘리고 늘어난 만큼만 현재 실드도 올린다 (전체 리필이 아니다).
func add_shield(amount: int) -> void:
	set_facility_bonus(_facility_bonus + amount)


func set_charge_speed_multiplier(multiplier: float) -> void:
	charge_speed_multiplier = maxf(0.01, multiplier)


## 시설 강화가 최대 실드를 바꾸는 유일한 경로.
func set_facility_bonus(bonus: int) -> void:
	var previous_max := get_max_shield()
	_facility_bonus = maxi(0, bonus)
	var delta := get_max_shield() - previous_max
	_set_current_shield(_current_shield + maxi(0, delta))
	_update_regen_process()


## 현재 실드만 충전한다. 최대 실드를 넘지 않는다.
func restore_shield(amount: int) -> void:
	if amount <= 0:
		return
	_set_current_shield(_current_shield + amount)
	_update_regen_process()


## 피격(실드·선체) 시 호출. 충전 게이지를 리셋하고 즉시 재충전을 시작한다.
func notify_hit() -> void:
	_set_charge_progress(0.0)
	_update_regen_process()


## 실드에 피해를 먼저 적용하고, 선체로 넘길 남은 피해를 반환한다.
func absorb_damage(damage: int) -> int:
	if damage <= 0:
		return 0
	if _current_shield <= 0:
		return damage
	var absorbed := mini(_current_shield, damage)
	_set_current_shield(_current_shield - absorbed)
	if absorbed > 0:
		shield_absorbed.emit(absorbed)
	return damage - absorbed


func _needs_regen() -> bool:
	return get_max_shield() > 0 and _current_shield < get_max_shield()


func _update_regen_process() -> void:
	var needs := _needs_regen()
	set_process(needs)
	if not needs:
		_set_charge_progress(0.0)


func _set_current_shield(value: int) -> void:
	var clamped := clampi(value, 0, get_max_shield())
	if clamped == _current_shield:
		_update_regen_process()
		return
	_current_shield = clamped
	shield_changed.emit(_current_shield, get_max_shield())
	_update_regen_process()


func _set_charge_progress(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _charge_progress):
		return
	_charge_progress = clamped
	charge_changed.emit(_charge_progress)
