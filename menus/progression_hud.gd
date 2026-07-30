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
	experience_bar.max_value = max(1, experience_required)
	experience_bar.value = current_experience
	var is_ready := current_experience >= experience_required
	if is_ready:
		experience_label.text = "LEVEL %02d   AUGMENT READY [C]" % level
	else:
		experience_label.text = "LEVEL %02d   %d / %d XP" % [level, current_experience, experience_required]
	_set_augment_ready(is_ready)


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


func _on_enemy_augment_progress_changed(elapsed: float, interval: float, next_tier: int) -> void:
	threat_bar.max_value = maxf(1.0, interval)
	threat_bar.value = elapsed
	var remaining_seconds := maxi(0, ceili(interval - elapsed))
	var minutes := remaining_seconds / 60
	var seconds := remaining_seconds % 60
	threat_label.text = "THREAT %02d   %02d:%02d" % [next_tier, minutes, seconds]
