extends MoveComponent

@export var state: StateComponent

@export var speed: float = 20.0

func _ready() -> void:
	state.entering.connect(func():
		_choose_direction()
	)

func _choose_direction() -> void:
	velocity = Vector2([-speed, speed].pick_random(), 0.0)
