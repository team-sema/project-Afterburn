class_name EnemyAugmentGrantComponent
extends Node

@export var augment: EnemyAugment
@export var augment_registry: EnemyAugmentRegistry


func grant() -> void:
	assert(augment != null, "EnemyAugmentGrantComponent must have an augment set.")
	assert(augment_registry != null, "EnemyAugmentGrantComponent requires an injected EnemyAugmentRegistry.")
	augment_registry.add_augment(augment)
