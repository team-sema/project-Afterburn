class_name WeaponTraitDefinition
extends Resource

@export var trait_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var target_weapon_id: StringName
@export_multiline var next_rank_hint: String = ""
@export_range(1, 5, 1) var max_rank := 3
## Lv.I combat tuning values read by the owning WeaponSystem via get_trait_param().
@export var params: Dictionary = {}
## Lv.II, Lv.III ... overrides in order. Each entry only needs changed keys.
@export var rank_overrides: Array[Dictionary] = []


func get_params_for_rank(rank: int) -> Dictionary:
	var resolved := params.duplicate(true)
	var override_count := mini(maxi(rank - 1, 0), rank_overrides.size())
	for index in override_count:
		resolved.merge(rank_overrides[index], true)
	return resolved


func get_param_for_rank(rank: int, key: StringName, default_value: Variant = null) -> Variant:
	var resolved := get_params_for_rank(clampi(rank, 1, max_rank))
	if resolved.has(key):
		return resolved[key]
	var string_key := String(key)
	if resolved.has(string_key):
		return resolved[string_key]
	return default_value
