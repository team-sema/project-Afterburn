class_name BulletBehavior
extends Resource

@export var actions: Array[BulletAction] = []
@export var repeat_count := 1 # Zero loops forever; empty is straight forever.

## Behavior-invariant facts every bullet state adopts instead of re-walking
## the actions per launch. Pure data (no RIDs), so caching it on file-backed
## presets is safe; builder edits invalidate it.
class Analysis extends RefCounted:
	var heading_actions: Array[BulletAction] = []
	var speed_actions: Array[BulletAction] = []
	var has_homing := false
	var has_lateral := false
	var constant_velocity := true
	var static_visuals := true
	var max_hitbox_scale := 1.0
	var prediction_step := 0.04
	var single_turn: BulletAction
	var single_wave: BulletAction
	var single_lateral: BulletAction
	var spawn_offsets: Array[Dictionary] = []
	var cycle_length := 0.0
	## TURN_TO aims at a world angle, so its state depends on the launch
	## direction; shared samples then key on it too.
	var uses_world_heading := false

var _runtime_analysis: Analysis
## Shared state samples, one table per launch key (speed, tint and, for
## world-heading Behaviors, direction): {key: {age: state}}. Bullets that share
## this Behavior instance and key read one sample per age instead of each
## evaluating it. Runtime only; never duplicated or saved.
var _sample_memos := {}
## Shared local-frame trajectories, {launch key: BulletBehaviorState.SharedPath}.
var _path_tables := {}

func runtime_analysis() -> Analysis:
	if _runtime_analysis == null:
		_runtime_analysis = _analyze()
	return _runtime_analysis

func _analyze() -> Analysis:
	var analysis := Analysis.new()
	for action in actions:
		var heading_action: BulletAction
		var speed_action: BulletAction
		var group: Array = action.children if action.type == BulletAction.Type.PARALLEL else [action]
		for child in group:
			if child.type == BulletAction.Type.HOMING: analysis.has_homing = true
			if child.type == BulletAction.Type.TURN_TO: analysis.uses_world_heading = true
			if child.channel() == "heading": heading_action = child
			if child.channel() == "speed": speed_action = child
			if child.type == BulletAction.Type.LATERAL_WAVE:
				analysis.has_lateral = true
			if child.channel() in ["heading", "speed"]:
				analysis.constant_velocity = false
			if child.type in [BulletAction.Type.TINT, BulletAction.Type.OPACITY, BulletAction.Type.VISUAL_SCALE, BulletAction.Type.HITBOX_SCALE, BulletAction.Type.TANGIBLE]:
				analysis.static_visuals = false
			if child.type == BulletAction.Type.HITBOX_SCALE:
				analysis.max_hitbox_scale = maxf(analysis.max_hitbox_scale, child.value)
			if child.type in [BulletAction.Type.HEADING_WAVE, BulletAction.Type.LATERAL_WAVE]:
				analysis.prediction_step = minf(analysis.prediction_step, child.period / 24.0)
		analysis.heading_actions.append(heading_action)
		analysis.speed_actions.append(speed_action)
	if repeat_count == 1 and actions.size() == 1 and actions[0].type == BulletAction.Type.TURN_AT:
		analysis.single_turn = actions[0]
	if actions.size() == 1 and actions[0].type == BulletAction.Type.HEADING_WAVE and actions[0].duration > 0:
		analysis.single_wave = actions[0]
	if actions.size() == 1 and actions[0].type == BulletAction.Type.LATERAL_WAVE and actions[0].duration > 0:
		analysis.single_lateral = actions[0]
	for action in actions:
		if action.type == BulletAction.Type.SPAWN:
			analysis.spawn_offsets.append({"offset": analysis.cycle_length, "action": action})
		analysis.cycle_length += action.length()
	return analysis

func then(action: BulletAction) -> BulletBehavior:
	actions.append(action)
	_runtime_analysis = null
	_sample_memos.clear()
	_path_tables.clear()
	return self

