class_name FacilityModuleEffect
extends Resource

## Per-module facility effect payload. Installed modules of the same Kind stack
## by multiplying primaries (multipliers) or summing (additives). Timed buffs use
## the product of primaries for strength and timing from the first module found.

enum Kind {
	WEAPON_DAMAGE_MULT,
	BOSS_DAMAGE_MULT,
	PERIODIC_DAMAGE_BUFF, ## primary=damage mult, secondary=duration, tertiary=interval
	HULL_HIT_DAMAGE_BUFF, ## primary=damage mult, secondary=duration, tertiary=cooldown
	MOVE_SPEED_MULT,
	ENGINE_BOOST, ## primary=speed mult, secondary=duration, tertiary=cooldown
	MAX_HULL_ADD,
	HULL_HIT_IFRAMES, ## primary=bonus duration seconds
	PICKUP_RANGE_MULT,
	XP_GAIN_MULT,
	MAX_SHIELD_ADD,
	SHIELD_CHARGE_SPEED_MULT,
}

@export var kind: Kind = Kind.WEAPON_DAMAGE_MULT
@export var primary := 1.0
@export var secondary := 0.0
@export var tertiary := 0.0


static func is_multiplier_kind(effect_kind: Kind) -> bool:
	return effect_kind in [
		Kind.WEAPON_DAMAGE_MULT,
		Kind.BOSS_DAMAGE_MULT,
		Kind.PERIODIC_DAMAGE_BUFF,
		Kind.HULL_HIT_DAMAGE_BUFF,
		Kind.MOVE_SPEED_MULT,
		Kind.ENGINE_BOOST,
		Kind.PICKUP_RANGE_MULT,
		Kind.XP_GAIN_MULT,
		Kind.SHIELD_CHARGE_SPEED_MULT,
	]


static func get_neutral_primary_for(effect_kind: Kind) -> float:
	return 1.0 if is_multiplier_kind(effect_kind) else 0.0
