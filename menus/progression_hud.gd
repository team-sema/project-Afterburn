class_name ProgressionHud
extends VBoxContainer

@export var progression: Node

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
	threat_bar.max_value = maxf(1.0, interval)
	threat_bar.value = interval if _elite_gate_active else elapsed
	if _elite_gate_active:
		threat_label.text = "THREAT %02d   ELITE ENGAGED" % current_threat_level
		return
	var remaining_seconds := maxi(0, ceili(interval - elapsed))
	var minutes := floori(float(remaining_seconds) / 60.0)
	var seconds := remaining_seconds % 60
	threat_label.text = "THREAT %02d   %02d:%02d" % [current_threat_level, minutes, seconds]


func _on_elite_gate_changed(is_active: bool, _threat_level: int) -> void:
	_elite_gate_active = is_active


func _on_bullet_cancel_reward_changed(is_active: bool) -> void:
	_bullet_cancel_reward_active = is_active
	_refresh_experience()
