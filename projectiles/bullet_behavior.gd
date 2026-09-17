class_name BulletBehavior
extends Resource

@export var actions: Array[BulletAction] = []
@export var repeat_count := 1 # Zero loops forever; empty is straight forever.

func then(action: BulletAction) -> BulletBehavior:
	actions.append(action)
	return self

func wait(seconds: float) -> BulletBehavior:
	return then(BulletAction.make(BulletAction.Type.WAIT, 0, seconds))

func turn_by(degrees: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.turn_by(degrees, seconds))

func homing(max_turn_degrees_per_second: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.homing(max_turn_degrees_per_second, seconds))

func turn_to(degrees: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.make(BulletAction.Type.TURN_TO, degrees, seconds))

func turn_at(degrees_per_second: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.make(BulletAction.Type.TURN_AT, degrees_per_second, seconds))

func heading_wave(degrees: float, seconds: float) -> BulletBehavior:
	var action := BulletAction.make(BulletAction.Type.HEADING_WAVE, degrees, seconds)
	action.period = seconds
	return then(action)

func lateral_wave(amplitude: float, seconds: float, phase := 0.0) -> BulletBehavior:
	var action := BulletAction.make(BulletAction.Type.LATERAL_WAVE, amplitude, seconds)
	action.period = seconds
	action.phase = phase
	return then(action)

func speed_to(speed: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.make(BulletAction.Type.SPEED, speed, seconds))

func tint_to(color: Color, seconds: float) -> BulletBehavior:
	return then(BulletAction.tint_to(color, seconds))

func opacity_to(alpha: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.make(BulletAction.Type.OPACITY, alpha, seconds))

func visual_scale_to(scale: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.visual_scale_to(scale, seconds))

func hitbox_scale_to(scale: float, seconds: float) -> BulletBehavior:
	return then(BulletAction.hitbox_scale_to(scale, seconds))

func parallel(group: Array[BulletAction]) -> BulletBehavior:
	var action := BulletAction.new()
	action.type = BulletAction.Type.PARALLEL
	action.children = group
	return then(action)

func repeat(times := 0) -> BulletBehavior:
	repeat_count = times
	return self

## Eases the most recently added action. For parallel groups ease each child with
## BulletAction.eased() instead.
func eased(transition: Tween.TransitionType, easing: Tween.EaseType = Tween.EASE_IN_OUT) -> BulletBehavior:
	if actions.is_empty() or actions[-1] == null or actions[-1].type == BulletAction.Type.PARALLEL:
		push_warning("BulletBehavior.eased() needs a preceding non-parallel action.")
		return self
	actions[-1].eased(transition, easing)
	return self

func validation_error() -> String:
	if actions.size() > 128 or repeat_count < 0 or repeat_count > 10000: return "Behavior exceeds action/repeat limits."
	var duration := 0.0
	for action in actions:
		if action == null: return "Null behavior action."
		var error := action.validation_error()
		if not error.is_empty(): return error
		duration += action.length()
	if repeat_count == 0 and duration < 0.1: return "Infinite behavior requires a cycle of at least 0.1s."
	return ""
