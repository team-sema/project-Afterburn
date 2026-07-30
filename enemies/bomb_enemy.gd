extends Enemy

## Slow bomb: proximity fuse, red warning flashes, oversized self-destruct.


func _enter_tree() -> void:
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		shoot.free()
