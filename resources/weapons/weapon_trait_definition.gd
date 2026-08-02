class_name WeaponTraitDefinition
extends Resource

## Scaffold for weapon-specific trait modules. Combat effects are not implemented yet.

@export var trait_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var target_weapon_id: StringName
@export_multiline var next_rank_hint: String = ""
