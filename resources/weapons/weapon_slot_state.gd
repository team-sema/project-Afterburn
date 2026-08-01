class_name WeaponSlotState
extends RefCounted

var slot_type: WeaponDefinition.Category = WeaponDefinition.Category.MAIN
var slot_index: int = 0
var unlocked: bool = false
var equipped_weapon_id: StringName = &""
var equipped_weapon_display_name: String = ""
var equipped_weapon_definition: WeaponDefinition = null
var equipped_weapon_instance: WeaponSystem = null


## Empty when no weapon id is assigned (reserve may have no live instance).
func is_empty() -> bool:
	return equipped_weapon_id == &""
