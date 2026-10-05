class_name BarrageShot
extends Resource
## Serializable projectile recipe. No live projectile state belongs here.

## BEAM is appended last so saved Kind values keep their meaning.
enum Kind { BULLET, TRAIL_LASER, LEGACY, BEAM }
@export var kind: Kind = Kind.BULLET
@export var appearance: BulletAppearance
@export var behavior: BulletBehavior
@export var trail_effect: BulletTrailEffect
@export var turn_degrees := 70.0
@export var turn_duration := 1.5
@export var trail_duration := 1.4
@export var core_width := 6.0
@export var hit_width := 4.0
@export var lifetime := 5.0
## BEAM (TelegraphBeam): warning line without hitbox -> grow -> hold with
## hitbox (`hit_width`, visual `core_width`) -> fade. 0 length = to view edge.
@export var beam_warn_duration := 0.7
@export var beam_grow_duration := 0.1
@export var beam_hold_duration := 0.5
@export var beam_fade_duration := 0.15
@export var beam_warn_width := 1.5
@export var beam_length := 0.0
@export var beam_color := Color(1.0, 0.3, 0.5)
## Glow and sparks where the held beam ends (visual only).
@export var beam_impact := true
## Playfield walls this shot reflects off (BULLET / TRAIL_LASER). 0 = none.
@export_flags("Left", "Right", "Top", "Bottom") var bounce_walls := 0
## Bounces per bullet before it passes through; 0 = unlimited.
@export_range(0, 64) var bounce_count := 1

func is_valid() -> bool:
	if trail_effect != null and (not trail_effect.is_valid() or kind == Kind.LEGACY): return false
	if behavior != null and not behavior.validation_error().is_empty():
		return false
	# Spawning runs on the BULLET body only; a laser head never fires volleys.
	if behavior != null and kind != Kind.BULLET and behavior.has_spawn():
		return false
	if bounce_walls < 0 or bounce_walls > BulletWallBounce.ALL or bounce_count < 0 or bounce_count > 64:
		return false
	# Homing steers by the unreflected path, so it cannot be mixed with bounces.
	if bounce_walls != 0 and (kind not in [Kind.BULLET, Kind.TRAIL_LASER] or (behavior != null and behavior.has_homing())):
		return false
	match kind:
		Kind.BULLET:
			return appearance != null and appearance.is_valid() and behavior != null and is_finite(lifetime) and lifetime > 0
		Kind.LEGACY:
			return behavior == null # Comparison adapter has no Behavior runtime.
		Kind.TRAIL_LASER:
			return (is_finite(turn_degrees) and is_finite(turn_duration) and turn_duration >= 0
				and is_finite(trail_duration) and trail_duration > 0
				and is_finite(core_width) and core_width > 0
				and is_finite(hit_width) and hit_width > 0 and hit_width <= core_width
				and is_finite(lifetime) and lifetime > 0)
		Kind.BEAM:
			# A fixed straight beam has no Behavior runtime or particle trail.
			return (behavior == null and trail_effect == null
				and is_finite(beam_warn_duration) and beam_warn_duration >= 0
				and is_finite(beam_grow_duration) and beam_grow_duration >= 0
				and is_finite(beam_hold_duration) and beam_hold_duration > 0
				and is_finite(beam_fade_duration) and beam_fade_duration >= 0
				and is_finite(beam_warn_width) and beam_warn_width > 0
				and is_finite(core_width) and core_width > 0
				and is_finite(hit_width) and hit_width > 0 and hit_width <= core_width
				and is_finite(beam_length) and beam_length >= 0)
	return false

## `shared_config` is for SPAWN children only: this shot is then part of the
## parent's private, already validated Behavior copy, so bullets share it
## instead of copying and re-validating per bullet.
func spawn(parent: Node2D, origin: Vector2, direction: Vector2, speed: float, debug := false, target: Node2D = null, target_resolver := Callable(), shared_config := false) -> Node2D:
	if not (shared_config or is_valid()) or not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return null
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx() or not is_finite(speed) or speed < 0 or (kind == Kind.TRAIL_LASER and speed == 0):
		return null
	var projectile: Node2D
	match kind:
		Kind.BULLET:
			var bullet := preload("res://projectiles/foundation_bullet.tscn").instantiate() as FoundationBullet
			bullet.appearance = appearance
			bullet.behavior = behavior
			bullet.trail_effect = trail_effect
			bullet.lifetime = lifetime
			bullet.show_hitbox = debug
			bullet.shares_config = shared_config
			bullet.bounce_walls = bounce_walls
			bullet.bounce_count = bounce_count
			projectile = bullet
		Kind.TRAIL_LASER:
			var laser := preload("res://projectiles/curved_laser.tscn").instantiate() as CurvedLaser
			laser.turn_degrees = turn_degrees
			laser.behavior = behavior
			laser.shares_config = shared_config
			laser.trail_effect = trail_effect
			laser.turn_duration = turn_duration
			laser.trail_duration = trail_duration
			laser.core_width = core_width
			laser.hit_width = hit_width
			laser.lifetime = lifetime
			laser.show_hitbox = debug
			laser.bounce_walls = bounce_walls
			laser.bounce_count = bounce_count
			projectile = laser
		Kind.LEGACY:
			projectile = preload("res://projectiles/base_enemy_projectile.tscn").instantiate()
		Kind.BEAM:
			var beam := TelegraphBeam.new()
			beam.add_to_group(EnemyBullets.GROUP)
			beam.warn_duration = beam_warn_duration
			beam.grow_duration = beam_grow_duration
			beam.hold_duration = beam_hold_duration
			beam.fade_duration = beam_fade_duration
			beam.warn_width = beam_warn_width
			beam.core_width = core_width
			beam.hit_width = hit_width
			beam.beam_length = beam_length
			beam.color = beam_color
			beam.show_impact = beam_impact
			beam.show_hitbox = debug
			projectile = beam
	projectile.position = parent.to_local(origin)
	parent.add_child(projectile)
	if kind == Kind.LEGACY:
		var velocity := parent.global_transform.basis_xform_inv(direction.normalized() * speed)
		projectile.launch(velocity.normalized() if speed > 0 else direction, velocity.length())
	elif kind == Kind.BEAM:
		projectile.launch(direction, speed)
	else:
		projectile.launch(direction, speed)
		projectile.behavior_state.configure_homing(projectile, origin, target, target_resolver)
		if projectile is FoundationBullet:
			(projectile as FoundationBullet).set_spawn_target(target, target_resolver)
	return projectile if is_instance_valid(projectile) else null
