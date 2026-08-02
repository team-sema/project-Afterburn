class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var weapon_scene: PackedScene
@export var icon: Texture2D
@export_multiline var description: String = ""
## Short attack-style blurb for STATUS detail (not shown inside the hex core).
@export var attack_summary: String = ""
