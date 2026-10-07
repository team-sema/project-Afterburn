class_name LaunchSequence
extends Node

## 런 시작 출격 연출 (docs/design/scene-flow.md 「런 시작 · 출격 시퀀스」).
## 점화(0~0.5s) → 연소(0.5~1.6s) → 정착(1.6~2.6s) → EncounterDirector 시작.
## Plays itself only when a current scene exists (same gate as the director),
## so tests that attach gameplay.tscn drive it with play() + advance().

signal launch_finished

const MUSIC_BUS := &"Music"
const MUFFLED_CUTOFF_HZ := 500.0
const OPEN_CUTOFF_HZ := 20500.0
const LAUNCH_SFX_PATH := "res://sounds/launch_burn.wav"

const IGNITION_END := 0.5
const BURN_END := 1.6
const SETTLE_END := 2.6
const RISE_START := 0.3
const CONTROL_UNLOCK := 1.8
const FILTER_OPEN_START := 0.6
const FILTER_OPEN_END := 1.4
const SFX_AT := 0.3
const START_BELOW_SCREEN := 40.0
const IGNITION_SPEED := 0.3
const BURST_SPEED := 7.0
const SHAKE_PX := 2.0
const FLAME_SCALE_Y := 3.0
const FLAME_SPEED_SCALE := 2.5

@export var ship: Node2D
@export var space_background: SpaceBackground
@export var encounter_director: Node
## Start on _ready when a current scene exists. Tests leave it off by not
## setting current_scene.
@export var autostart := true

var is_launching := false
var elapsed := 0.0
var _home_position := Vector2.ZERO
var _start_position := Vector2.ZERO
var _sfx_played := false
var _controls_unlocked := false
var _anchor: Node2D
var _flame: GPUParticles2D
var _move_input: MoveInputComponent
var _clamp: PositionClampComponent
var _weapon_loadout: Node


static func _find_music_low_pass() -> AudioEffectLowPassFilter:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus < 0:
		return null
	for index in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, index) as AudioEffectLowPassFilter
		if effect != null:
			return effect
	return null


static func set_music_cutoff(cutoff_hz: float) -> void:
	var low_pass := _find_music_low_pass()
	if low_pass != null:
		low_pass.cutoff_hz = cutoff_hz


static func set_music_muffled(muffled: bool) -> void:
	set_music_cutoff(MUFFLED_CUTOFF_HZ if muffled else OPEN_CUTOFF_HZ)


## -1 when the Music bus has no low-pass filter.
static func get_music_cutoff() -> float:
	var low_pass := _find_music_low_pass()
	return low_pass.cutoff_hz if low_pass != null else -1.0


func _ready() -> void:
	assert(ship != null, "LaunchSequence requires the Ship.")
	assert(space_background != null, "LaunchSequence requires the SpaceBackground.")
	set_process(false)
	_anchor = ship.get_node_or_null("Anchor") as Node2D
	_flame = ship.get_node_or_null("Anchor/EngineTrail") as GPUParticles2D
	_move_input = ship.get_node_or_null("MoveInputComponent") as MoveInputComponent
	_clamp = ship.get_node_or_null("PositionClampComponent") as PositionClampComponent
	_weapon_loadout = ship.get_node_or_null("PlayerWeaponLoadout")
	if autostart and get_tree().current_scene != null:
		play.call_deferred()


func play() -> void:
	if is_launching:
		return
	is_launching = true
	elapsed = 0.0
	_sfx_played = false
	_controls_unlocked = false
	_home_position = ship.position
	var viewport_height := ship.get_viewport_rect().size.y
	_start_position = Vector2(_home_position.x, viewport_height + START_BELOW_SCREEN)
	ship.position = _start_position
	_set_controls(false)
	if space_background != null:
		space_background.speed_scale = 0.0
	set_music_muffled(true)
	set_process(true)


func _process(delta: float) -> void:
	advance(delta)


