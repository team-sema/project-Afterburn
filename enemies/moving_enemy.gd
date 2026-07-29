extends Enemy

func _ready() -> void:
	super()
	move_component.velocity.x = [-23, 23].pick_random()
