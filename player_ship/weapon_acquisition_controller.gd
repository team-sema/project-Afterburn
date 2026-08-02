class_name WeaponAcquisitionController
extends Node

## Retired field-pickup bridge. Augment offers call PlayerWeaponLoadout directly.
## Left in the scene tree so old references do not break; try_collect always fails.

@export var ship: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("weapon_acquisition")


func try_collect(_weapon_definition: WeaponDefinition) -> bool:
	return false
