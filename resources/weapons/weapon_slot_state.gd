class_name WeaponSlotState
extends RefCounted

const MAX_LEVEL := 3

var slot_type: WeaponDefinition.Category = WeaponDefinition.Category.MAIN
var slot_index: int = 0
var unlocked: bool = false
var level: int = 1
var equipped_weapon_id: StringName = &""
var equipped_weapon_display_name: String = ""
var equipped_weapon_instance: WeaponSystem = null


func is_empty() -> bool:
	return equipped_weapon_id == &"" or equipped_weapon_instance == null


func get_damage_multiplier() -> float:
	match clampi(level, 1, MAX_LEVEL):
		1:
			return 1.0
		2, 3:
			return 1.2
		_:
			return 1.0


func get_attack_rate_multiplier() -> float:
	match clampi(level, 1, MAX_LEVEL):
		1, 2:
			return 1.0
		3:
			return 1.2
		_:
			return 1.0


func can_upgrade() -> bool:
	return unlocked and not is_empty() and level < MAX_LEVEL
