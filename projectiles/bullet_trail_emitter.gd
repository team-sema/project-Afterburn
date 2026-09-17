class_name BulletTrailEmitter
extends RefCounted
## No Node per emitter/particle. Carries only emission phase and last position.
var manager: ProjectileTrailManager
var effect: BulletTrailEffect
var previous: Vector2
var remainder := 0.0

func _init(world: Node2D, config: BulletTrailEffect, origin: Vector2) -> void:
	manager = ProjectileTrailManager.for_world(world)
	effect = config.duplicate() as BulletTrailEffect
	previous = origin

func advance(position_world: Vector2, delta: float) -> void:
	if not position_world.is_finite() or not is_finite(delta) or delta < 0: return
	var movement := position_world - previous
	var distance := movement.length()
	if distance > 1024:
		previous = position_world
		remainder = 0
		return
	if distance <= 0.00001: return
	var count := floori((remainder + distance) / effect.spacing)
	var first := effect.spacing - remainder
	if is_instance_valid(manager):
		for i in mini(count, 64):
			var fraction := (first + i * effect.spacing) / distance
			manager.emit_particle(effect, previous.lerp(position_world, fraction), -movement / distance, maxf(0, delta * (1 - fraction)))
		manager.dropped += maxi(0, count - 64)
	remainder = fposmod(remainder + distance, effect.spacing)
	previous = position_world
