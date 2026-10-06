class_name ProjectileTrailManager
extends Node2D
## One bounded decorative pool per projectile world, independent of emitters.
## Each particle's instance data is written once at emission; the shader moves,
## fades and finally collapses it from its age, so living particles cost no
## per-frame writes. The CPU only tracks lifetimes to reuse MultiMesh slots and
## enforce the emission budgets.
const MAX_PARTICLES := 4096
const MAX_PER_TICK := 256
class Particle extends RefCounted:
	var position: Vector2
	var velocity: Vector2
	var born: float
	var lifetime: float
	var mesh: MultiMesh
	var free_slots: Array
	var slot: int

var particles: Array[Particle] = []
var dropped := 0
var _emitted := 0
## key -> {instance: MultiMeshInstance2D, mesh: MultiMesh, free: Array, used: int}
var _batches := {}
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _last_transform := Transform2D.IDENTITY

static func for_world(world: Node2D) -> ProjectileTrailManager:
	var existing = world.get_meta("projectile_trails") if world.has_meta("projectile_trails") else null
	if is_instance_valid(existing) and not existing.is_queued_for_deletion(): return existing
	var manager := ProjectileTrailManager.new()
	manager.name = "ProjectileTrailManager"
	world.set_meta("projectile_trails", manager)
	world.add_child.call_deferred(manager)
	return manager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -100
	var renderer := get_parent().get_node_or_null("ProjectileBatchRenderer")
	if renderer != null: get_parent().move_child(self, renderer.get_index())
	_rng.randomize()

func emit_particle(effect: BulletTrailEffect, position_world: Vector2, backwards: Vector2, elapsed := 0.0) -> bool:
	if particles.size() >= MAX_PARTICLES or _emitted >= MAX_PER_TICK:
		dropped += 1
		return false
	_emitted += 1
	if elapsed >= effect.lifetime: return false
	var batch := _batch_for(effect)
	var free: Array = batch.free
	var mesh: MultiMesh = batch.mesh
	var slot: int
	if free.is_empty():
		slot = batch.used
		batch.used += 1
		if slot >= mesh.instance_count:
			# Growing reallocates the zeroed buffer, so live slots are rewritten.
			mesh.instance_count = maxi(64, mesh.instance_count * 2)
			_rewrite_batch(mesh)
	else:
		slot = free.pop_back()
	var particle := Particle.new()
	particle.position = position_world
	particle.velocity = backwards.rotated(deg_to_rad(_rng.randf_range(-effect.spread_degrees, effect.spread_degrees))) * _rng.randf_range(effect.speed_min, effect.speed_max)
	particle.born = _clock - elapsed
	particle.lifetime = effect.lifetime
	particle.mesh = mesh
	particle.free_slots = free
	particle.slot = slot
	particles.append(particle)
	mesh.set_instance_transform_2d(slot, global_transform.affine_inverse() * Transform2D(0, particle.position))
	mesh.set_instance_custom_data(slot, Color(particle.velocity.x, particle.velocity.y, particle.born, particle.lifetime))
	if mesh.visible_instance_count < batch.used:
		mesh.visible_instance_count = batch.used
	return true

func _batch_for(effect: BulletTrailEffect) -> Dictionary:
	var key := effect.batch_key()
	if _batches.has(key):
		return _batches[key]
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh.mesh = quad
	mesh.instance_count = 64
	mesh.visible_instance_count = 0
	var instance := MultiMeshInstance2D.new()
	instance.multimesh = mesh
	instance.texture = effect.texture
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = preload("res://projectiles/projectile_trail.gdshader")
	material.set_shader_parameter("clock_time", _clock)
	material.set_shader_parameter("sizes", Vector2(effect.size, effect.end_size))
	material.set_shader_parameter("start_color", effect.color)
	material.set_shader_parameter("end_color", effect.end_color)
	instance.material = material
	add_child(instance)
	var batch := {"instance": instance, "mesh": mesh, "free": [], "used": 0}
	_batches[key] = batch
	return batch

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0 or (is_inside_tree() and get_tree().paused): return
	_emitted = 0
	_clock += delta
	for i in range(particles.size() - 1, -1, -1):
		var particle := particles[i]
		if _clock - particle.born >= particle.lifetime:
			# The shader already hides it; only the slot returns to the pool.
			particle.free_slots.append(particle.slot)
			particles[i] = particles[-1]
			particles.pop_back()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	for batch in _batches.values(): batch.instance.material.set_shader_parameter("clock_time", _clock)
	if global_transform == _last_transform: return
	_last_transform = global_transform
	var inverse := global_transform.affine_inverse()
	for particle in particles:
		particle.mesh.set_instance_transform_2d(particle.slot, inverse * Transform2D(0, particle.position))

## Rewrites every live particle of `mesh` after its buffer was reallocated.
func _rewrite_batch(mesh: MultiMesh) -> void:
	var inverse := global_transform.affine_inverse()
	for particle in particles:
		if particle.mesh == mesh:
			mesh.set_instance_transform_2d(particle.slot, inverse * Transform2D(0, particle.position))
			mesh.set_instance_custom_data(particle.slot, Color(particle.velocity.x, particle.velocity.y, particle.born, particle.lifetime))

func clear() -> void:
	for particle in particles:
		# Neutralize the slot so even an unexpired particle vanishes right away.
		particle.mesh.set_instance_custom_data(particle.slot, Color(0, 0, -1.0e9, 1))
		particle.free_slots.append(particle.slot)
	particles.clear()
	_emitted = 0

func _exit_tree() -> void:
	if get_parent() != null and get_parent().has_meta("projectile_trails") and get_parent().get_meta("projectile_trails") == self:
		get_parent().remove_meta("projectile_trails")
