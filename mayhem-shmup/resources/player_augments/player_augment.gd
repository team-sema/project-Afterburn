class_name PlayerAugment
extends Resource

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var stat_modifiers: Array[PlayerStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
