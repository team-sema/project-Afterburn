extends "res://components/enemy_shoot_component.gd"

const WARNING = preload("res://components/entry_warning_component.gd")
enum Phase { ENTRY, RECOVERY, AIM, DASH, REENTRY_WARNING, REENTRY }

@export var dash_speed := 320.0
@export var entry_speed := 110.0
@export var aim_duration := 0.8
@export var recovery_duration := 1.2
@export var reentry_warning_duration := 0.7
## Nonzero seeds allow repeatable legacy/new comparisons without VFX RNG interference.
@export var shot_random_seed := 0
var _shot_rng := RandomNumberGenerator.new()

var phase := Phase.ENTRY
var dash_direction := Vector2.DOWN
var _elapsed := 0.0
var _shot_elapsed := 0.0
var _wake_elapsed := 0.0
var _action_rate := 1.0
var _hold_position := Vector2.ZERO
var _visual: Node2D
var _aim_locked := false
var _dash_intent := MovementIntent.new()


func _ready() -> void:
	if shot_random_seed == 0: _shot_rng.randomize()
	else: _shot_rng.seed = shot_random_seed
	super._ready()
	fire_timer.stop()
	_visual = enemy.get_node("ChargeVisual")
	enemy.get_node("EliteAimCone").hide()
	(enemy.get_node("VisibleOnScreenNotifier2D") as FreeOffscreenComponent).suspend_despawn()
	process_priority = 20
	set_process(true)


func apply_action_rate_multiplier(multiplier: float) -> void:
	_action_rate = maxf(0.01, multiplier)


func get_threat_projectile_rate() -> float:
	if phase != Phase.DASH:
		return 0.0
	return 2.0 / maxf(0.1, 0.18 / _action_rate)


func get_threat_reaction_time() -> float:
	if phase == Phase.AIM or phase == Phase.DASH:
		return aim_duration
	return -1.0


func _process(delta: float) -> void:
	if enemy.is_queued_for_deletion() or enemy.stats_component.health <= 0:
		return
	_elapsed += delta
	match phase:
		Phase.ENTRY:
			if enemy.is_formation_member() or enemy.movement_controller.get_current_step_index() < 1:
				return
			enemy.movement_controller.stop()
			_begin_recovery()
		Phase.RECOVERY:
			enemy.global_position = _hold_position
			_track_player(delta)
			if _elapsed >= recovery_duration:
				_begin_aim()
		Phase.AIM:
			enemy.global_position = _hold_position
			if not _aim_locked:
				_track_player(delta)
				if _elapsed >= maxf(0.0, aim_duration - 0.18):
					_aim_locked = true
					_visual.locked = true
			if _elapsed >= aim_duration:
				_visual.aiming = false
				phase = Phase.DASH
				_shot_elapsed = 0.0
				_wake_elapsed = 0.0
		Phase.DASH:
			# Substeps keep side shots along the path even on a slower frame.
			var remaining := delta
			while remaining > 0.0 and phase == Phase.DASH:
				var step := minf(remaining, 0.025)
				_advance_dash(step)
				remaining -= step
		Phase.REENTRY_WARNING:
			if _elapsed >= reentry_warning_duration:
				phase = Phase.REENTRY
		Phase.REENTRY:
			var destination := Vector2(enemy.global_position.x, enemy.get_viewport_rect().position.y + 72.0)
			enemy.global_position = enemy.global_position.move_toward(destination, entry_speed * _speed_multiplier() * delta)
			if enemy.global_position.is_equal_approx(destination):
				_begin_recovery()


func _begin_recovery() -> void:
	phase = Phase.RECOVERY
	_elapsed = 0.0
	_hold_position = enemy.global_position
	dash_direction = Vector2.DOWN
	_face(Vector2.DOWN)


func _begin_aim() -> void:
	phase = Phase.AIM
	_elapsed = 0.0
	_aim_locked = false
	_visual.aiming = true
	_visual.locked = false
	_visual.direction = dash_direction


func _track_player(delta: float) -> void:
	var target_direction := targeting_component.get_direction_from(enemy.global_position)
	if target_direction.is_zero_approx():
		target_direction = Vector2.DOWN
	var angle := lerp_angle(dash_direction.angle(), target_direction.angle(), 1.0 - exp(-10.0 * delta))
	dash_direction = Vector2.from_angle(angle)
	_face(dash_direction)
	_visual.direction = dash_direction


func _advance_dash(delta: float) -> void:
	_dash_intent.reset()
	_dash_intent.set_velocity(dash_direction * dash_speed)
	enemy.move_component.apply_movement_intent(_dash_intent, delta)
	var bounds := enemy.get_viewport_rect()
	if not bounds.grow(48.0).has_point(enemy.global_position):
		_begin_reentry_warning()
		return
	_wake_elapsed += delta
	if _wake_elapsed >= 0.025:
		_wake_elapsed -= 0.025
		if bounds.has_point(enemy.global_position):
			_visual.emit_wake(enemy.global_position - dash_direction * 14.0, dash_direction)
	_shot_elapsed += delta
	var interval := maxf(0.1, 0.18 / _action_rate)
	if _shot_elapsed >= interval:
		_shot_elapsed -= interval
		if bounds.has_point(enemy.global_position):
			var perpendicular := Vector2(-dash_direction.y, dash_direction.x)
			projectile_speed = _shot_rng.randf_range(90.0, 110.0)
			_fire_projectiles(perpendicular.rotated(_shot_rng.randf_range(-0.24, 0.24)))
			projectile_speed = _shot_rng.randf_range(90.0, 110.0)
			_fire_projectiles((-perpendicular).rotated(_shot_rng.randf_range(-0.24, 0.24)))


func _begin_reentry_warning() -> void:
	phase = Phase.REENTRY_WARNING
	_elapsed = 0.0
	var bounds := enemy.get_viewport_rect()
	var lane := 0.75 if enemy.global_position.x < bounds.get_center().x else 0.25
	enemy.global_position = Vector2(bounds.position.x + bounds.size.x * lane, bounds.position.y - 64.0)
	_face(Vector2.DOWN)
	var warning := WARNING.new()
	warning.actor = enemy
	warning.warning_duration = reentry_warning_duration
	warning.warning_color = Color(1.0, 0.25, 0.42, 0.95)
	enemy.add_child(warning)


func _face(direction: Vector2) -> void:
	var angle := direction.angle() - PI * 0.5
	(enemy.get_node("Anchor") as Node2D).rotation = angle
	(enemy.get_node("HurtboxComponent") as Node2D).rotation = angle
	(enemy.get_node("HitboxComponent") as Node2D).rotation = angle


func _speed_multiplier() -> float:
	return maxf(0.01, enemy.move_component.velocity_multiplier)
