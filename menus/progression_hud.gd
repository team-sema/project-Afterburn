class_name ProgressionHud
extends VBoxContainer

@export var progression: Node

@onready var experience_label: Label = %ExperienceLabel
@onready var experience_bar: ProgressBar = %ExperienceBar
@onready var threat_label: Label = %ThreatLabel
@onready var threat_bar: ProgressBar = %ThreatBar


func _ready() -> void:
	assert(progression != null, "ProgressionHud requires an AugmentProgressionController.")
	progression.experience_changed.connect(_on_experience_changed)
	progression.enemy_augment_progress_changed.connect(_on_enemy_augment_progress_changed)
	progression.call_deferred("publish_state")


func _on_experience_changed(current_experience: int, experience_required: int, level: int) -> void:
	experience_bar.max_value = max(1, experience_required)
	experience_bar.value = current_experience
	experience_label.text = "LEVEL %02d   %d / %d XP" % [level, current_experience, experience_required]


func _on_enemy_augment_progress_changed(elapsed: float, interval: float, next_tier: int) -> void:
	threat_bar.max_value = maxf(1.0, interval)
	threat_bar.value = elapsed
	var remaining_seconds := maxi(0, ceili(interval - elapsed))
	var minutes := remaining_seconds / 60
	var seconds := remaining_seconds % 60
	threat_label.text = "THREAT %02d   %02d:%02d" % [next_tier, minutes, seconds]
