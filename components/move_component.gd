class_name MoveComponent
extends Node

@export var actor: Node2D
@export var velocity: Vector2 = Vector2.ZERO

@export var velocity_multiplier: float = 1.0

func _process(delta: float) -> void:
	actor.translate(velocity * delta * velocity_multiplier)
