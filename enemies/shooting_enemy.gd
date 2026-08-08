class_name PinkEnemy
extends Enemy

## Caster: hovers at the top and fires multi-ring circular barrages until death.


func _enter_tree() -> void:
	# Replace baseline aimed fire + old dive state machine.
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		shoot.free()
	var state_machine := get_node_or_null("StateMachine")
	if state_machine != null:
		state_machine.free()
	var legacy_spawner := get_node_or_null("ProjectileSpawnerComponent")
	if legacy_spawner != null:
		legacy_spawner.free()
