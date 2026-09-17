extends HitboxComponent


func _ready() -> void:
	# One Area owns all body segments. Polling also hits again after immunity
	# expires while the player remains inside a persistent laser.
	pass


func apply_contacts() -> void:
	for area in get_overlapping_areas():
		if area is HurtboxComponent:
			_on_hurtbox_entered(area)
