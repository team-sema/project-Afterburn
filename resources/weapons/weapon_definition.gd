class_name WeaponDefinition
extends Resource

enum Category {
	MAIN,
	AUXILIARY,
}

@export var id: StringName
@export var display_name: String
@export var category: Category = Category.MAIN
@export var weapon_scene: PackedScene
@export var icon: Texture2D
@export_multiline var description: String = ""
