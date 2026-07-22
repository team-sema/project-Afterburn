class_name FreeOffscreenComponent
extends VisibleOnScreenNotifier2D

@export var actor: Node2D


func _ready() -> void:
	screen_exited.connect(actor.queue_free)
