extends Enemy

## Courier: a dart fighter towing a Bomb. Descends while steering toward the
## player, drops the Bomb ahead of them, then boosts out. Carries no gun.

## How quickly the nose turns toward the flight direction (radians/s factor).
@export_range(0.0, 40.0, 0.5) var heading_turn_rate := 10.0

@onready var _anchor: Node2D = $Anchor


func _enter_tree() -> void:
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		shoot.free()


func _process(delta: float) -> void:
	var velocity := move_component.velocity
	if velocity.length_squared() < 1.0:
		return
	var heading := Vector2.DOWN.angle_to(velocity)
	_anchor.rotation = lerp_angle(_anchor.rotation, heading, minf(1.0, heading_turn_rate * delta))
