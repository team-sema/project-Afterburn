class_name PlayerAugmentModuleState
extends RefCounted

var augment: PlayerAugment
var target_weapon_id: StringName


func _init(definition: PlayerAugment, weapon_id: StringName = &"") -> void:
	augment = definition
	target_weapon_id = weapon_id
