class_name BulletSlowField
extends RefCounted

## Keeps one speed multiplier on enemy bullets while their centre (laser: head)
## stays inside a circle. The effect is applied once on entry and removed on
## exit, so a bullet sitting in the field does not pile up trajectory events.
## Call update() every physics tick and release() when the field goes away.

var handle: StringName
var speed_mult: float
## instance id -> bullet currently carrying this field's effect.
var _inside: Dictionary = {}


func _init(p_handle: StringName, p_speed_mult: float) -> void:
	handle = p_handle
	speed_mult = p_speed_mult


## Returns how many bullets are slowed after this tick.
func update(world: Node, center: Vector2, radius: float) -> int:
	var current: Dictionary = {}
	for bullet in EnemyBullets.query_circle(world, center, radius):
		var id := bullet.get_instance_id()
		if _inside.has(id) or EnemyBullets.apply_effect(bullet, handle, speed_mult):
			current[id] = bullet
	for id in _inside:
		if not current.has(id):
			_remove(_inside[id])
	_inside = current
	return _inside.size()


func release() -> void:
	for id in _inside:
		_remove(_inside[id])
	_inside.clear()


func get_count() -> int:
	return _inside.size()


func _remove(bullet: Variant) -> void:
	if is_instance_valid(bullet):
		EnemyBullets.remove_effect(bullet as Node2D, handle)
