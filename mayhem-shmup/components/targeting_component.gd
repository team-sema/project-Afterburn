class_name TargetingComponent
extends Node

@export var default_target_group: StringName = &"player"

var _target: Node2D = null

func _ready() -> void:
	_target = get_tree().get_first_node_in_group(default_target_group) as Node2D


func change_target(new_target: Node2D) -> void:
	_target = new_target


func get_target() -> Node2D:
	return _target


func get_target_position() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	return _target.global_position


func get_direction_from(origin: Vector2) -> Vector2:
	if _target == null:
		return Vector2.ZERO

	return origin.direction_to(_target.global_position)
