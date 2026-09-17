class_name BarrageSequence
extends Resource
## Builder and saved Resource use the same representation. repeat(0) loops forever.

@export var steps: Array[BarrageStep] = []
@export_range(0, 100000) var repeat_count := 1

## Optional hook for .gd patterns: EnemyShootComponent calls build(pattern_params)
## after _init(); the Lab passes an empty Dictionary, so read every key with a default.
func build(_params: Dictionary) -> void:
	pass

func snapshot() -> BarrageSequence:
	# Never duplicate the derived sequence: its constructor may append steps.
	var copy := BarrageSequence.new()
	copy.repeat_count = repeat_count
	for step in steps:
		copy.steps.append(clone_settings(step) as BarrageStep)
	return copy

## Copies every barrage setting Resource (including external presets) so a
## running pattern ignores later edits, but shares textures and other assets:
## the batch renderer and trail manager group projectiles by texture RID, so a
## duplicated texture would split every emitter into its own draw call.
static func clone_settings(resource: Resource) -> Resource:
	if resource == null or not _is_setting(resource):
		return resource
	var copy := resource.duplicate()
	for property in copy.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE == 0 or property.name == "script":
			continue
		var value = copy.get(property.name)
		if value is Resource:
			copy.set(property.name, clone_settings(value))
		elif value is Array:
			var items: Array = value.duplicate()
			for index in items.size():
				if items[index] is Resource:
					items[index] = clone_settings(items[index])
			copy.set(property.name, items)
	return copy

static func _is_setting(resource: Resource) -> bool:
	return (resource is BarrageStep or resource is BarrageVolley or resource is BarrageShot
		or resource is BulletAppearance or resource is BulletBehavior or resource is BulletAction
		or resource is BulletTrailEffect)

func emission_summary() -> Dictionary:
	var count := 0
	var seconds := 0.0
	var speed := 0.0
	for step in steps:
		if step.action == BarrageStep.Action.WAIT:
			seconds += step.value
		elif step.action == BarrageStep.Action.FIRE:
			for volley in step.get_volleys():
				count += 1 if volley.layout == BarrageVolley.Layout.SINGLE else volley.count
				speed = maxf(speed, volley.speed)
	return {"rate": count / maxf(0.05, seconds), "speed": speed}

func fire(volley: BarrageVolley) -> BarrageSequence:
	var step := BarrageStep.new()
	step.volley = volley
	steps.append(step)
	return self

func wait(seconds: float) -> BarrageSequence:
	var step := BarrageStep.new()
	step.action = BarrageStep.Action.WAIT
	step.value = seconds
	steps.append(step)
	return self

func fire_together(volleys: Array[BarrageVolley]) -> BarrageSequence:
	var step := BarrageStep.new()
	step.volleys = volleys
	steps.append(step)
	return self

func fire_ring(shot: BarrageShot, count: int, speed := 95.0, angle_degrees := 0.0) -> BarrageSequence:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.RING
	volley.count = count
	volley.speed = speed
	volley.angle_degrees = angle_degrees
	return fire(volley)

func fire_fan(shot: BarrageShot, count: int, spread_degrees: float, speed := 95.0, angle_degrees := 0.0) -> BarrageSequence:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.FAN
	volley.count = count
	volley.spread_degrees = spread_degrees
	volley.speed = speed
	volley.angle_degrees = angle_degrees
	return fire(volley)

func rotate(degrees: float) -> BarrageSequence:
	var step := BarrageStep.new()
	step.action = BarrageStep.Action.ROTATE
	step.value = degrees
	steps.append(step)
	return self

## Sets the base angle absolutely; unlike rotate() it never accumulates across loops.
func rotate_to(degrees: float) -> BarrageSequence:
	var step := BarrageStep.new()
	step.action = BarrageStep.Action.ROTATE_TO
	step.value = degrees
	steps.append(step)
	return self

## Locks the emitter-to-target direction for later Aim.LOCKED volleys.
func aim() -> BarrageSequence:
	var step := BarrageStep.new()
	step.action = BarrageStep.Action.AIM
	steps.append(step)
	return self

## True when playback needs a target: aim() steps or any aimed volley.
func needs_target() -> bool:
	for step in steps:
		if step == null: continue
		if step.action == BarrageStep.Action.AIM: return true
		if step.action == BarrageStep.Action.FIRE:
			for volley in step.get_volleys():
				if volley != null and volley.aim != BarrageVolley.Aim.NONE: return true
	return false

func repeat(times := 0) -> BarrageSequence:
	repeat_count = times
	return self

func validation_error() -> String:
	if steps.is_empty() or steps.size() > 256 or repeat_count < 0 or repeat_count > 100000:
		return "A sequence needs 1..256 steps and a repeat count in 0..100000."
	var has_wait := false
	for step in steps:
		if step == null:
			return "Null sequence step."
		match step.action:
			BarrageStep.Action.FIRE:
				var count := 0
				if step.get_volleys().size() > 64: return "At most 64 simultaneous volleys."
				for volley in step.get_volleys():
					if volley == null or not volley.is_valid(): return "Invalid volley or projectile settings."
					count += 1 if volley.layout == BarrageVolley.Layout.SINGLE else volley.count
				if count > 4096: return "Simultaneous volleys exceed 4096 projectiles."
			BarrageStep.Action.WAIT:
				if not is_finite(step.value) or step.value < 0:
					return "Wait must be finite and nonnegative."
				has_wait = has_wait or step.value > 0
			BarrageStep.Action.ROTATE, BarrageStep.Action.ROTATE_TO:
				if not is_finite(step.value):
					return "Rotation must be finite."
			BarrageStep.Action.AIM:
				pass
			_:
				return "Unknown sequence action."
	if repeat_count == 0 and not has_wait:
		return "An infinite sequence requires a positive wait."
	return ""
