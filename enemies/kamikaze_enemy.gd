extends Enemy

## Awl kamikaze: no shots — dive, aim, charge at locked player position.


func _enter_tree() -> void:
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		# Free before EnemyShootComponent._ready so no delayed burst starts.
		shoot.free()
