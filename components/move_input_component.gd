class_name MoveInputComponent
extends Node

@export var move_stats: MoveStats
@export var move_component: MoveComponent
## false locks the ship (launch sequence): velocity stays whatever it was set to.
@export var enabled := true

func _process(_delta: float) -> void:
	if not enabled:
		return
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if Input.is_physical_key_pressed(KEY_A):
		input_direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_direction.y += 1.0

	move_component.velocity = input_direction.limit_length(1.0) * move_stats.speed
