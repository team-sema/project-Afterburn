class_name ShieldComponent
extends Node

## 선체(StatsComponent.health)와 분리된 방어 자원(버퍼 HP).
## 피해는 실드를 먼저 깎고, 남는 양만 선체로 넘긴다.
## 현재 < 최대이면 충전 진행도(0~1칸)를 자동 충전·그레이즈로 채우고, 1칸이 되면 실드 +1.

signal shield_changed(current_shield: int, max_shield: int)
## 실드가 피해를 일부라도 흡수했을 때 (HUD·연출용). 인자는 흡수한 양.
signal shield_absorbed(damage: int)
## 다음 실드 칸 충전률 0~1 (HUD 소형 게이지)
signal charge_changed(progress: float)

## 시설 보너스를 뺀 기본 최대 실드. 런 시작 시 현재=최대.
@export var base_max_shield := 2
## 자동 충전만으로 실드 1칸을 채우는 데 걸리는 초 (현재 < 최대일 때).
@export_range(0.5, 300.0, 0.1) var regen_charge_duration := 120.0

const CHARGE_EPSILON := 0.000001

var _facility_bonus := 0
var _current_shield := 0
## Fraction (0~1) of the next shield point charged so far. Auto charge and
## graze both add to it; any hit clears it.
var _charge_progress := 0.0
## Facility SHIELD_CHARGE_SPEED_MULT product. Higher = shorter auto charge.
## Graze charge ignores it (docs/design/player.md「그레이즈」).
var charge_speed_multiplier := 1.0
## Run rule cards (e.g. brink trade-off). Multiplies the facility channel.
var rule_charge_speed_multiplier := 1.0


func _ready() -> void:
	_current_shield = get_max_shield()
	_charge_progress = 0.0
	set_process(false)
	shield_changed.emit(_current_shield, get_max_shield())
	charge_changed.emit(0.0)


func _process(delta: float) -> void:
	if not _needs_regen():
		_reset_charge()
		set_process(false)
		return
	_add_charge(delta / _charge_duration())
	if not _needs_regen():
		set_process(false)


func get_max_shield() -> int:
	return maxi(0, base_max_shield + _facility_bonus)


func get_current_shield() -> int:
	return _current_shield


## HUD 0~1: how much of the next shield point is charged.
func get_charge_progress() -> float:
	if not _needs_regen():
		return 0.0
	return clampf(_charge_progress, 0.0, 1.0)


## Graze charge: adds `fraction` of a shield point, unaffected by the charge
## speed multipliers. Returns false (and does nothing) when the shield is full.
func add_graze_charge(fraction: float) -> bool:
	if fraction <= 0.0 or not _needs_regen():
		return false
	_add_charge(fraction)
	return true


## 최대 실드를 늘리고 늘어난 만큼만 현재 실드도 올린다 (전체 리필이 아니다).
func add_shield(amount: int) -> void:
	set_facility_bonus(_facility_bonus + amount)


func set_charge_speed_multiplier(multiplier: float) -> void:
	charge_speed_multiplier = maxf(0.01, multiplier)


func set_rule_charge_speed_multiplier(multiplier: float) -> void:
	rule_charge_speed_multiplier = maxf(0.01, multiplier)


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


## 피격(실드·선체) 시 호출. 충전 경과를 리셋하고 즉시 재충전을 시작한다.
func notify_hit() -> void:
	_reset_charge()
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


## Advances the charge; reaching one whole point restores it and clears the charge.
func _add_charge(fraction: float) -> void:
	var next := _charge_progress + fraction
	# Float steps (e.g. 30 × 1/30) can land a hair below 1.0.
	if next < 1.0 - CHARGE_EPSILON:
		_set_charge_progress(next)
		return
	_reset_charge()
	restore_shield(1)


func _charge_duration() -> float:
	return maxf(
		0.05,
		regen_charge_duration / maxf(0.01, charge_speed_multiplier * rule_charge_speed_multiplier),
	)


func _needs_regen() -> bool:
	return get_max_shield() > 0 and _current_shield < get_max_shield()


func _update_regen_process() -> void:
	var needs := _needs_regen()
	set_process(needs)
	if not needs:
		_reset_charge()


func _set_current_shield(value: int) -> void:
	var clamped := clampi(value, 0, get_max_shield())
	if clamped == _current_shield:
		_update_regen_process()
		return
	_current_shield = clamped
	shield_changed.emit(_current_shield, get_max_shield())
	_update_regen_process()


func _reset_charge() -> void:
	_set_charge_progress(0.0)


func _set_charge_progress(value: float) -> void:
	var next := maxf(0.0, value)
	if is_equal_approx(next, _charge_progress):
		return
	_charge_progress = next
	charge_changed.emit(get_charge_progress())
