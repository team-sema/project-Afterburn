extends "res://components/enemy_shoot_component.gd"

const PHASE_PATTERN = preload("res://patterns/elite_fighter_pattern.gd")
enum Phase { ENTRY, FAN, AIM, BURST, RECOVERY }
var phase := Phase.ENTRY
var _remaining := 0.0
var _action_rate := 1.0
var _locked_direction := Vector2.DOWN
var _cone: Node2D

func _ready() -> void:
	super._ready()
	fire_timer.stop()
	_cone = enemy.get_node("EliteAimCone")
	barrage_player = BarragePlayer.new()
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
	var gap := 0.13 if phase == Phase.BURST else 0.34
	var minimum := 0.08 if phase == Phase.BURST else 0.18
	barrage_player.time_scale = gap / maxf(minimum, gap / _action_rate)

func get_threat_projectile_rate() -> float:
	if phase == Phase.ENTRY: return 0.0
	var cycle := 0.45 + 3.0 * maxf(0.18, 0.34 / _action_rate) + 1.0
	cycle += 9.0 * maxf(0.08, 0.13 / _action_rate) + maxf(1.0, 1.6 / _action_rate)
	return 50.0 / maxf(0.05, cycle)

func get_threat_reaction_time() -> float:
	if phase == Phase.AIM or phase == Phase.BURST: return 1.0
	return super.get_threat_reaction_time()

func _process(delta: float) -> void:
	if enemy.is_queued_for_deletion() or enemy.stats_component.health <= 0:
		barrage_player.stop()
		_cone.hide_telegraph()
		return
	if phase == Phase.ENTRY:
		if enemy.movement_controller.get_current_step_index() < 1: return
		_begin_fan()
	if barrage_player.running:
		# Advance on the actor clock; never double-tick in physics.
		barrage_player.advance(delta)
		return
	_remaining -= delta
	if _remaining > 0: return
	match phase:
		Phase.FAN: _play_phase(false)
		Phase.AIM: _begin_burst()
		Phase.RECOVERY: _begin_fan()

func _begin_fan() -> void:
	phase = Phase.FAN
	_remaining = 0.45
	enemy.movement_controller.set_process(true)

func _begin_burst() -> void:
	_cone.hide_telegraph()
	phase = Phase.BURST
	_play_phase(true)

func _play_phase(focused: bool) -> void:
	var sequence := PHASE_PATTERN.new()
	sequence.build({"focused": focused, "extra_shots": maxi(0, shot_count - 1),
		"min_spread": spread_degrees, "angle": rad_to_deg(_locked_direction.angle() - PI * 0.5)})
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null: world = get_tree().current_scene as Node2D
	projectile_speed = 195.0 if focused else 145.0
	_update_phase_rate()
	if not barrage_player.play(sequence, enemy, world):
		push_error(barrage_player.last_error)
	barrage_player.set_physics_process(false)

func _phase_finished() -> void:
	if phase == Phase.FAN:
		phase = Phase.AIM
		_remaining = 1.0
		enemy.movement_controller.set_process(false)
		_locked_direction = targeting_component.get_direction_from(enemy.global_position)
		if _locked_direction.is_zero_approx(): _locked_direction = Vector2.DOWN
		_cone.rotation = _locked_direction.angle() - PI * 0.5
		_cone.set_half_angle_degrees(6.0)
		_cone.set_focus_progress(1.0)
		_cone.show_telegraph()
	elif phase == Phase.BURST:
		phase = Phase.RECOVERY
		_remaining = maxf(1.0, 1.6 / _action_rate)
		enemy.movement_controller.set_process(true)
