extends "res://components/enemy_shoot_component.gd"

const MINE = preload("res://components/elite_mine.gd")
const FIELD_PATTERN = preload("res://patterns/elite_bomb_pattern.gd")
const WARNING_COLOR := Color(1.0, 0.3, 0.3)
enum Phase { ENTRY, READY, THROW, RECOVERY, FIELD_WARNING, FIELD }

@export var mine_count := 3
@export var ready_duration := 0.6
@export var throw_interval := 0.3
@export var recovery_duration := 2.4
@export var flight_duration := 0.6
@export var arm_duration := 1.5
@export var blast_radius := 44.0
@export var lateral_offset := 72.0
@export var screen_margin := 24.0
@export var ring_shot: BarrageShot
@export var ring_count := 10
@export var ring_speed := 80.0
@export var ring_angle_step := 18.0
@export var field_warning_duration := 0.6

var phase := Phase.ENTRY
var mines: Array[Node2D] = []
var mines_thrown := 0
var _remaining := 0.0
var _thrown_in_cycle := 0
var _action_rate := 1.0
var _arming_rate := 1.0
## Patterns alternate: mine throw (A), then the orb minefield (B).
var next_is_field := false
var field_direction := Vector2.DOWN
var _warning_elapsed := 0.0


func _ready() -> void:
	super._ready()
	fire_timer.stop()
	enemy.get_node("EliteAimCone").hide()
	(enemy.get_node("StatsComponent") as StatsComponent).no_health.connect(clear_mines)
	enemy.tree_exiting.connect(clear_mines)
	barrage_player = BarragePlayer.new()
	add_child(barrage_player)
	barrage_player.volley_fired.connect(_pattern_fired)
	barrage_player.finished.connect(_field_finished)
	process_priority = 20
	set_process(true)


func apply_action_rate_multiplier(multiplier: float) -> void:
	_action_rate = maxf(0.01, multiplier)


func apply_arming_rate_multiplier(multiplier: float) -> void:
	_arming_rate *= maxf(0.01, multiplier)


func get_arm_duration() -> float:
	return maxf(0.8, arm_duration / _arming_rate)


func get_ring_count() -> int:
	return ring_count + maxi(0, shot_count - 1)


func _process(delta: float) -> void:
	if enemy.is_queued_for_deletion() or enemy.stats_component.health <= 0:
		barrage_player.stop()
		return
	if phase == Phase.ENTRY:
		if enemy.movement_controller.get_current_step_index() < 1:
			return
		phase = Phase.READY
		_remaining = ready_duration
	if barrage_player.running:
		# Advance on the actor clock; never double-tick in physics.
		barrage_player.advance(delta)
		return
	if phase == Phase.FIELD_WARNING:
		_warning_elapsed += delta
		_set_warning_flash(fmod(_warning_elapsed, 0.2) < 0.1)
	_remaining -= delta
	while _remaining <= 0.0 and not barrage_player.running:
		match phase:
			Phase.THROW:
				_throw_mine()
			Phase.FIELD_WARNING:
				_begin_field()
			_:
				if next_is_field:
					_begin_field_warning()
				else:
					phase = Phase.THROW
					_thrown_in_cycle = 0
					_throw_mine()


func _throw_mine() -> void:
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null: world = get_tree().current_scene as Node2D
	var mine := MINE.new()
	mine.start_position = enemy.global_position
	mine.landing_position = _landing_point(_thrown_in_cycle)
	mine.flight_duration = flight_duration
	mine.arm_duration = get_arm_duration()
	mine.blast_radius = blast_radius
	mine.ring_shot = ring_shot
	mine.ring_count = get_ring_count()
	mine.ring_speed = ring_speed
	mine.ring_angle_degrees = ring_angle_step * mines_thrown
	mine.detonated.connect(_on_mine_detonated)
	world.add_child(mine)
	mines.append(mine)
	mines_thrown += 1
	_thrown_in_cycle += 1
	if _thrown_in_cycle >= mine_count:
		phase = Phase.RECOVERY
		next_is_field = true
		_remaining += maxf(1.2, recovery_duration / _action_rate)
	else:
		_remaining += maxf(0.15, throw_interval / _action_rate)


## Centre first, then alternate left/right with growing offsets.
func _landing_point(index: int) -> Vector2:
	var target := targeting_component.get_target()
	var center := enemy.global_position + Vector2(0.0, 160.0)
	if is_instance_valid(target):
		center = target.global_position
	var side := 0 if index == 0 else (-1 if index % 2 == 1 else 1)
	var point := center + Vector2(side * lateral_offset * ceili(index / 2.0), 0.0)
	var bounds := enemy.get_viewport_rect().grow(-screen_margin)
	return point.clamp(bounds.position, bounds.end)


func _begin_field_warning() -> void:
	phase = Phase.FIELD_WARNING
	_warning_elapsed = 0.0
	_remaining += field_warning_duration
	enemy.movement_controller.set_process(false)
	var direction := targeting_component.get_direction_from(enemy.global_position)
	field_direction = Vector2.DOWN if direction.is_zero_approx() else direction
	_set_warning_flash(true)


func _begin_field() -> void:
	phase = Phase.FIELD
	_set_warning_flash(false)
	var sequence := FIELD_PATTERN.new()
	sequence.build({"angle": rad_to_deg(field_direction.angle() - PI * 0.5), "rate": _action_rate})
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null: world = get_tree().current_scene as Node2D
	if not barrage_player.play(sequence, enemy, world):
		push_error(barrage_player.last_error)
	barrage_player.set_physics_process(false)


func _field_finished() -> void:
	phase = Phase.RECOVERY
	next_is_field = false
	_remaining = maxf(1.2, recovery_duration / _action_rate)
	enemy.movement_controller.set_process(true)


func _set_warning_flash(enabled: bool) -> void:
	(enemy.get_node("Anchor") as Node2D).modulate = WARNING_COLOR if enabled else Color.WHITE


func _on_mine_detonated(mine: Node2D) -> void:
	mines.erase(mine)


## Undetonated mines vanish with their elite; already fired rings stay.
func clear_mines() -> void:
	for mine in mines:
		if is_instance_valid(mine):
			mine.queue_free()
	mines.clear()
