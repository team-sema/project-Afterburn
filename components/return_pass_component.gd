class_name ReturnPassComponent
extends Node

## Evolved Interceptor: once its pass has left the screen, it detaches, holds just
## offscreen behind an edge warning, then runs back along the reversed lane and
## opens another fire window.

const RETURN_RUN: MovementSequence = preload(
	"res://resources/enemy_movement/sequences/interceptor_attack_run.tres"
)

@export_range(0, 3, 1) var return_passes := 1
## Offscreen hold before the return run; the edge warning lasts the same time.
@export_range(0.1, 3.0, 0.05, "suffix:s") var turn_delay := 0.6
## How far past the visible edge the actor travels before it turns.
@export_range(0.0, 64.0, 1.0, "suffix:px") var exit_margin := 12.0

var enemy: Enemy
var _shoot: EnemyShootComponent
var _passes_done := 0
var _holding := false
var _hold_elapsed := 0.0
var _return_direction := Vector2.ZERO


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "ReturnPassComponent must be attached directly to an Enemy.")
	_shoot = enemy.get_node_or_null("EnemyShootComponent") as EnemyShootComponent
	assert(_shoot != null, "ReturnPassComponent requires a visible-entry EnemyShootComponent.")


func get_passes_done() -> int:
	return _passes_done


func is_holding() -> bool:
	return _holding


func _process(delta: float) -> void:
	if _holding:
		_hold_elapsed += delta
		if _hold_elapsed >= turn_delay:
			_start_return_run()
		return
	if _passes_done >= return_passes:
		return
	if not _shoot.has_visible_pass_started() or _shoot.is_fire_window_active():
		return
	if enemy.get_viewport_rect().grow(exit_margin).has_point(enemy.global_position):
		return
	_begin_hold()


func _begin_hold() -> void:
	# Local +Y is the run's forward axis; the return retraces the lane backward.
	_return_direction = -Vector2.DOWN.rotated(enemy.global_rotation)
	enemy.detach_from_formation()
	enemy.movement_controller.clear_sequence()
	enemy.move_component.stop_motion()
	_holding = true
	_hold_elapsed = 0.0
	var warning := EntryWarningComponent.new()
	warning.actor = enemy
	warning.entry_direction = Vector2.RIGHT if _return_direction.x >= 0.0 else Vector2.LEFT
	warning.face_spawn_side = true
	warning.warning_duration = turn_delay
	enemy.add_child(warning)


func _start_return_run() -> void:
	_holding = false
	_passes_done += 1
	_shoot.rearm_visible_entry()
	enemy.set_movement_sequence(RETURN_RUN, {"attack_run_direction": _return_direction})
