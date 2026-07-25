class_name WeaponDropTable
extends Resource

@export var weapons: Array[WeaponDefinition] = []


func pick_random() -> WeaponDefinition:
	if weapons.is_empty():
		return null
	return weapons[randi() % weapons.size()]
