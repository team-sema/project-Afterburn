class_name MovementController
extends Node

const DEFAULT_MOVEMENT_SPACE: MovementSpaceConfig = preload(
	"res://resources/enemy_movement/default_movement_space.tres"
)

signal step_started(step_index: int, step: MovementStep)
signal step_finished(step_index: int, step: MovementStep)
signal sequence_finished
signal sequence_stopped

@export var actor: Node2D
@export var move_component: MoveComponent
@export var sequence: MovementSequence
@export var auto_start := true
@export var initial_context: Dictionary = {}
@export var movement_space_config: MovementSpaceConfig = DEFAULT_MOVEMENT_SPACE

var _context: Dictionary = {}
var _context_was_configured := false
var _current_step_index := -1
var _current_step_state: Dictionary = {}
var _current_step_active := false
var _running := false
var _finished := false
var _ready_complete := false
var _start_requested := false
var _start_generation := 0
var _auto_start_suppressed := false
var _intent := MovementIntent.new()


func _ready() -> void:
	assert(actor != null, "MovementController requires an actor.")
	assert(move_component != null, "MovementController requires MoveComponent.")
	assert(
		movement_space_config != null and movement_space_config.validate(),
		"MovementController requires a valid MovementSpaceConfig.",
	)
	_ready_complete = true
	set_process(false)
	if not _context_was_configured:
		_context = initial_context.duplicate(true)
	if _start_requested or (
		auto_start and sequence != null and not _auto_start_suppressed
	):
		_request_deferred_start()


func _process(delta: float) -> void:
	update_movement(delta)


func set_sequence(new_sequence: MovementSequence, context: Dictionary = {}) -> void:
	stop()
	sequence = new_sequence
	_context = initial_context.duplicate(true)
	_context.merge(context, true)
	_context_was_configured = true
	_finished = false


func clear_sequence() -> void:
	stop()
	sequence = null
	_context = initial_context.duplicate(true)
	_context_was_configured = false
	move_component.resume_legacy_motion()


func start() -> void:
	if sequence == null:
		push_error("MovementController cannot start without a MovementSequence.")
		return
	if not sequence.validate():
		return
	_auto_start_suppressed = false
	if not _ready_complete:
		_start_requested = true
		return
	_start_now()


## Schedules a generation-gated start. A later stop(), set_sequence(), or
## clear_sequence() in the same frame cancels this request safely.
func request_deferred_start() -> void:
	if sequence == null:
		push_error("MovementController cannot start without a MovementSequence.")
		return
	_auto_start_suppressed = false
	_request_deferred_start()


func _start_now() -> void:
	if _running:
		stop()
	if sequence == null or not sequence.validate():
		return
	_start_requested = false
	_auto_start_suppressed = false
	_finished = false
	_current_step_index = 0
	_running = true
	move_component.stop_motion()
	move_component.set_process(false)
	set_process(true)
	_begin_current_step()


func stop() -> void:
	_start_generation += 1
	_start_requested = false
	_auto_start_suppressed = true
	var was_running := _running
	if (
		_running
		and _current_step_active
		and _current_step_index >= 0
		and sequence != null
	):
		var step := sequence.steps[_current_step_index]
		step.stop(_build_context(), _current_step_state)
	_running = false
	_finished = false
	_current_step_active = false
	_current_step_index = -1
	_current_step_state = {}
	set_process(false)
	if move_component != null:
		move_component.stop_motion()
	if was_running:
		sequence_stopped.emit()


func restart() -> void:
	stop()
	start()


func update_movement(delta: float) -> void:
	if not _running or sequence == null:
		return
	if _current_step_index < 0 or _current_step_index >= sequence.steps.size():
		push_error("MovementController current step index is invalid: %d" % _current_step_index)
		stop()
		return
	var step := sequence.steps[_current_step_index]
	var context := _build_context()
	_intent.reset()
	step.update_movement(delta, context, _current_step_state, _intent)
	if not _intent.is_valid:
		push_error(
			"MovementStep did not provide an intent at index %d: %s"
			% [_current_step_index, step.resource_path]
		)
		stop()
		return
	move_component.apply_movement_intent(_intent, delta)
	if step.is_finished(_build_context(), _current_step_state):
		step.stop(_build_context(), _current_step_state)
		_current_step_active = false
		_advance_step()


func is_running() -> bool:
	return _running


func is_finished() -> bool:
	return _finished


func get_current_step_index() -> int:
	return _current_step_index


func get_context() -> Dictionary:
	return _context.duplicate(true)


func _begin_current_step() -> void:
	var step := sequence.steps[_current_step_index]
	_current_step_state = step.create_runtime_state()
	if _current_step_state == null:
		push_error("MovementStep returned null runtime state: %s" % step.resource_path)
		_current_step_state = {}
	_current_step_active = true
	step.start(_build_context(), _current_step_state)
	step_started.emit(_current_step_index, step)


func _advance_step() -> void:
	var completed_index := _current_step_index
	var completed_step := sequence.steps[completed_index]
	var generation := _start_generation
	step_finished.emit(completed_index, completed_step)
	if (
		generation != _start_generation
		or not _running
		or sequence == null
		or _current_step_index != completed_index
	):
		return
	_current_step_index += 1
	if _current_step_index >= sequence.steps.size():
		if sequence.loop:
			_current_step_index = 0
			_begin_current_step()
			return
		_running = false
		_finished = true
		_current_step_active = false
		_current_step_index = -1
		_current_step_state = {}
		move_component.stop_motion()
		move_component.resume_legacy_motion()
		set_process(false)
		sequence_finished.emit()
		return
	_begin_current_step()


func _request_deferred_start() -> void:
	_start_requested = true
	_start_generation += 1
	var generation := _start_generation
	_start_if_requested.call_deferred(generation)


func _start_if_requested(generation: int) -> void:
	if generation != _start_generation or not _start_requested:
		return
	_start_now()


func _build_context() -> Dictionary:
	var result := _context.duplicate(false)
	var modifier_offset := move_component.get_modifier_offset()
	result["actor"] = actor
	result["global_position"] = actor.global_position
	result["base_position"] = actor.global_position - modifier_offset
	result["modifier_offset"] = modifier_offset
	var visible_rect := actor.get_viewport_rect()
	result["viewport_rect"] = visible_rect
	result["visible_rect"] = visible_rect
	result["movement_area"] = movement_space_config.get_movement_area(visible_rect)
	result["combat_area"] = movement_space_config.get_combat_area(visible_rect)
	result["despawn_area"] = movement_space_config.get_despawn_area(visible_rect)
	result["speed_multiplier"] = move_component.velocity_multiplier
	var player := actor.get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		result["player_position"] = player.global_position
	return result
