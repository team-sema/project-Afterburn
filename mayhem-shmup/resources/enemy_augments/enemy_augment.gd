class_name EnemyAugment
extends Resource

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var stat_modifiers: Array[EnemyStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
