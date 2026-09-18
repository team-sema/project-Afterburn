class_name PinkEnemy
extends Enemy

## Caster: hovers at the top and fires multi-ring circular barrages until death.


func _enter_tree() -> void:
	# Keep common pattern fire; remove only the obsolete dive state machine.
	var state_machine := get_node_or_null("StateMachine")
	if state_machine != null:
		state_machine.free()
	var legacy_spawner := get_node_or_null("ProjectileSpawnerComponent")
	if legacy_spawner != null:
		legacy_spawner.free()
