extends Enemy

## Awl-specific behavior. FormationController owns movement only while this
## enemy is bound. When the shared entry sequence finishes, each Awl requests
## its own detach, freezes, captures the player once after charging, and dashes.

enum BehaviorState {
	FORMATION,
	CHARGING,
	DASHING,
}

@export_range(0.0, 10.0, 0.05) var charge_duration := 3.0
@export var dash_movement_sequence: MovementSequence

var _behavior_state := BehaviorState.FORMATION
var _charge_elapsed := 0.0
var _charging_position := Vector2.ZERO
var _captured_target_position := Vector2.ZERO
var _formation_movement_controller: MovementController
var _aim_during_formation := false


func _enter_tree() -> void:
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		shoot.free()


func _process(delta: float) -> void:
	match _behavior_state:
		BehaviorState.FORMATION:
			_update_formation_aim()
		BehaviorState.CHARGING:
			# Charging owns a fixed world-space point. The formation center and
			# additive movement modifiers cannot pull this enemy after detach.
			global_position = _charging_position
			_update_charge_aim()
			_charge_elapsed += delta
			if _charge_elapsed >= charge_duration:
				_begin_dash()


func enter_formation_mode(controller: Node, slot: FormationSlot) -> void:
	super.enter_formation_mode(controller, slot)
	_behavior_state = BehaviorState.FORMATION
	_charge_elapsed = 0.0
	_aim_during_formation = false
	_face_visual_direction(Vector2.DOWN)
	_formation_movement_controller = (
		controller.get_node_or_null("MovementController") as MovementController
	)
	if _formation_movement_controller == null:
		return
	if not _formation_movement_controller.step_started.is_connected(
		_on_formation_step_started
	):
		_formation_movement_controller.step_started.connect(_on_formation_step_started)
	if not _formation_movement_controller.sequence_finished.is_connected(
		_on_formation_sequence_finished
	):
		_formation_movement_controller.sequence_finished.connect(
			_on_formation_sequence_finished
		)


func exit_formation_mode(
	_individual_sequence: MovementSequence,
	context: Dictionary = {},
) -> void:
	_disconnect_formation_signals()
	# The charge state machine owns the post-detach movement. A preset cannot
	# accidentally start a second individual sequence in the detach frame.
	super.exit_formation_mode(null, context)
	_begin_charging()


func is_charging() -> bool:
	return _behavior_state == BehaviorState.CHARGING


func is_dashing() -> bool:
	return _behavior_state == BehaviorState.DASHING


func get_captured_target_position() -> Vector2:
	return _captured_target_position


func _update_formation_aim() -> void:
	if not _aim_during_formation or not is_formation_member():
		return
	_face_toward_player()


func _update_charge_aim() -> void:
	_face_toward_player()


func _face_toward_player() -> void:
	var targeting := get_node_or_null("TargetingComponent") as TargetingComponent
	if targeting == null:
		return
	var target := targeting.get_target()
	if target == null or not is_instance_valid(target):
		return
	_face_visual_direction(global_position.direction_to(target.global_position))


func _on_formation_step_started(_step_index: int, step: MovementStep) -> void:
	_aim_during_formation = step is WaitMovementStep
	if not _aim_during_formation:
		_face_visual_direction(Vector2.DOWN)


func _on_formation_sequence_finished() -> void:
	if _behavior_state != BehaviorState.FORMATION or not is_formation_member():
		return
	# Each Awl makes this request independently. Detaching one member neither
	# breaks nor repacks the surviving formation.
	detach_from_formation()


func _begin_charging() -> void:
	_behavior_state = BehaviorState.CHARGING
	_aim_during_formation = false
	_charge_elapsed = 0.0
	_charging_position = global_position
	movement_controller.clear_sequence()
	move_component.stop_motion()


func _begin_dash() -> void:
	if _behavior_state != BehaviorState.CHARGING:
		return
	global_position = _charging_position
	_captured_target_position = global_position + Vector2.DOWN * 200.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		_captured_target_position = player.global_position
	var dash_direction := global_position.direction_to(_captured_target_position)
	if dash_direction.is_zero_approx():
		dash_direction = Vector2.DOWN
	_behavior_state = BehaviorState.DASHING
	_face_visual_direction(dash_direction)
	assert(dash_movement_sequence != null, "KamikazeEnemy requires a dash MovementSequence.")
	set_movement_sequence(
		dash_movement_sequence,
		{
			"player_direction": dash_direction,
			"locked_player_position": _captured_target_position,
		},
	)


func _disconnect_formation_signals() -> void:
	if _formation_movement_controller == null:
		return
	if is_instance_valid(_formation_movement_controller):
		if _formation_movement_controller.step_started.is_connected(
			_on_formation_step_started
		):
			_formation_movement_controller.step_started.disconnect(
				_on_formation_step_started
			)
		if _formation_movement_controller.sequence_finished.is_connected(
			_on_formation_sequence_finished
		):
			_formation_movement_controller.sequence_finished.disconnect(
				_on_formation_sequence_finished
			)
	_formation_movement_controller = null


func _face_visual_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	var visual_anchor := get_node_or_null("Anchor") as Node2D
	if visual_anchor != null:
		visual_anchor.global_rotation = direction.angle() - PI * 0.5
