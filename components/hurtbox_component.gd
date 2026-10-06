# Give the component a class name so it can be instanced as a custom node
class_name HurtboxComponent
extends Area2D

signal invincibility_changed(enabled: bool)

## When true, piercing player shots stop on this hurtbox (e.g. boss wall body).
@export var blocks_pierce := false

func _ready() -> void:
	# Enemy bullets are passive (monitorable-only) areas: the few player-side
	# hurtboxes they can hit watch the enemy_projectile layer instead of every
	# bullet running its own overlap monitoring.
	if collision_layer & 1: # layer 1 = player_hurtbox
		monitoring = true
		collision_mask |= EnemyBullets.LAYER
		area_entered.connect(_on_passive_hitbox_entered)

func _on_passive_hitbox_entered(area: Area2D) -> void:
	# Hitboxes that monitor themselves (contact bodies, lasers, beams, legacy
	# shots) keep their own detection; dispatching them here would double-hit.
	var hitbox := area as HitboxComponent
	if hitbox != null and not hitbox.monitoring:
		hitbox._on_hurtbox_entered(self)

# Create the is_invincible boolean
var is_invincible = false :
	# Here we create an inline setter so we can disable and enable collision shapes on
	# the hurtbox when is_invincible is changed.
	set(value):
		if is_invincible == value:
			return
		is_invincible = value
		# Disable any collisions shapes on this hurtbox when it is invincible
		# And reenable them when it isn't invincible
		for child in get_children():
			if not child is CollisionShape2D and not child is CollisionPolygon2D: continue
			# Use call deferred to make sure this doesn't happen in the middle of the
			# physics process
			child.set_deferred("disabled", is_invincible)
		invincibility_changed.emit(is_invincible)

# Create a signal for when this hurtbox is hit by a hitbox
@warning_ignore("unused_signal") # Emitted by HitboxComponent and weapon/projectile systems.
signal hurt(hitbox)