## Steps the timeline by `delta` gameplay seconds (also used by tests).
func advance(delta: float) -> void:
	if not is_launching:
		return
	elapsed += delta
	_update_ship()
	_update_background()
	_update_audio()
	if elapsed >= CONTROL_UNLOCK and not _controls_unlocked:
		_controls_unlocked = true
		_set_controls(true)
	if elapsed >= SETTLE_END:
		_finish()


func _update_ship() -> void:
	var rise := clampf((elapsed - RISE_START) / (BURN_END - RISE_START), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - rise, 3.0)
	if not _controls_unlocked:
		ship.position = _start_position.lerp(_home_position, eased)
	var burn := _burn_amount()
	if _anchor != null:
		_anchor.position = Vector2(
			randf_range(-SHAKE_PX, SHAKE_PX),
			randf_range(-SHAKE_PX, SHAKE_PX),
		) * burn
	if _flame != null:
		_flame.scale = Vector2(1.0 + 0.3 * burn, 1.0 + (FLAME_SCALE_Y - 1.0) * burn)
		_flame.speed_scale = 1.0 + (FLAME_SPEED_SCALE - 1.0) * burn


## 0 before ignition, 1 through the burn, back to 0 across the settle.
func _burn_amount() -> float:
	if elapsed < IGNITION_END:
		return clampf(elapsed / IGNITION_END, 0.0, 1.0) * 0.4
	if elapsed < BURN_END:
		return 1.0
	return 1.0 - clampf((elapsed - BURN_END) / (SETTLE_END - BURN_END), 0.0, 1.0)


func _update_background() -> void:
	if space_background == null:
		return
	var scale := 1.0
	if elapsed < IGNITION_END:
		var t := elapsed / IGNITION_END
		scale = IGNITION_SPEED * t * t
	elif elapsed < BURN_END:
		var t := (elapsed - IGNITION_END) / (BURN_END - IGNITION_END)
		scale = lerpf(IGNITION_SPEED, BURST_SPEED, 1.0 - pow(1.0 - t, 2.0))
	elif elapsed < SETTLE_END:
		var t := (elapsed - BURN_END) / (SETTLE_END - BURN_END)
		scale = lerpf(BURST_SPEED, 1.0, t * t)
	space_background.speed_scale = scale


func _update_audio() -> void:
	if not _sfx_played and elapsed >= SFX_AT:
		_sfx_played = true
		_play_sfx()
	var open := clampf((elapsed - FILTER_OPEN_START) / (FILTER_OPEN_END - FILTER_OPEN_START), 0.0, 1.0)
	# Perceptually even sweep: interpolate in log frequency.
	var cutoff := exp(lerpf(log(MUFFLED_CUTOFF_HZ), log(OPEN_CUTOFF_HZ), open))
	set_music_cutoff(cutoff)


func _play_sfx() -> void:
	if not ResourceLoader.exists(LAUNCH_SFX_PATH):
		return
	var stream := load(LAUNCH_SFX_PATH) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Movement input, the viewport clamp and weapon fire (the loadout's timers
## stop with PROCESS_MODE_DISABLED) lock together.
func _set_controls(enabled: bool) -> void:
	if _move_input != null:
		_move_input.enabled = enabled
	if _clamp != null:
		_clamp.enabled = enabled
	if _weapon_loadout != null:
		_weapon_loadout.process_mode = (
			Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		)


func _finish() -> void:
	is_launching = false
	set_process(false)
	if not _controls_unlocked:
		_controls_unlocked = true
		_set_controls(true)
	# The ship is the player's since CONTROL_UNLOCK: keep where they flew it.
	if _anchor != null:
		_anchor.position = Vector2.ZERO
	if _flame != null:
		_flame.scale = Vector2.ONE
		_flame.speed_scale = 1.0
	if space_background != null:
		space_background.speed_scale = 1.0
	set_music_muffled(false)
	if encounter_director != null and encounter_director.has_method("start_sequence"):
		encounter_director.call("start_sequence")
	launch_finished.emit()
