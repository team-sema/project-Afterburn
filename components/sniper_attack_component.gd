class_name SniperAttackComponent
extends Node

## Sniper combat loop after positioning: AIMING → FIRING → COOLDOWN (repeat).
## Telegraph is a scene child (BombBlastPreview pattern). Laser spawns into
## gameplay_world like EnemyShootComponent projectiles.

enum CombatState {
	POSITIONING,
	AIMING,
	FIRING,
	COOLDOWN,
}

@export var aim_cone: SniperAimCone
@export_range(0.5, 20.0, 0.05) var aim_duration := 4.0
@export_range(0.05, 5.0, 0.05) var laser_duration := 0.5
@export_range(0.1, 20.0, 0.05) var cooldown_duration := 2.5
@export_range(1.0, 90.0, 0.5) var telegraph_start_angle := 42.0
@export_range(0.1, 30.0, 0.1) var telegraph_end_angle := 1.2
@export_range(1.0, 24.0, 0.5) var laser_width := 4.0
@export_range(64.0, 800.0, 1.0) var laser_range := 480.0
@export_range(1, 20, 1) var laser_damage := 1
@export var laser_scene: PackedScene

var enemy: Enemy
var _state := CombatState.POSITIONING
var _state_elapsed := 0.0
var _aim_direction := Vector2.DOWN
var _base_aim_duration := 4.0
var _base_cooldown_duration := 2.5
var _active_laser: SniperLaserBeam
var _shots_fired := 0
var _hold_position := Vector2.ZERO
var _hold_locked := false


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "SniperAttackComponent must be attached to an Enemy.")
	_base_aim_duration = aim_duration
	_base_cooldown_duration = cooldown_duration
	if aim_cone == null:
		aim_cone = enemy.get_node_or_null("SniperAimCone") as SniperAimCone
	assert(aim_cone != null, "SniperAttackComponent requires a SniperAimCone sibling.")
	aim_cone.hide_telegraph()
	aim_cone.set_cone_length(laser_range)
	_face_visual_direction(Vector2.DOWN)

	var movement := enemy.get_node_or_null("MovementController") as MovementController
	if movement != null:
		if not movement.step_started.is_connected(_on_movement_step_started):
			movement.step_started.connect(_on_movement_step_started)
		call_deferred("_sync_positioning_from_movement")


func apply_action_rate_multiplier(multiplier: float) -> void:
	var rate := maxf(0.01, multiplier)
	aim_duration = _base_aim_duration / rate
	cooldown_duration = _base_cooldown_duration / rate


func set_combat_timings(aim: float, laser: float, cooldown: float) -> void:
	_base_aim_duration = maxf(0.05, aim)
	_base_cooldown_duration = maxf(0.05, cooldown)
	aim_duration = _base_aim_duration
	laser_duration = maxf(0.05, laser)
	cooldown_duration = _base_cooldown_duration


func get_combat_state() -> CombatState:
	return _state


func get_shots_fired() -> int:
	return _shots_fired


func get_aim_direction() -> Vector2:
	return _aim_direction


func is_telegraph_visible() -> bool:
	return aim_cone != null and aim_cone.visible


func has_active_laser() -> bool:
	return is_instance_valid(_active_laser)


func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _state == CombatState.POSITIONING:
		_sync_positioning_from_movement()
	if _hold_locked:
		enemy.global_position = _hold_position

	match _state:
		CombatState.POSITIONING:
			pass
		CombatState.AIMING:
			_update_aiming(delta)
		CombatState.FIRING:
			_state_elapsed += delta
			if _state_elapsed >= laser_duration:
				_enter_cooldown()
		CombatState.COOLDOWN:
			_state_elapsed += delta
			if _state_elapsed >= cooldown_duration:
				_enter_aiming()


func _on_movement_step_started(_step_index: int, step: MovementStep) -> void:
	if step is HoldPositionMovementStep and _state == CombatState.POSITIONING:
		_begin_hold_and_aim()


func _sync_positioning_from_movement() -> void:
	if _state != CombatState.POSITIONING or enemy == null:
		return
	# Formation escorts skip individual HoldPosition; start aiming in place.
	if enemy.is_formation_member():
		_hold_locked = false
		_enter_aiming()
		return
	var movement := enemy.get_node_or_null("MovementController") as MovementController
	if movement == null or not movement.is_running():
		return
	var index := movement.get_current_step_index()
	if index < 0 or movement.sequence == null:
		return
	if index >= movement.sequence.steps.size():
		return
	var step := movement.sequence.steps[index]
	if step is HoldPositionMovementStep:
		_begin_hold_and_aim()


