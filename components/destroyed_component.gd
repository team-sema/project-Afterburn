# Give the component a class name so it can be instanced as a custom node
class_name DestroyedComponent
extends Node

# Export the actor this component will operate on
@export var actor: Node2D

# Grab access to the stats so we can tell when the health has reached zero
@export var stats_component: StatsComponent

# Export and grab access to a spawner component so we can create an effect on death
@export var destroy_effect_spawner_component: SpawnerComponent
@export var destroy_effect_color := Color("ff3f8f")
## Player and standalone users keep the legacy automatic effect + free path.
## Enemy disables this and owns its ordered score -> effect -> free path.
@export var auto_destroy_on_no_health := true

var _suppress_next_effect := false

func _ready() -> void:
	assert(actor != null, "DestroyedComponent requires an actor.")
	assert(stats_component != null, "DestroyedComponent requires StatsComponent.")
	assert(
		destroy_effect_spawner_component != null,
		"DestroyedComponent requires a destroy effect spawner.",
	)
	if auto_destroy_on_no_health and not stats_component.no_health.is_connected(destroy):
		stats_component.no_health.connect(destroy)

func destroy() -> void:
	spawn_destroy_effect()
	actor.queue_free()


func spawn_destroy_effect() -> Node:
	if _suppress_next_effect:
		_suppress_next_effect = false
		return null
	var destroy_effect := destroy_effect_spawner_component.spawn(actor.global_position)
	if destroy_effect.has_method("set_effect_color"):
		destroy_effect.call("set_effect_color", destroy_effect_color)
	return destroy_effect


func suppress_next_effect() -> void:
	_suppress_next_effect = true
