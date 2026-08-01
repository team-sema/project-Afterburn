class_name PlayerAugmentKind
extends RefCounted

enum Kind {
	STAT_MULTIPLIER,
	EQUIP_MAIN_WEAPON,
	EQUIP_AUXILIARY_WEAPON,
	UNLOCK_AUXILIARY_SLOT,
	UPGRADE_MAIN_WEAPON,
	UPGRADE_AUXILIARY_WEAPON,
	## 함선 시설 레벨 +1. 대상 시설은 PlayerAugment.facility_id로 지정한다.
	UPGRADE_FACILITY,
}
