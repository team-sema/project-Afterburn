class_name MoveComponent
extends Node

@export var actor: Node2D
@export var velocity: Vector2 = Vector2.ZERO
@export var modifier_component: MoveModifierComponent

@export var velocity_multiplier: float = 1.0


func _ready() -> void:
	if modifier_component == null and actor != null:
		modifier_component = actor.get_node_or_null("MoveModifierComponent") as MoveModifierComponent


func _process(delta: float) -> void:
	var motion := velocity * delta * velocity_multiplier
	if modifier_component != null:
		motion += modifier_component.advance(delta)
	actor.translate(motion)


func get_modifier_component() -> MoveModifierComponent:
	return modifier_component
