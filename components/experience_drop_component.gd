class_name ExperienceDropComponent
extends Node

## Per-enemy XP orb drop. Tune frequency via drop_chance; keep experience_amount for value.

@export var stats_component: StatsComponent
@export var actor: Node2D
@export var orb_scene: PackedScene
@export_range(1, 1000, 1) var experience_amount := 1
## Temporary bump after removing weapon drops (was 0.5). Tunable in the inspector / scene.
@export_range(0.0, 1.0, 0.01) var drop_chance := 0.62


func _ready() -> void:
	assert(stats_component != null, "ExperienceDropComponent requires StatsComponent.")
	assert(actor != null, "ExperienceDropComponent requires actor Node2D.")
	assert(orb_scene != null, "ExperienceDropComponent requires orb_scene.")
	stats_component.no_health.connect(_on_no_health)


func _on_no_health() -> void:
	if drop_chance <= 0.0 or randf() > drop_chance:
		return
	var parent := get_tree().get_first_node_in_group("gameplay_world")
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var orb := orb_scene.instantiate()
	if orb == null or not orb.has_method("setup"):
		push_error("ExperienceDropComponent: orb scene missing setup().")
		return
	var spawn_position := actor.global_position
	parent.add_child.call_deferred(orb)
	orb.call_deferred("setup", experience_amount, spawn_position)
