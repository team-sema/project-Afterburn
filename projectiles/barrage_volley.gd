class_name BarrageVolley
extends Resource

enum Layout { SINGLE, FAN, RING }
@export var shot: BarrageShot
@export var layout: Layout = Layout.SINGLE
@export_range(1, 2048) var count := 1
@export var spread_degrees := 48.0
@export var angle_degrees := 0.0
@export var speed := 95.0
@export var origin_offset := Vector2.ZERO
## NONE fires world-down (plus rotations). EACH_SHOT reads the target position at
## every FIRE. LOCKED reuses the direction captured by the last sequence aim() step.
enum Aim { NONE, EACH_SHOT, LOCKED }
@export var aim: Aim = Aim.NONE
## Rotates Aim.NONE directions by the emitter's global rotation (turrets, spinning
## enemies). Aimed volleys are already world-space and ignore this flag.
@export var relative_to_emitter := false

## Compatibility alias: true means Aim.EACH_SHOT.
var aimed: bool:
	get: return aim != Aim.NONE
	set(value):
		if value != (aim != Aim.NONE): aim = Aim.EACH_SHOT if value else Aim.NONE

func is_valid() -> bool:
	return (shot != null and shot.is_valid() and layout in [Layout.SINGLE, Layout.FAN, Layout.RING]
		and aim in [Aim.NONE, Aim.EACH_SHOT, Aim.LOCKED]
		and count >= 1 and count <= 2048 and is_finite(spread_degrees) and spread_degrees >= 0 and spread_degrees <= 360
		and is_finite(angle_degrees) and is_finite(speed) and speed >= 0 and origin_offset.is_finite()
		and (shot.kind != BarrageShot.Kind.CURVED_LASER or speed > 0))

func directions(rotation_degrees := 0.0, aim_direction := Vector2.DOWN) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not is_valid() or not is_finite(rotation_degrees) or not aim_direction.is_finite():
		return result
	var base := aim_direction.normalized() if aim != Aim.NONE and not aim_direction.is_zero_approx() else Vector2.DOWN
	var total := 1 if layout == Layout.SINGLE else count
	for i in total:
		var offset := 0.0
		if layout == Layout.RING:
			offset = 360.0 * i / total
		elif layout == Layout.FAN and total > 1:
			offset = lerpf(-spread_degrees * 0.5, spread_degrees * 0.5, float(i) / (total - 1))
		result.append(base.rotated(deg_to_rad(angle_degrees + rotation_degrees + offset)))
	return result
