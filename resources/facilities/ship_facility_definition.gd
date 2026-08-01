class_name ShipFacilityDefinition
extends Resource

## 함선 시설 1종의 정의. 시설은 무기별 고유 성능이 아니라 공통 수치만 강화하므로
## 효과 종류와 레벨별 효과값 표만 가진다. 밸런스 수치는 이 리소스에서만 관리한다.

enum Effect {
	## 주무기 공통 공격력 배율 (발사체 수·관통 등 고유 성능과 무관)
	MAIN_WEAPON_DAMAGE,
	## 보조무기 최대 탄약 가산
	AUXILIARY_MAX_AMMO,
	## 플레이어 이동속도 배율
	MOVE_SPEED,
	## 최대 선체 내구도 가산 (기존 HP)
	MAX_HULL,
	## 경험치·픽업 수집 반경 배율
	PICKUP_RANGE,
	## 최대 실드 가산 (선체와 분리된 방어 자원)
	MAX_SHIELD,
}

@export var id: StringName
@export var display_name: String = ""
@export var effect: Effect = Effect.MAIN_WEAPON_DAMAGE
## 시설 UI 한 줄 설명 (예: "주무기 공격력 증가")
@export var effect_summary: String = ""
## 시설 UI 아이콘 (흰색 실루엣, UI에서 색을 입힌다)
@export var icon: Texture2D
## Lv.1부터의 효과값 표. index 0 = Lv.1이며 무효과값(배율 1.0 / 가산 0)이어야 한다.
## 표 길이가 곧 현재 상한이며, 항목이 하나뿐이면 강화 불가 상태로 표시된다.
@export var level_values: PackedFloat32Array = PackedFloat32Array([1.0])


## 배율형 효과는 곱으로, 가산형 효과는 합으로 합산된다.
static func is_multiplier_effect(effect_kind: Effect) -> bool:
	return effect_kind in [
		Effect.MAIN_WEAPON_DAMAGE,
		Effect.MOVE_SPEED,
		Effect.PICKUP_RANGE,
	]


static func get_neutral_value_for(effect_kind: Effect) -> float:
	return 1.0 if is_multiplier_effect(effect_kind) else 0.0


func is_multiplier() -> bool:
	return is_multiplier_effect(effect)


func get_neutral_value() -> float:
	return get_neutral_value_for(effect)


func get_max_level() -> int:
	return maxi(1, level_values.size())


func get_value_for_level(level: int) -> float:
	if level_values.is_empty():
		return get_neutral_value()
	return level_values[clampi(level - 1, 0, level_values.size() - 1)]


## UI 표시용 문자열 ("×1.15" / "+4").
func format_value(value: float) -> String:
	if is_multiplier():
		return "×%.2f" % value
	return "+%d" % roundi(value)
