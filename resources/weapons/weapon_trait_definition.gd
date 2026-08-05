class_name WeaponTraitDefinition
extends Resource

@export var trait_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var target_weapon_id: StringName
@export_multiline var next_rank_hint: String = ""
## Combat tuning values read by the owning WeaponSystem via get_trait_param().
@export var params: Dictionary = {}