func _begin_hold_and_aim() -> void:
	_hold_position = enemy.global_position
	_hold_locked = true
	_enter_aiming()


func _enter_aiming() -> void:
	if has_active_laser():
		_active_laser.queue_free()
		_active_laser = null
	_state = CombatState.AIMING
	_state_elapsed = 0.0
	_refresh_aim_direction()
	_face_visual_direction(_aim_direction)
	_apply_cone_transform()
	if aim_cone != null:
		aim_cone.set_cone_length(laser_range)
		aim_cone.set_half_angle_degrees(telegraph_start_angle)
		aim_cone.show_telegraph()


func _update_aiming(delta: float) -> void:
	_state_elapsed += delta
	_refresh_aim_direction()
	var progress := clampf(_state_elapsed / maxf(0.05, aim_duration), 0.0, 1.0)
	var half_angle := lerpf(telegraph_start_angle, telegraph_end_angle, progress)
	_apply_cone_transform()
	if aim_cone != null:
		aim_cone.set_half_angle_degrees(half_angle)
	if _state_elapsed >= aim_duration:
		_enter_firing()


func _enter_firing() -> void:
	# Final AIMING-frame direction keeps telegraph and laser aligned.
	_refresh_aim_direction()
	_apply_cone_transform()
	if aim_cone != null:
		aim_cone.hide_telegraph()
	_state = CombatState.FIRING
	_state_elapsed = 0.0
	_spawn_laser(_aim_direction)
	_shots_fired += 1


func _enter_cooldown() -> void:
	if aim_cone != null:
		aim_cone.hide_telegraph()
	_state = CombatState.COOLDOWN
	_state_elapsed = 0.0


func _refresh_aim_direction() -> void:
	var player := _get_player()
	if player == null:
		_aim_direction = Vector2.DOWN
	else:
		_aim_direction = enemy.global_position.direction_to(player.global_position)
		if _aim_direction.length_squared() < 0.0001:
			_aim_direction = Vector2.DOWN
	if _state == CombatState.AIMING or _state == CombatState.FIRING:
		_face_visual_direction(_aim_direction)


func _face_visual_direction(direction: Vector2) -> void:
	## Same pattern as Awl: rotate Anchor art toward aim, leave root unrotated.
	if enemy == null or direction.is_zero_approx():
		return
	var visual_anchor := enemy.get_node_or_null("Anchor") as Node2D
	if visual_anchor != null:
		visual_anchor.global_rotation = direction.angle() - PI * 0.5


func _apply_cone_transform() -> void:
	if aim_cone == null or not is_instance_valid(aim_cone):
		return
	# Cone is a child of the enemy (BombBlastPreview pattern): local aim only.
	aim_cone.position = Vector2.ZERO
	aim_cone.rotation = _aim_direction.angle() - PI * 0.5


func _spawn_laser(direction: Vector2) -> void:
	if has_active_laser():
		return
	# Same parenting path as EnemyShootComponent projectiles.
	var projectile_parent := get_tree().get_first_node_in_group("gameplay_world")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	if projectile_parent == null:
		return
	var laser: SniperLaserBeam
	if laser_scene != null:
		laser = laser_scene.instantiate() as SniperLaserBeam
	else:
		laser = SniperLaserBeam.new()
	if laser == null:
		return
	laser.global_position = enemy.global_position
	_active_laser = laser
	laser.finished.connect(_on_laser_finished, CONNECT_ONE_SHOT)
	# Mirror EnemyShootComponent: defer enter-tree, then apply launch-equivalent setup.
	projectile_parent.add_child.call_deferred(laser)
	laser.call_deferred(
		"configure",
		enemy.global_position,
		direction,
		laser_duration,
		laser_width,
		laser_range,
		laser_damage,
	)


func _on_laser_finished() -> void:
	_active_laser = null


func _get_player() -> Node2D:
	var targeting := enemy.get_node_or_null("TargetingComponent") as TargetingComponent
	if targeting != null:
		var target := targeting.get_target()
		if target != null and is_instance_valid(target):
			return target
		var found := get_tree().get_first_node_in_group("player") as Node2D
		if found != null:
			targeting.change_target(found)
			return found
	return get_tree().get_first_node_in_group("player") as Node2D


func _exit_tree() -> void:
	if is_instance_valid(_active_laser):
		_active_laser.queue_free()
		_active_laser = null
	if aim_cone != null and is_instance_valid(aim_cone):
		aim_cone.hide_telegraph()
