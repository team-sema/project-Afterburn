extends Node
## Lives across Lab scene reloads, until returning to the hub.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		return_to_hub.call_deferred()

func return_to_hub() -> void:
	get_tree().paused = false
	get_tree().debug_collisions_hint = false
	get_tree().change_scene_to_file("res://lab_hub.tscn")
	queue_free()
