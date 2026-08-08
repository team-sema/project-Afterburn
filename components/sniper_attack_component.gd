class_name SniperAttackComponent
extends Node

## Sniper combat loop after positioning: AIMING → FIRING → COOLDOWN (repeat).
## Telegraph is a scene child (BombBlastPreview pattern). The bullet spawns into
## gameplay_world like EnemyShootComponent projectiles.

enum CombatState {
	POSITIONING,
	AIMING,
	FIRING,
	COOLDOWN,
}

@export var aim_cone: SniperAimCone
@export_range(0.5, 20.0, 0.05) var aim_duration := 4.0
@export_range(0.0, 1.0, 0.01) var focus_hold_duration := 0.18
@export_range(0.05, 5.0, 0.05) var shot_recovery_duration := 0.1
@export_range(0.1, 20.0, 0.05) var cooldown_duration := 2.5
@export_range(1.0, 45.0, 0.5) var telegraph_start_angle := 14.0
@export_range(0.0, 15.0, 0.05) var telegraph_end_angle := 0.05
@export_range(100.0, 2000.0, 10.0) var projectile_speed := 900.0
@export_range(1.0, 12.0, 0.5) var projectile_width := 3.0
@export_range(64.0, 800.0, 1.0) var projectile_range := 480.0
@export_range(1, 20, 1) var projectile_damage := 1
@export var projectile_scene: PackedScene
@export_range(0.0, 16.0, 0.5) var recoil_distance := 5.0
@export_range(0.01, 0.2, 0.01) var recoil_kick_duration := 0.05
@export_range(0.05, 0.5, 0.01) var recoil_return_duration := 0.18

var enemy: Enemy
var _state := CombatState.POSITIONING
var _state_elapsed := 0.0
var _aim_direction := Vector2.DOWN
var _base_aim_duration := 4.0
var _base_focus_hold_duration := 0.18
var _base_cooldown_duration := 2.5
var _active_bullet: SniperBullet
var _shots_fired := 0
var _hold_position := Vector2.ZERO
var _hold_locked := false
var _visual_anchor: Node2D
var _visual_anchor_rest_position := Vector2.ZERO
var _recoil_tween: Tween


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "SniperAttackComponent must be attached to an Enemy.")
	_base_aim_duration = aim_duration
	_base_focus_hold_duration = focus_hold_duration
	_base_cooldown_duration = cooldown_duration
	if aim_cone == null:
		aim_cone = enemy.get_node_or_null("SniperAimCone") as SniperAimCone
	assert(aim_cone != null, "SniperAttackComponent requires a SniperAimCone sibling.")
	_visual_anchor = enemy.get_node_or_null("Anchor") as Node2D
	if _visual_anchor != null:
		_visual_anchor_rest_position = _visual_anchor.position
	aim_cone.hide_telegraph()
	aim_cone.set_cone_length(projectile_range)
	_face_visual_direction(Vector2.DOWN)

	var movement := enemy.get_node_or_null("MovementController") as MovementController
	if movement != null:
		if not movement.step_started.is_connected(_on_movement_step_started):
			movement.step_started.connect(_on_movement_step_started)
		call_deferred("_sync_positioning_from_movement")


func apply_action_rate_multiplier(multiplier: float) -> void:
	var rate := maxf(0.01, multiplier)
	aim_duration = _base_aim_duration / rate
	focus_hold_duration = _base_focus_hold_duration / rate
	cooldown_duration = _base_cooldown_duration / rate


func set_combat_timings(
	aim: float,
	shot_recovery: float,
	cooldown: float,
	focus_hold: float = -1.0,
) -> void:
	_base_aim_duration = maxf(0.05, aim)
	_base_cooldown_duration = maxf(0.05, cooldown)
	if focus_hold >= 0.0:
		_base_focus_hold_duration = focus_hold
	aim_duration = _base_aim_duration
	focus_hold_duration = _base_focus_hold_duration
	shot_recovery_duration = maxf(0.05, shot_recovery)
	cooldown_duration = _base_cooldown_duration


func get_combat_state() -> CombatState:
	return _state


func get_shots_fired() -> int:
	return _shots_fired


