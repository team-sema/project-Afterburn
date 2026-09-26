class_name PlayerAugmentKind
extends RefCounted

enum Kind {
	STAT_MULTIPLIER = 0,
	## New weapon equip (always fresh modules; no restore).
	WEAPON_ACQUIRE = 1,
	## Weapon-specific module level. Numeric value stays 3 for resource compatibility.
	WEAPON_TRAIT = 3,
	FACILITY_EFFECT = 6,
	## Run-wide rule change applied on pick (e.g. an extra weapon bay). No slot.
	SHIP_RULE = 7,
}


static func is_weapon_offer(kind: Kind) -> bool:
	return kind in [Kind.WEAPON_ACQUIRE, Kind.WEAPON_TRAIT]


## Cards installed into universal facility slots.
static func is_facility_offer(kind: Kind) -> bool:
	return kind in [Kind.STAT_MULTIPLIER, Kind.FACILITY_EFFECT]
