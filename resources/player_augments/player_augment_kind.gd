class_name PlayerAugmentKind
extends RefCounted

enum Kind {
	STAT_MULTIPLIER = 0,
	## New weapon equip (always fresh modules; no restore).
	WEAPON_ACQUIRE = 1,
	## Weapon-specific module level. Numeric value stays 3 for resource compatibility.
	WEAPON_TRAIT = 3,
	FACILITY_EFFECT = 6,
}


static func is_weapon_offer(kind: Kind) -> bool:
	return kind in [Kind.WEAPON_ACQUIRE, Kind.WEAPON_TRAIT]
