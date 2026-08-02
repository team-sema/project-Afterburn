class_name WeaponSlotState
extends RefCounted

## One equipped bay. Growth lives on weapon_id progress, not here.

var slot_index: int = 0
var equipped_weapon_id: StringName = &""
var equipped_weapon_display_name: String = ""
var equipped_weapon_definition: WeaponDefinition = null
var equipped_weapon_instance: WeaponSystem = null


func is_empty() -> bool:
	return equipped_weapon_id == &""
