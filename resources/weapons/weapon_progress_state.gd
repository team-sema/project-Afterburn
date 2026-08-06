class_name WeaponProgressState
extends RefCounted

## Per-weapon_id module growth for the current run. Slots and UI do not own this.

var weapon_id: StringName = &""
## trait_id -> module level
var trait_ranks: Dictionary = {}
var definition: WeaponDefinition = null


func get_trait_rank(trait_id: StringName) -> int:
	return int(trait_ranks.get(trait_id, 0))


func set_trait_rank(trait_id: StringName, rank: int) -> void:
	if trait_id == &"":
		return
	if rank <= 0:
		trait_ranks.erase(trait_id)
	else:
		trait_ranks[trait_id] = rank
