extends "res://components/enemy_shoot_component.gd"

const PHASE_PATTERN = preload("res://patterns/elite_caster_pattern.gd")
const Spell = PHASE_PATTERN.Spell
enum Phase { ENTRY, READY, SPELL, REST }

@export var ready_duration := 0.6
@export var rest_duration := 1.4
@export var lane_spin_degrees := 9.0

var phase := Phase.ENTRY
var spell: int = Spell.BREATHING_RINGS
var cycle := 0
var reference_direction := Vector2.DOWN
var _remaining := 0.0
var _action_rate := 1.0


func _ready() -> void:
	super._ready()
	fire_timer.stop()
	enemy.get_node("EliteAimCone").hide()
	barrage_player = BarragePlayer.new()
	barrage_player.resolve_target = _pattern_target
	add_child(barrage_player)
	barrage_player.volley_fired.connect(_pattern_fired)
	barrage_player.finished.connect(_spell_finished)
	process_priority = 20
	set_process(true)


func apply_action_rate_multiplier(multiplier: float) -> void:
	_action_rate = maxf(0.01, multiplier)


func get_lane_spin() -> float:
	return lane_spin_degrees if cycle % 2 == 0 else -lane_spin_degrees


func _process(delta: float) -> void:
	if enemy.is_queued_for_deletion() or enemy.stats_component.health <= 0:
		barrage_player.stop()
		return
	if phase == Phase.ENTRY:
		if enemy.movement_controller.get_current_step_index() < 1: return
		phase = Phase.READY
		_remaining = ready_duration
	if barrage_player.running:
		# Advance on the actor clock; never double-tick in physics.
		barrage_player.advance(delta)
		return
	_remaining -= delta
	if _remaining <= 0 and phase != Phase.SPELL:
		_begin_spell()


func _begin_spell() -> void:
	phase = Phase.SPELL
	var direction := targeting_component.get_direction_from(enemy.global_position)
	reference_direction = Vector2.DOWN if direction.is_zero_approx() else direction
	var sequence := PHASE_PATTERN.new()
	sequence.build({"spell": spell, "angle": rad_to_deg(reference_direction.angle() - PI * 0.5),
		"spin": get_lane_spin(), "extra_shots": maxi(0, shot_count - 1), "rate": _action_rate})
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null: world = get_tree().current_scene as Node2D
	if not barrage_player.play(sequence, enemy, world):
		push_error(barrage_player.last_error)
	barrage_player.set_physics_process(false)


func _spell_finished() -> void:
	phase = Phase.REST
	_remaining = maxf(0.8, rest_duration / _action_rate)
	if spell == Spell.HALT_AND_AIM:
		cycle += 1
	spell = (spell + 1) % 3
