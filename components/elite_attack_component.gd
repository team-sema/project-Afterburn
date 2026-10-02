extends "res://components/enemy_shoot_component.gd"

const PHASE_PATTERN = preload("res://patterns/elite_fighter_pattern.gd")
enum Phase { ENTRY, SALVO, AIM, RAIL, RECOVERY, SCISSOR }
var phase := Phase.ENTRY
var _remaining := 0.0
var _action_rate := 1.0
var _locked_direction := Vector2.DOWN
## Patterns alternate: homing salvo + rail burst (A), then scissor crossfire (B).
var next_is_scissor := false
var _cone: Node2D

func _ready() -> void:
	super._ready()
	fire_timer.stop()
	_cone = enemy.get_node("EliteAimCone")
	barrage_player = BarragePlayer.new()
	barrage_player.resolve_target = _pattern_target
	add_child(barrage_player)
	barrage_player.volley_fired.connect(_pattern_fired)
	barrage_player.finished.connect(_phase_finished)
	process_priority = 20
	set_process(true)

func apply_action_rate_multiplier(multiplier: float) -> void:
	_action_rate = maxf(0.01, multiplier)
	_update_phase_rate()

func _update_phase_rate() -> void:
	if barrage_player == null: return
	var gap := 0.34
	var minimum := 0.18
	if phase == Phase.RAIL:
		gap = 0.13
		minimum = 0.08
	elif phase == Phase.SCISSOR:
		gap = 0.16
		minimum = 0.1
	barrage_player.time_scale = gap / maxf(minimum, gap / _action_rate)

func _process(delta: float) -> void:
	if enemy.is_queued_for_deletion() or enemy.stats_component.health <= 0:
		barrage_player.stop()
		_cone.hide_telegraph()
		return
	if phase == Phase.ENTRY:
		if enemy.movement_controller.get_current_step_index() < 1: return
		_begin_salvo()
	if barrage_player.running:
		# Advance on the actor clock; never double-tick in physics.
		barrage_player.advance(delta)
		return
	_remaining -= delta
	if _remaining > 0: return
	match phase:
		Phase.SALVO: _play_phase("salvo")
		Phase.AIM: _begin_rail()
		Phase.RECOVERY: _begin_scissor() if next_is_scissor else _begin_salvo()

func _begin_salvo() -> void:
	phase = Phase.SALVO
	_remaining = 0.45
	enemy.movement_controller.set_process(true)

func _begin_rail() -> void:
	_cone.hide_telegraph()
	phase = Phase.RAIL
	_play_phase("rail")

func _begin_scissor() -> void:
	phase = Phase.SCISSOR
	_locked_direction = _target_direction()
	_play_phase("scissor")

func _play_phase(mode: String) -> void:
	var sequence := PHASE_PATTERN.new()
	sequence.build({"mode": mode, "extra_shots": maxi(0, shot_count - 1),
		"min_spread": spread_degrees, "angle": rad_to_deg(_locked_direction.angle() - PI * 0.5)})
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null: world = get_tree().current_scene as Node2D
	_update_phase_rate()
	if not barrage_player.play(sequence, enemy, world):
		push_error(barrage_player.last_error)
	barrage_player.set_physics_process(false)

func _phase_finished() -> void:
	if phase == Phase.SALVO:
		phase = Phase.AIM
		_remaining = 1.0
		enemy.movement_controller.set_process(false)
		_locked_direction = _target_direction()
		_cone.rotation = _locked_direction.angle() - PI * 0.5
		_cone.set_half_angle_degrees(4.0)
		_cone.set_focus_progress(1.0)
		_cone.show_telegraph()
	elif phase == Phase.RAIL or phase == Phase.SCISSOR:
		next_is_scissor = phase == Phase.RAIL
		phase = Phase.RECOVERY
		_remaining = maxf(1.0, 1.6 / _action_rate)
		enemy.movement_controller.set_process(true)

func _target_direction() -> Vector2:
	var direction := targeting_component.get_direction_from(enemy.global_position)
	return Vector2.DOWN if direction.is_zero_approx() else direction
