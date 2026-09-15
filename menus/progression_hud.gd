class_name ProgressionHud
extends VBoxContainer

@export var progression: Node
## Optional. When set and running a sequence, Threat HUD shows phase progress
## instead of the 60s elite timer countdown.
@export var encounter_director: Node

@onready var experience_label: Label = %ExperienceLabel
@onready var experience_bar: ProgressBar = %ExperienceBar
@onready var threat_label: Label = %ThreatLabel
@onready var threat_bar: ProgressBar = %ThreatBar

var _experience_fill_style: StyleBoxFlat
var _normal_experience_fill_color := Color.WHITE
var _normal_experience_label_color := Color.WHITE
var _is_augment_ready := false
var _highlight_time := 0.0
var _elite_gate_active := false
var _bullet_cancel_reward_active := false
var _current_experience := 0
var _experience_required := 1
var _level := 1
var _current_threat_level := 1
var _sequence_mode := false
var _sequence_stage := 0
var _sequence_step_index := 0
var _sequence_step_count := 0
var _timer_elapsed := 0.0
var _timer_interval := 60.0


func _ready() -> void:
	assert(progression != null, "ProgressionHud requires an AugmentProgressionController.")
	var fill_style := experience_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		_experience_fill_style = fill_style.duplicate() as StyleBoxFlat
		_normal_experience_fill_color = _experience_fill_style.bg_color
		experience_bar.add_theme_stylebox_override("fill", _experience_fill_style)
	_normal_experience_label_color = experience_label.get_theme_color("font_color")
	progression.experience_changed.connect(_on_experience_changed)
	progression.enemy_augment_progress_changed.connect(_on_enemy_augment_progress_changed)
	progression.elite_gate_changed.connect(_on_elite_gate_changed)
	progression.bullet_cancel_reward_changed.connect(_on_bullet_cancel_reward_changed)
	if encounter_director != null:
		encounter_director.sequence_started.connect(_on_sequence_started)
		encounter_director.sequence_progress_changed.connect(_on_sequence_progress_changed)
		encounter_director.sequence_completed.connect(_on_sequence_completed)
	progression.call_deferred("publish_state")


func _process(delta: float) -> void:
	if not _is_augment_ready:
		return
	_highlight_time += delta
	var hue := fmod(_highlight_time * 0.35, 1.0)
	var pulse := (sin(_highlight_time * TAU * 2.0) + 1.0) * 0.5
	var highlight := Color.from_hsv(hue, 0.7, 1.0, 0.95).lerp(Color.WHITE, pulse * 0.3)
	if _experience_fill_style != null:
		_experience_fill_style.bg_color = highlight
	experience_label.add_theme_color_override("font_color", highlight)


func _on_experience_changed(current_experience: int, experience_required: int, level: int) -> void:
	_current_experience = current_experience
	_experience_required = experience_required
	_level = level
	_refresh_experience()


func _refresh_experience() -> void:
	experience_bar.max_value = max(1, _experience_required)
	experience_bar.value = _current_experience
	var is_ready := _current_experience >= _experience_required
	if is_ready:
		if _bullet_cancel_reward_active:
			experience_label.text = "LEVEL %02d   XP RECOVERY" % _level
		else:
			experience_label.text = "LEVEL %02d   AUGMENT READY [C]" % _level
	else:
		experience_label.text = "LEVEL %02d   %d / %d XP" % [
			_level,
			_current_experience,
			_experience_required,
		]
	_set_augment_ready(is_ready and not _bullet_cancel_reward_active)


func _set_augment_ready(is_ready: bool) -> void:
	if _is_augment_ready == is_ready:
		return
	_is_augment_ready = is_ready
	_highlight_time = 0.0
	if is_ready:
		return
	if _experience_fill_style != null:
		_experience_fill_style.bg_color = _normal_experience_fill_color
	experience_label.add_theme_color_override("font_color", _normal_experience_label_color)


func _on_enemy_augment_progress_changed(
	elapsed: float,
	interval: float,
	current_threat_level: int,
) -> void:
	_timer_elapsed = elapsed
	_timer_interval = interval
	_current_threat_level = current_threat_level
	_refresh_threat()


func _on_elite_gate_changed(is_active: bool, _threat_level: int) -> void:
	_elite_gate_active = is_active
	_refresh_threat()


func _on_sequence_started(_sequence_id: StringName) -> void:
	_sequence_mode = true
	_refresh_threat()


func _on_sequence_progress_changed(
	stage: int,
	step_index: int,
	step_count: int,
	_token: StringName,
	_kind: EncounterSequenceStep.Kind,
) -> void:
	_sequence_mode = true
	_sequence_stage = stage
	_sequence_step_index = step_index
	_sequence_step_count = step_count
	_refresh_threat()


func _on_sequence_completed(_sequence_id: StringName) -> void:
	_sequence_mode = false
	_sequence_stage = 0
	_sequence_step_index = 0
	_sequence_step_count = 0
	_refresh_threat()


func _refresh_threat() -> void:
	if _elite_gate_active:
		threat_bar.max_value = maxf(1.0, float(maxi(1, _sequence_step_count)))
		threat_bar.value = threat_bar.max_value
		if _sequence_mode:
			threat_label.text = "STAGE %02d   ELITE ENGAGED" % maxi(1, _sequence_stage)
		else:
			threat_label.text = "ELITE ENGAGED"
		return
	if _sequence_mode:
		var step_count := maxi(1, _sequence_step_count)
		threat_bar.max_value = float(step_count)
		threat_bar.value = float(clampi(_sequence_step_index, 0, step_count))
		threat_label.text = "STAGE %02d" % maxi(1, _sequence_stage)
		return
	threat_bar.max_value = maxf(1.0, _timer_interval)
	threat_bar.value = _timer_elapsed
	var remaining_seconds := maxi(0, ceili(_timer_interval - _timer_elapsed))
	var minutes := floori(float(remaining_seconds) / 60.0)
	var seconds := remaining_seconds % 60
	threat_label.text = "%02d:%02d" % [minutes, seconds]


func _on_bullet_cancel_reward_changed(is_active: bool) -> void:
	_bullet_cancel_reward_active = is_active
	_refresh_experience()
