class_name WeaponDropComponent
extends Node

## Field weapon drops are retired. Keep the component for scene compatibility;
## it does nothing unless explicitly re-enabled.

@export var stats_component: StatsComponent
@export var actor: Node2D
@export var drop_table: WeaponDropTable
@export var pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var drop_chance := 0.08
## Weapons are offered through augments; leave false.
@export var enabled := false


func _ready() -> void:
	if not enabled:
		return
	assert(stats_component != null, "WeaponDropComponent requires StatsComponent.")
	assert(actor != null, "WeaponDropComponent requires actor Node2D.")
	assert(drop_table != null, "WeaponDropComponent requires WeaponDropTable.")
	assert(pickup_scene != null, "WeaponDropComponent requires pickup_scene.")
	stats_component.no_health.connect(_on_no_health)


func _on_no_health() -> void:
	if not enabled:
		return
	if drop_chance <= 0.0 or randf() > drop_chance:
		return
	var definition := drop_table.pick_random()
	if definition == null:
		return
	var parent := get_tree().get_first_node_in_group("gameplay_world")
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var pickup := pickup_scene.instantiate()
	if pickup == null or not pickup.has_method("setup"):
		push_error("WeaponDropComponent: pickup scene missing setup().")
		return
	var spawn_position := actor.global_position
	parent.add_child.call_deferred(pickup)
	pickup.call_deferred("setup", definition, spawn_position)
