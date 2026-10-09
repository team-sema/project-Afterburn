class_name CockpitGeometry
extends RefCounted

const SHELL_SIZE := Vector2(640, 360)
const FIELD_LEFT := 150.0
const FIELD_WIDTH := 340.0
const SHOULDER_Y := 226.0
const LOWER_INSET := 76.0

static func inset_at(y: float) -> float:
	return LOWER_INSET * clampf((y - SHOULDER_Y) / (360.0 - SHOULDER_Y), 0.0, 1.0)

static func clamp_position(point: Vector2, margin: float) -> Vector2:
	var y := clampf(point.y, margin, 360.0 - margin)
	# Offset the sloping boundary by the same perpendicular clearance as the sides.
	var slope := LOWER_INSET / (360.0 - SHOULDER_Y)
	var inset := maxf(margin, inset_at(y) + margin * sqrt(1.0 + slope * slope))
	var top_slope := 24.0 / 22.0
	var top_inset := 24.0 * clampf(1.0 - y / 22.0, 0.0, 1.0)
	if y < 30.0:
		inset = maxf(inset, top_inset + margin * sqrt(1.0 + top_slope * top_slope))
	return Vector2(clampf(point.x, inset, FIELD_WIDTH - inset), y)
