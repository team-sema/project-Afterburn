class_name BulletAction
extends Resource

enum Type { WAIT, TURN_BY, TURN_TO, TURN_AT, HEADING_WAVE, LATERAL_WAVE, SPEED, TINT, OPACITY, VISUAL_SCALE, HITBOX_SCALE, PARALLEL, HOMING }
@export var type: Type = Type.WAIT
@export var duration := 0.0
@export var value := 0.0
@export var period := 1.2
@export var phase := 0.0 # Radians.
@export var color := Color.WHITE
@export var children: Array[BulletAction] = []
## Easing for interpolated actions (turn_by/turn_to/speed/tint/opacity/scales).
## Constant-rate turns, waves, homing and wait ignore it.
@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

static func make(kind: Type, target: float, seconds: float) -> BulletAction:
	var action := BulletAction.new()
	action.type = kind
	action.value = target
	action.duration = seconds
	return action

static func turn_by(degrees: float, seconds: float) -> BulletAction:
	return make(Type.TURN_BY, degrees, seconds)

static func homing(max_turn_degrees_per_second: float, seconds: float) -> BulletAction:
	return make(Type.HOMING, max_turn_degrees_per_second, seconds)

static func tint_to(tint: Color, seconds: float) -> BulletAction:
	var action := make(Type.TINT, 0, seconds)
	action.color = tint
	return action

static func visual_scale_to(scale: float, seconds: float) -> BulletAction:
	return make(Type.VISUAL_SCALE, scale, seconds)

static func hitbox_scale_to(scale: float, seconds: float) -> BulletAction:
	return make(Type.HITBOX_SCALE, scale, seconds)

## Applies easing to this action; returns self so parallel children can chain it.
func eased(transition: Tween.TransitionType, easing: Tween.EaseType = Tween.EASE_IN_OUT) -> BulletAction:
	transition_type = transition
	ease_type = easing
	return self

func uses_easing() -> bool:
	return type in [Type.TURN_BY, Type.TURN_TO, Type.SPEED, Type.TINT, Type.OPACITY, Type.VISUAL_SCALE, Type.HITBOX_SCALE]

## Interpolation weight in [0, 1] for elapsed seconds of this action.
func progress(elapsed: float) -> float:
	if duration <= 0: return 1.0
	var t := clampf(elapsed, 0, duration)
	if transition_type == Tween.TRANS_LINEAR or not uses_easing():
		return t / duration
	# Overshooting transitions must preserve channel bounds and hitbox envelopes.
	return clampf(float(Tween.interpolate_value(0.0, 1.0, t, duration, transition_type, ease_type)), 0.0, 1.0)

func channel() -> String:
	match type:
		Type.TURN_BY, Type.TURN_TO, Type.TURN_AT, Type.HEADING_WAVE, Type.HOMING: return "heading"
		Type.LATERAL_WAVE: return "lateral"
		Type.SPEED: return "speed"
		Type.TINT: return "tint"
		Type.OPACITY: return "opacity"
		Type.VISUAL_SCALE: return "visual_scale"
		Type.HITBOX_SCALE: return "hitbox_scale"
	return ""

func length() -> float:
	if type != Type.PARALLEL:
		return duration
	var longest := 0.0
	for action in children:
		if action != null:
			longest = maxf(longest, action.duration)
	return longest

func validation_error() -> String:
	if type < Type.WAIT or type > Type.HOMING or not is_finite(duration) or duration < 0 or not is_finite(value):
		return "Action needs a valid type, finite value and nonnegative duration."
	if transition_type < Tween.TRANS_LINEAR or transition_type > Tween.TRANS_SPRING or ease_type < Tween.EASE_IN or ease_type > Tween.EASE_OUT_IN:
		return "Action easing must use Tween transition and ease enums."
	if type == Type.PARALLEL:
		if children.is_empty() or children.size() > 16:
			return "Parallel requires 1..16 actions."
		var channels := {}
		for action in children:
			if action == null or action.type == Type.PARALLEL:
				return "Parallel contains only non-null leaf actions."
			var error := action.validation_error()
			if not error.is_empty(): return error
			var key := action.channel()
			if not key.is_empty() and channels.has(key): return "Parallel actions conflict on " + key
			channels[key] = true
	if type in [Type.HEADING_WAVE, Type.LATERAL_WAVE] and (not is_finite(period) or period < 0.1 or not is_finite(phase)):
		return "Wave period must be at least 0.1s and phase finite."
	if type == Type.SPEED and value < 0: return "Speed must be nonnegative."
	if type == Type.HOMING and (value <= 0 or duration <= 0): return "Homing needs a positive turn rate and duration."
	if type in [Type.VISUAL_SCALE, Type.HITBOX_SCALE] and (value <= 0 or value > 16): return "Scale must be in (0, 16]."
	if type == Type.OPACITY and (value < 0 or value > 1): return "Opacity must be in [0, 1]."
	if type == Type.TINT and not (is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)):
		return "Tint must be finite."
	return ""
