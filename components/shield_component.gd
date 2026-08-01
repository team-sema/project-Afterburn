class_name ShieldComponent
extends Node

## 선체(StatsComponent.health)와 분리된 방어 자원.
## 피해 직전 실드가 1 이상이면 그 피해 이벤트 전체를 막는다(실드 게이트).
## 리필 조건은 정하지 않고, 다른 시스템이 호출할 충전 인터페이스만 제공한다.

signal shield_changed(current_shield: int, max_shield: int)
## 실드가 피해 이벤트 하나를 막았을 때 (HUD·연출용)
signal shield_absorbed(damage: int)

## 시설 보너스를 뺀 기본 최대 실드.
@export var base_max_shield := 0

var _facility_bonus := 0
var _current_shield := 0


func _ready() -> void:
	_current_shield = get_max_shield()
	shield_changed.emit(_current_shield, get_max_shield())


func get_max_shield() -> int:
	return maxi(0, base_max_shield + _facility_bonus)


func get_current_shield() -> int:
	return _current_shield


## 최대 실드를 늘리고 늘어난 만큼만 현재 실드도 올린다 (전체 리필이 아니다).
func add_shield(amount: int) -> void:
	set_facility_bonus(_facility_bonus + amount)


## 시설 강화가 최대 실드를 바꾸는 유일한 경로.
func set_facility_bonus(bonus: int) -> void:
	var previous_max := get_max_shield()
	_facility_bonus = maxi(0, bonus)
	var delta := get_max_shield() - previous_max
	_set_current_shield(_current_shield + maxi(0, delta))


## 현재 실드만 충전한다. 최대 실드를 넘지 않는다.
func restore_shield(amount: int) -> void:
	if amount <= 0:
		return
	_set_current_shield(_current_shield + amount)


## 피해 이벤트를 실드가 막았으면 true. 초과 피해는 선체로 넘기지 않는다.
func absorb_damage(damage: int) -> bool:
	if _current_shield < 1:
		return false
	_set_current_shield(_current_shield - damage)
	shield_absorbed.emit(damage)
	return true


func _set_current_shield(value: int) -> void:
	var clamped := clampi(value, 0, get_max_shield())
	if clamped == _current_shield:
		return
	_current_shield = clamped
	shield_changed.emit(_current_shield, get_max_shield())
