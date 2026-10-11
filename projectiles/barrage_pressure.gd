class_name BarragePressure
extends RefCounted

## Shared curve for the barrage pressure level P (docs/design/combat.md 탄막 압력).
## A pattern names a base value (P = 0) and a limit; every HALF_LIFE levels the
## value covers half of the remaining distance, so it never reaches the limit.

const HALF_LIFE := 4.0


static func progress(pressure: int) -> float:
	return 1.0 - pow(2.0, -float(maxi(pressure, 0)) / HALF_LIFE)


static func scale(base: float, limit: float, pressure: int) -> float:
	return lerpf(base, limit, progress(pressure))


static func scale_int(base: int, limit: int, pressure: int) -> int:
	return roundi(scale(float(base), float(limit), pressure))


## Ring counts stay even so the ring keeps its left-right symmetry.
static func scale_even(base: int, limit: int, pressure: int) -> int:
	return 2 * roundi(scale(float(base), float(limit), pressure) * 0.5)
