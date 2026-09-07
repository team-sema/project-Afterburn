extends "res://components/enemy_shoot_component.gd"

enum Phase { ENTRY, FAN, AIM, BURST, RECOVERY }

var phase := Phase.ENTRY
var _remaining := 0.0
var _volley := 0
var _action_rate := 1.0
var _locked_direction := Vector2.DOWN
var _cone: Node2D


func _ready() -> void:
	super._ready()
	fire_timer.stop()
	_cone = enemy.get_node("EliteAimCone")
	process_priority = 20
	set_process(true)


func apply_action_rate_multiplier(multiplier: float) -> void:
	_action_rate = maxf(0.01, multiplier)


func _process(delta: float) -> void:
	if enemy.is_queued_for_deletion() or enemy.stats_component.health <= 0:
		return
	if phase == Phase.ENTRY:
		if enemy.movement_controller.get_current_step_index() < 1:
			return
		_begin_fan()
	_remaining -= delta
	if _remaining > 0.0:
		return
	match phase:
		Phase.FAN:
			var sweep := lerpf(-18.0, 18.0, float(_volley) / 3.0)
			_shoot(Vector2.DOWN.rotated(deg_to_rad(sweep)), 5, 76.0, 145.0)
			_volley += 1
			_remaining = maxf(0.18, 0.34 / _action_rate)
			if _volley >= 4:
				phase = Phase.AIM
				_remaining = 1.0
				enemy.movement_controller.set_process(false)
				_locked_direction = targeting_component.get_direction_from(enemy.global_position)
				if _locked_direction.is_zero_approx():
					_locked_direction = Vector2.DOWN
				_cone.rotation = _locked_direction.angle() - PI * 0.5
				_cone.set_half_angle_degrees(6.0)
				_cone.set_focus_progress(1.0)
				_cone.show_telegraph()
		Phase.AIM:
			_cone.hide_telegraph()
			phase = Phase.BURST
			_volley = 0
			_fire_burst_volley()
		Phase.BURST:
			_fire_burst_volley()
		Phase.RECOVERY:
			_begin_fan()


func _begin_fan() -> void:
	phase = Phase.FAN
	_volley = 0
	_remaining = 0.45
	enemy.movement_controller.set_process(true)


func _fire_burst_volley() -> void:
	_shoot(_locked_direction, 3, 12.0, 195.0)
	_volley += 1
	_remaining = maxf(0.08, 0.13 / _action_rate)
	if _volley >= 10:
		phase = Phase.RECOVERY
		_remaining = maxf(1.0, 1.6 / _action_rate)
		enemy.movement_controller.set_process(true)


func _shoot(direction: Vector2, count: int, spread: float, speed: float) -> void:
	# Preserve extra pellets granted by enemy behavior augments.
	var baseline_count := shot_count
	var baseline_spread := spread_degrees
	shot_count = count + maxi(0, baseline_count - 1)
	spread_degrees = maxf(spread, baseline_spread)
	projectile_speed = speed
	_fire_projectiles(direction)
	shot_count = baseline_count
	spread_degrees = baseline_spread
