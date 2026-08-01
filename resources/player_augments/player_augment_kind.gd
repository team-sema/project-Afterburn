class_name PlayerAugmentKind
extends RefCounted

enum Kind {
	STAT_MULTIPLIER = 0,
	UPGRADE_MAIN_WEAPON = 4,
	UPGRADE_AUXILIARY_WEAPON = 5,
	## 장착 중 해당 함선 시설의 효과값을 한 단계 제공한다.
	FACILITY_EFFECT = 6,
}
