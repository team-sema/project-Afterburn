class_name SniperEnemy
extends Enemy

## Sniper: enters a distant band, holds position, and repeatedly aims/fires a laser.


func _enter_tree() -> void:
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		shoot.free()
	var state_machine := get_node_or_null("StateMachine")
	if state_machine != null:
		state_machine.free()
	var legacy_spawner := get_node_or_null("ProjectileSpawnerComponent")
	if legacy_spawner != null:
		legacy_spawner.free()
