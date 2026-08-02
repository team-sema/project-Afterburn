class_name PlayerAugmentKind
extends RefCounted

enum Kind {
	STAT_MULTIPLIER = 0,
	## Offer a weapon definition: new progress + equip, or restore from records.
	WEAPON_ACQUIRE = 1,
	## Raise weapon_id level by 1 (equipped or recorded).
	WEAPON_LEVEL = 2,
	## Weapon-specific trait module (rank / attach). Does not raise weapon level.
	WEAPON_TRAIT = 3,
	FACILITY_EFFECT = 6,
}


static func is_weapon_offer(kind: Kind) -> bool:
	return kind in [Kind.WEAPON_ACQUIRE, Kind.WEAPON_LEVEL, Kind.WEAPON_TRAIT]