func get_aim_direction() -> Vector2:
	return _aim_direction


func is_telegraph_visible() -> bool:
	return aim_cone != null and aim_cone.visible


func has_active_bullet() -> bool:
	return is_instance_valid(_active_bullet)


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
			if _state_elapsed >= shot_recovery_duration:
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
	_state = CombatState.AIMING
	_state_elapsed = 0.0
	_refresh_aim_direction()
	_face_visual_direction(_aim_direction)
	_apply_cone_transform()
	if aim_cone != null:
		aim_cone.set_cone_length(projectile_range)
		aim_cone.set_half_angle_degrees(telegraph_start_angle)
		aim_cone.set_focus_progress(0.0)
		aim_cone.show_telegraph()


func _update_aiming(delta: float) -> void:
	_state_elapsed += delta
	_refresh_aim_direction()
	var progress := clampf(_state_elapsed / maxf(0.05, aim_duration), 0.0, 1.0)
	# Cubic ease-out: a sharp initial lock-on that settles flat at full focus.
	var focus_progress := 1.0 - pow(1.0 - progress, 3.0)
	var half_angle := lerpf(telegraph_start_angle, telegraph_end_angle, focus_progress)
	_apply_cone_transform()
	if aim_cone != null:
		aim_cone.set_half_angle_degrees(half_angle)
		aim_cone.set_focus_progress(focus_progress)
	if _state_elapsed >= aim_duration + focus_hold_duration:
		_enter_firing()


func _enter_firing() -> void:
	# Final AIMING-frame direction keeps the telegraph and bullet aligned.
	_refresh_aim_direction()
	_apply_cone_transform()
	if aim_cone != null:
		aim_cone.hide_telegraph()
	_state = CombatState.FIRING
	_state_elapsed = 0.0
	_spawn_bullet(_aim_direction)
	_play_recoil(_aim_direction)
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
	if _visual_anchor != null:
		_visual_anchor.global_rotation = direction.angle() - PI * 0.5


func _play_recoil(direction: Vector2) -> void:
	if _visual_anchor == null or direction.is_zero_approx() or recoil_distance <= 0.0:
		return
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_visual_anchor.position = _visual_anchor_rest_position
	var local_direction := direction.rotated(-enemy.global_rotation).normalized()
	var recoil_position := _visual_anchor_rest_position - local_direction * recoil_distance
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(
		_visual_anchor,
		"position",
		recoil_position,
		recoil_kick_duration,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(
		_visual_anchor,
		"position",
		_visual_anchor_rest_position,
		recoil_return_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_cone_transform() -> void:
	if aim_cone == null or not is_instance_valid(aim_cone):
		return
	# Cone is a child of the enemy (BombBlastPreview pattern): local aim only.
	aim_cone.position = Vector2.ZERO
	aim_cone.rotation = _aim_direction.angle() - PI * 0.5


func _spawn_bullet(direction: Vector2) -> void:
	if has_active_bullet():
		return
	# Same parenting path as EnemyShootComponent projectiles.
	var projectile_parent := get_tree().get_first_node_in_group("gameplay_world")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	if projectile_parent == null:
		return
	var bullet: SniperBullet
	if projectile_scene != null:
		bullet = projectile_scene.instantiate() as SniperBullet
	else:
		bullet = SniperBullet.new()
	if bullet == null:
		return
	bullet.global_position = enemy.global_position
	_active_bullet = bullet
	bullet.finished.connect(_on_bullet_finished, CONNECT_ONE_SHOT)
	# Mirror EnemyShootComponent: defer enter-tree, then apply launch-equivalent setup.
	projectile_parent.add_child.call_deferred(bullet)
	bullet.call_deferred(
		"configure",
		enemy.global_position,
		direction,
		projectile_speed,
		projectile_width,
		projectile_range,
		projectile_damage,
	)


func _on_bullet_finished() -> void:
	_active_bullet = null


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
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	if _visual_anchor != null and is_instance_valid(_visual_anchor):
		_visual_anchor.position = _visual_anchor_rest_position
	if aim_cone != null and is_instance_valid(aim_cone):
		aim_cone.hide_telegraph()
