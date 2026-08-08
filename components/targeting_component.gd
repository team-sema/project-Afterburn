class_name TargetingComponent
extends Node

@export var default_target_group: StringName = &"player"

var _target: Node2D = null

func _ready() -> void:
	_target = get_tree().get_first_node_in_group(default_target_group) as Node2D


func change_target(new_target: Node2D) -> void:
	_target = new_target


func get_target() -> Node2D:
	if _target == null or not is_instance_valid(_target):
		if is_inside_tree():
			_target = get_tree().get_first_node_in_group(default_target_group) as Node2D
	return _target


func get_target_position() -> Vector2:
	var target := get_target()
	if target == null:
		return Vector2.ZERO
	return target.global_position


func get_direction_from(origin: Vector2) -> Vector2:
	var target := get_target()
	if target == null:
		return Vector2.ZERO
	return origin.direction_to(target.global_position)
