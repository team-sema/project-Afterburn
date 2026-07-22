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

func _ready() -> void:
	# Connect the the no health signal on our stats to the destroy function
	stats_component.no_health.connect(destroy)

func destroy() -> void:
	# create an effect (from the spawner component) and free the actor
	var destroy_effect := destroy_effect_spawner_component.spawn(actor.global_position)
	if destroy_effect.has_method("set_effect_color"):
		destroy_effect.call("set_effect_color", destroy_effect_color)
	actor.queue_free()
