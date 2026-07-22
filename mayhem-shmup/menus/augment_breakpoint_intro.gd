class_name AugmentBreakpointIntro
extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func play_intro() -> void:
	visible = true
	animation_player.play(&"reveal")
	await animation_player.animation_finished
	visible = false
