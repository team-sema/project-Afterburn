class_name EnemyFireVolumeBoostComponent
extends Node

## Crisis pressure: more pellets per volley on the baseline shoot component.

@export_range(1, 8, 1) var extra_shots := 2
@export_range(0.0, 60.0, 1.0) var min_spread_degrees := 18.0


func _ready() -> void:
	var enemy := get_parent() as Enemy
	if enemy == null:
		push_error("EnemyFireVolumeBoostComponent must be attached to an Enemy.")
		return
	var shoot := enemy.get_node_or_null("EnemyShootComponent") as EnemyShootComponent
	if shoot == null:
		push_warning("EnemyFireVolumeBoostComponent: no EnemyShootComponent on '%s'." % enemy.name)
		return
	shoot.shot_count = maxi(shoot.shot_count + extra_shots, 1)
	shoot.spread_degrees = maxf(shoot.spread_degrees, min_spread_degrees)