## The shared trajectory for one launch key (see _path_tables).
func shared_path(key: Array) -> BulletBehaviorState.SharedPath:
	var path: BulletBehaviorState.SharedPath = _path_tables.get(key)
	if path == null:
		path = BulletBehaviorState.SharedPath.new()
		_path_tables[key] = path
	return path

## The shared {age: state} table for one launch key (see _sample_memos).
func sample_memo(key: Array) -> Dictionary:
	var memo: Dictionary = _sample_memos.get(key, {})
	if memo.is_empty() and not _sample_memos.has(key):
		_sample_memos[key] = memo
	return memo

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

## Switches the hitbox off from this point (a ghost bullet): hits pass
## through, the bullet keeps moving. Fade it with opacity_to yourself.
func intangible() -> BulletBehavior:
	return then(BulletAction.set_tangible(false))

## Switches the hitbox back on. Restore opacity first so players can read it.
func tangible() -> BulletBehavior:
	return then(BulletAction.set_tangible(true))

func parallel(group: Array[BulletAction]) -> BulletBehavior:
	var action := BulletAction.new()
	action.type = BulletAction.Type.PARALLEL
	action.children = group
	return then(action)

## Fires `volley` from the bullet's current position and heading; `consume`
## removes the bullet afterwards (split). See BulletAction.SPAWN limits.
func spawn(volley: BarrageVolley, consume := false) -> BulletBehavior:
	return then(BulletAction.spawn(volley, consume))

## Fires several Volleys at once from the bullet's current position and heading,
## each with its own speed/angle/aim (SPAWN_MAX_COUNT bullets in total).
func spawn_together(volleys: Array[BarrageVolley], consume := false) -> BulletBehavior:
	return then(BulletAction.spawn_together(volleys, consume))

func has_spawn() -> bool:
	for action in actions:
		if action != null and action.type == BulletAction.Type.SPAWN:
			return true
	return false

## True when any Action (parallel children included) toggles the hitbox.
func has_tangible_toggle() -> bool:
	for action in actions:
		if action == null:
			continue
		var group: Array = action.children if action.type == BulletAction.Type.PARALLEL else [action]
		for child in group:
			if child != null and child.type == BulletAction.Type.TANGIBLE:
				return true
	return false

func has_homing() -> bool:
	for action in actions:
		if action == null:
			continue
		var group: Array = action.children if action.type == BulletAction.Type.PARALLEL else [action]
		for child in group:
			if child != null and child.type == BulletAction.Type.HOMING:
				return true
	return false

func repeat(times := 0) -> BulletBehavior:
	repeat_count = times
	_runtime_analysis = null
	_sample_memos.clear()
	_path_tables.clear()
	return self

## Eases the most recently added action. For parallel groups ease each child with
## BulletAction.eased() instead.
func eased(transition: Tween.TransitionType, easing: Tween.EaseType = Tween.EASE_IN_OUT) -> BulletBehavior:
	if actions.is_empty() or actions[-1] == null or actions[-1].type == BulletAction.Type.PARALLEL:
		push_warning("BulletBehavior.eased() needs a preceding non-parallel action.")
		return self
	actions[-1].eased(transition, easing)
	_sample_memos.clear()
	_path_tables.clear()
	return self

func validation_error() -> String:
	if actions.size() > 128 or repeat_count < 0 or repeat_count > 10000: return "Behavior exceeds action/repeat limits."
	var duration := 0.0
	var spawns := 0
	for action in actions:
		if action == null: return "Null behavior action."
		var error := action.validation_error()
		if not error.is_empty(): return error
		duration += action.length()
		if action.type == BulletAction.Type.SPAWN: spawns += 1
	if spawns > BulletAction.SPAWN_MAX_PER_BULLET:
		return "Behavior exceeds %d spawn actions." % BulletAction.SPAWN_MAX_PER_BULLET
	if repeat_count == 0 and duration < 0.1: return "Infinite behavior requires a cycle of at least 0.1s."
	return ""
