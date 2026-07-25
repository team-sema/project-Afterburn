class_name PlayerAugment
extends Resource

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var augment_type: PlayerAugmentKind.Kind = PlayerAugmentKind.Kind.STAT_MULTIPLIER
@export var stat_modifiers: Array[PlayerStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
@export var weapon_definition: WeaponDefinition
