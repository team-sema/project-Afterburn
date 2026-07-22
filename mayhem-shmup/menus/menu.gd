extends Control

const GAME_SCENE := preload("uid://biklivgjp6cup")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_packed(GAME_SCENE)
