# Give the component a class name so it can be instanced as a custom node
class_name HurtComponent
extends Node

# Grab the stats so we can alter the health
@export var stats_component: StatsComponent

# Grab a hurtbox so we know when we have taken a hiet
@export var hurtbox_component: HurtboxComponent

# Optional shield that absorbs a whole damage event before the health is touched
@export var shield_component: ShieldComponent

func _ready() -> void:
	# Connect the hurt signal on the hurtbox component to an anonymous function
	# that removes health equal to the damage from the hitbox
	hurtbox_component.hurt.connect(func(hitbox_component: HitboxComponent):
		# The shield gate blocks the event outright, so no overflow reaches the hull
		if shield_component != null and shield_component.absorb_damage(hitbox_component.damage):
			return
		stats_component.health -= hitbox_component.damage
	)
