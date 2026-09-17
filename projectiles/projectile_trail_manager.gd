class_name ProjectileTrailManager
extends Node2D
## One bounded decorative pool per projectile world, independent of emitters.
const MAX_PARTICLES := 4096
const MAX_PER_TICK := 256
class Particle extends RefCounted:
	var position: Vector2
	var velocity: Vector2
	var age: float
	var born: float
	var effect: BulletTrailEffect
	var key: String

var particles: Array[Particle] = []
var dropped := 0
var _emitted := 0
var _batches := {}
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _dirty := true
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
	var velocity := backwards.rotated(deg_to_rad(_rng.randf_range(-effect.spread_degrees, effect.spread_degrees))) * _rng.randf_range(effect.speed_min, effect.speed_max)
	var key := str(effect.texture.get_rid(), effect.size, effect.end_size, effect.color, effect.end_color)
	var particle := Particle.new()
	particle.position = position_world
	particle.velocity = velocity
	particle.age = elapsed
	particle.born = _clock - elapsed
	particle.effect = effect
	particle.key = key
	particles.append(particle)
	_dirty = true
	return true

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0 or (is_inside_tree() and get_tree().paused): return
	_emitted = 0
	_clock += delta
	for i in range(particles.size() - 1, -1, -1):
		var particle := particles[i]
		particle.age += delta
		if particle.age >= particle.effect.lifetime:
			particles[i] = particles[-1]
			particles.pop_back()
			_dirty = true

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	for batch in _batches.values(): batch.material.set_shader_parameter("clock_time", _clock)
	if not _dirty and global_transform == _last_transform: return
	_dirty = false
	_last_transform = global_transform
	var groups := {}
	for particle in particles:
		var key: String = particle.key
		if not groups.has(key): groups[key] = []
		groups[key].append(particle)
	for key in _batches.keys():
		if not groups.has(key):
			_batches[key].queue_free()
			_batches.erase(key)
	var inverse := global_transform.affine_inverse()
	for key in groups:
		var members: Array = groups[key]
		if not _batches.has(key):
			var instance := MultiMeshInstance2D.new()
			var mesh := MultiMesh.new()
			mesh.transform_format = MultiMesh.TRANSFORM_2D
			mesh.use_custom_data = true
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			mesh.mesh = quad
			instance.multimesh = mesh
			instance.texture = members[0].effect.texture
			instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://projectiles/projectile_trail.gdshader")
			mat.set_shader_parameter("clock_time", _clock)
			mat.set_shader_parameter("sizes", Vector2(members[0].effect.size, members[0].effect.end_size))
			mat.set_shader_parameter("start_color", members[0].effect.color)
			mat.set_shader_parameter("end_color", members[0].effect.end_color)
			instance.material = mat
			add_child(instance)
			_batches[key] = instance
		var mesh: MultiMesh = _batches[key].multimesh
		if mesh.instance_count < members.size(): mesh.instance_count = mini(MAX_PARTICLES, maxi(members.size(), mesh.instance_count * 2))
		mesh.visible_instance_count = members.size()
		for i in members.size():
			var particle: Particle = members[i]
			var pose := Transform2D(0, particle.position)
			mesh.set_instance_transform_2d(i, inverse * pose)
			mesh.set_instance_custom_data(i, Color(particle.velocity.x, particle.velocity.y, particle.born, particle.effect.lifetime))

func clear() -> void:
	particles.clear()
	_dirty = true
	_emitted = 0
	for batch in _batches.values(): batch.multimesh.visible_instance_count = 0

func _exit_tree() -> void:
	if get_parent() != null and get_parent().has_meta("projectile_trails") and get_parent().get_meta("projectile_trails") == self:
		get_parent().remove_meta("projectile_trails")
