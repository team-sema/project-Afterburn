class_name EnemyBulletPool
extends Node2D
## One per projectile parent. Steps every FoundationBullet under that parent
## in a single loop, tests them against player-side hurtboxes on the CPU and
## writes their MultiMesh instances straight from the physics tick. Bullets
## stay lightweight Nodes (tree, groups, queue_free, pause, instance ids keep
## working) but own no Area2D and no per-node processing. Rules: combat.md 탄,
## barrage-api.md 9·11절.

const BATCH_RENDERER := preload("res://projectiles/projectile_batch_renderer.gd")
const COLOR_SHADER := preload("res://projectiles/projectile_color.gdshader")
const META := &"enemy_bullet_pool"
const OFFSCREEN := Transform2D(0.0, Vector2(-100000.0, -100000.0))
const DEBUG_COLOR := Color(0.2, 1.0, 0.75, 0.7)


class RenderGroup:
	var key := ""
	var appearance: BulletAppearance
	var multimesh := MultiMesh.new()
	var members: Array[FoundationBullet] = []
	var items: Array[RID] = []
	var materials: Array[Material] = []


## A hurtbox shape bullets can hit this tick, flattened for the hot loop.
class Target:
	var hurtbox: HurtboxComponent
	## 0 = circle, 1 = capsule (segment a-b), 2 = any other Shape2D.
	var kind := 0
	var center := Vector2.ZERO
	var radius := 0.0
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var shape: Shape2D
	var transform := Transform2D.IDENTITY


var _bullets: Array[FoundationBullet] = []
var _groups: Dictionary = {}
var _color_material: ShaderMaterial
## Stand-in HitboxComponent handed to hurtboxes so the damage pipeline sees the
## same object type and hit position as before.
var _proxy: HitboxComponent
var _targets: Array[Target] = []
var _debug_count := 0
var _capsule := CapsuleShape2D.new()
## Extra shapes drawn with the debug outlines (lab: the target hurtbox).
var extra_debug_shapes: Array[CollisionShape2D] = []


## Returns the pool under `parent`, creating it on first use.
static func for_parent(parent: Node) -> EnemyBulletPool:
	if parent.has_meta(META):
		var existing: Variant = parent.get_meta(META)
		# The meta may point at a pool freed with a world reset.
		if is_instance_valid(existing) and existing is EnemyBulletPool and not (existing as Node).is_queued_for_deletion():
			return existing as EnemyBulletPool
	var pool := EnemyBulletPool.new()
	pool.name = "EnemyBulletPool"
	# Registration can happen while the parent is still adding children.
	parent.add_child.call_deferred(pool)
	parent.set_meta(META, pool)
	return pool


func _init() -> void:
	_color_material = ShaderMaterial.new()
	_color_material.shader = COLOR_SHADER
	_proxy = HitboxComponent.new()
	_proxy.name = "HitProxy"
	_proxy.collision_layer = 0
	_proxy.collision_mask = 0
	_proxy.monitoring = false
	_proxy.monitorable = false
	add_child(_proxy)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Bullets simulate before anything that reads their positions this tick.
	process_physics_priority = -10


func _exit_tree() -> void:
	# Children leave the tree last-to-first, so the pool (added last) goes
	# before its bullets: detach them now so their own exit is a no-op.
	for group: RenderGroup in _groups.values():
		for item in group.items:
			RenderingServer.free_rid(item)
		group.items.clear()
		for bullet in group.members:
			if is_instance_valid(bullet):
				bullet._group = null
				bullet._slot = -1
				bullet._index = -1
		group.members.clear()
	_groups.clear()
	_bullets.clear()


# --- Registration ----------------------------------------------------------

## Called by FoundationBullet._ready. The bullet is drawn once it launches.
func register(bullet: FoundationBullet) -> void:
	var group := _group_for(bullet.appearance)
	bullet._group = group
	bullet._slot = group.members.size()
	group.members.append(bullet)
	var multimesh := group.multimesh
	if multimesh.instance_count < group.members.size():
		_grow(group, maxi(group.members.size(), multimesh.instance_count * 2))
	multimesh.visible_instance_count = group.members.size()
	multimesh.set_instance_transform_2d(bullet._slot, OFFSCREEN)
	multimesh.set_instance_color(bullet._slot, Color.WHITE)
	multimesh.set_instance_custom_data(bullet._slot, bullet.render_tint)
	bullet._index = _bullets.size()
	_bullets.append(bullet)
	bullet.tree_exiting.connect(_unregister.bind(bullet))
	if bullet.show_hitbox:
		_debug_count += 1


## Enlarges a group's instance buffer. Setting instance_count reallocates the
## buffer and zeroes every instance (transform, colour, custom data), so the
## live members are uploaded again; static-visual bullets never rewrite their
## colour on their own and would otherwise turn invisible.
func _grow(group: RenderGroup, count: int) -> void:
	var multimesh := group.multimesh
	multimesh.instance_count = count
	for member in group.members:
		if member._slot < 0:
			continue
		multimesh.set_instance_color(member._slot, Color(1, 1, 1, member.render_opacity) if member._active else Color.WHITE)
		multimesh.set_instance_custom_data(member._slot, member.render_tint)
		if member._active and member.visible:
			multimesh.set_instance_transform_2d(member._slot, Transform2D(member.global_rotation, Vector2.ONE * member.visual_scale, 0.0, member.global_position))
		else:
			multimesh.set_instance_transform_2d(member._slot, OFFSCREEN)


func _unregister(bullet: FoundationBullet) -> void:
	var group: RenderGroup = bullet._group
	if group == null:
		return
	bullet._group = null
	if bullet.show_hitbox:
		_debug_count = maxi(_debug_count - 1, 0)
	var hole := bullet._slot
	var last := group.members.size() - 1
	var multimesh := group.multimesh
	if hole != last:
		# Keep the instance range packed: the last live member fills the hole.
		var moved := group.members[last]
		moved._slot = hole
		group.members[hole] = moved
		_write_instance(moved)
	group.members.resize(last)
	multimesh.set_instance_transform_2d(last, OFFSCREEN)
	multimesh.visible_instance_count = last
	bullet._slot = -1
	# Blank its active-list entry so the pass never touches a freed object.
	var index := bullet._index
	if index >= 0 and index < _bullets.size() and _bullets[index] == bullet:
		_bullets[index] = null
	bullet._index = -1


func get_active_count() -> int:
	var count := 0
	for bullet in _bullets:
		if bullet != null and bullet._group != null and bullet._active and not bullet.is_queued_for_deletion():
			count += 1
	return count


## Notifies the pool that show_hitbox changed on `bullet`.
func debug_changed(bullet: FoundationBullet, shown: bool) -> void:
	if bullet._group == null:
		return
	_debug_count = maxi(_debug_count + (1 if shown else -1), 0)
	queue_redraw()


# --- Tick ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var frame := int(Engine.get_physics_frames())
	var bounds := get_viewport_rect()
	collect_targets(get_tree(), _targets)
	var targets := _targets
	var target_count := targets.size()
	var write := 0
	var count := _bullets.size()
	for read in count:
		var bullet := _bullets[read]
		if bullet == null or bullet._group == null:
			continue # unregistered (freed or left the tree)
		if not bullet._active or bullet._spawn_frame == frame:
			bullet._index = write
			_bullets[write] = bullet
			write += 1
			continue
		# A frozen bullet (simulating = false: tests, lab) keeps its place but
		# still collides and draws, like a stationary Area2D did.
		var point := bullet.global_position
		if bullet.simulating:
			point = bullet._tick(delta, bounds)
		if bullet._group == null:
			continue # consumed by a SPAWN, expired or left the view
		if target_count > 0 and bullet.tangible:
			var reach := bullet._bounding_radius * bullet.hitbox_scale
			for index in target_count:
				var target := targets[index]
				var span := reach + target.radius
				if absf(target.center.x - point.x) > span or absf(target.center.y - point.y) > span:
					continue
				if _overlaps_target(bullet, point, target) and _deliver_hit(bullet, point, target.hurtbox):
					break
			if bullet._group == null:
				continue
		# Inline instance write (see _write_instance) to save a call per bullet.
		var multimesh: MultiMesh = bullet._group.multimesh
		if bullet.visible:
			if not bullet._static_visuals:
				multimesh.set_instance_color(bullet._slot, Color(1, 1, 1, bullet.render_opacity))
				multimesh.set_instance_custom_data(bullet._slot, bullet.render_tint)
			multimesh.set_instance_transform_2d(bullet._slot, Transform2D(bullet.global_rotation, Vector2.ONE * bullet.visual_scale, 0.0, point))
		else:
			multimesh.set_instance_transform_2d(bullet._slot, OFFSCREEN)
		bullet._index = write
		_bullets[write] = bullet
		write += 1
	# SPAWN children registered during this pass sit past `count`; keep them.
	var total := _bullets.size()
	for extra in range(count, total):
		var late := _bullets[extra]
		if late == null:
			continue
		late._index = write
		_bullets[write] = late
		write += 1
	_bullets.resize(write)
	if _debug_count > 0 or not extra_debug_shapes.is_empty():
		queue_redraw()


func _write_instance(bullet: FoundationBullet) -> void:
	var multimesh: MultiMesh = bullet._group.multimesh
	if not bullet.visible or not bullet._active:
		multimesh.set_instance_transform_2d(bullet._slot, OFFSCREEN)
		return
	var pose := Transform2D(bullet.global_rotation, Vector2.ONE * bullet.visual_scale, 0.0, bullet.global_position)
	if not bullet._static_visuals:
		multimesh.set_instance_color(bullet._slot, Color(1, 1, 1, bullet.render_opacity))
		multimesh.set_instance_custom_data(bullet._slot, bullet.render_tint)
	multimesh.set_instance_transform_2d(bullet._slot, pose)


# --- Collision -------------------------------------------------------------

## Player-side hurtboxes (EnemyBullets.TARGET_GROUP) with their enabled shapes,
## flattened into `out` (cleared first). Shared with the laser bodies.
static func collect_targets(tree: SceneTree, out: Array[Target]) -> void:
	out.clear()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(EnemyBullets.TARGET_GROUP):
		var hurtbox := node as HurtboxComponent
		if hurtbox == null or not hurtbox.is_inside_tree() or hurtbox.is_invincible or not hurtbox.monitoring:
			continue
		for child in hurtbox.get_children():
			var collision := child as CollisionShape2D
			if collision == null or collision.disabled or collision.shape == null:
				continue
			var target := Target.new()
			target.hurtbox = hurtbox
			var xform := collision.global_transform
			var scale := xform.get_scale()
			var shape := collision.shape
			if shape is CircleShape2D:
				target.kind = 0
				target.center = xform.origin
				target.radius = (shape as CircleShape2D).radius * maxf(absf(scale.x), absf(scale.y))
			elif shape is CapsuleShape2D:
				var capsule := shape as CapsuleShape2D
				target.kind = 1
				target.radius = capsule.radius * maxf(absf(scale.x), absf(scale.y))
				var half := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
				target.a = xform * Vector2(0.0, -half)
				target.b = xform * Vector2(0.0, half)
				target.center = (target.a + target.b) * 0.5
				target.radius += target.a.distance_to(target.center)
			else:
				target.kind = 2
				target.shape = shape
				target.transform = xform
				target.center = xform.origin
				var rect := shape.get_rect()
				target.radius = (rect.size * scale).length() * 0.5 + rect.position.length() * maxf(absf(scale.x), absf(scale.y))
			out.append(target)


## Distance test used by laser bodies: the segment a-b with radius `width`
## against one target. Returns the closest point on a-b, or null when apart.
static func segment_hits(a: Vector2, b: Vector2, width: float, target: Target) -> Variant:
	match target.kind:
		0:
			var closest := Geometry2D.get_closest_point_to_segment(target.center, a, b)
			var reach := width + target.radius
			return closest if closest.distance_squared_to(target.center) <= reach * reach else null
		1:
			var pair := Geometry2D.get_closest_points_between_segments(a, b, target.a, target.b)
			var reach := width + (target.radius - target.a.distance_to(target.center))
			return pair[0] if pair[0].distance_squared_to(pair[1]) <= reach * reach else null
		_:
			var capsule := CapsuleShape2D.new()
			capsule.radius = width
			capsule.height = a.distance_to(b) + width * 2.0
			var xform := Transform2D((b - a).angle() - PI * 0.5, (a + b) * 0.5)
			return (a + b) * 0.5 if capsule.collide(xform, target.shape, target.transform) else null


func _overlaps_target(bullet: FoundationBullet, point: Vector2, target: Target) -> bool:
	var appearance := bullet.appearance
	var scale := bullet.hitbox_scale
	var center := point + (appearance.collision_offset * scale).rotated(bullet.global_rotation)
	match target.kind:
		0:
			match appearance.form:
				BulletAppearance.Form.ROUND:
					var reach := appearance.collision_radius * scale + target.radius
					return center.distance_squared_to(target.center) <= reach * reach
				BulletAppearance.Form.RICE:
					var radius := appearance.collision_radius * scale
					var half := maxf(appearance.collision_height * 0.5 * scale - radius, 0.0)
					var axis := Vector2.UP.rotated(bullet.global_rotation) * half
					var closest := Geometry2D.get_closest_point_to_segment(target.center, center - axis, center + axis)
					var reach := radius + target.radius
					return closest.distance_squared_to(target.center) <= reach * reach
				_:
					var local := (target.center - center).rotated(-bullet.global_rotation)
					var half_size := appearance.collision_size * 0.5 * scale
					var clamped := Vector2(clampf(local.x, -half_size.x, half_size.x), clampf(local.y, -half_size.y, half_size.y))
					return clamped.distance_squared_to(local) <= target.radius * target.radius
		1:
			# Capsule target (e.g. a barrier segment): the exact test for circles
			# and rice; textured rectangles use the generic shape test.
			var radius := appearance.collision_radius * scale
			if appearance.form == BulletAppearance.Form.ROUND:
				var closest := Geometry2D.get_closest_point_to_segment(center, target.a, target.b)
				var reach := radius + (target.radius - target.a.distance_to(target.center))
				return closest.distance_squared_to(center) <= reach * reach
			if appearance.form == BulletAppearance.Form.RICE:
				var half := maxf(appearance.collision_height * 0.5 * scale - radius, 0.0)
				var axis := Vector2.UP.rotated(bullet.global_rotation) * half
				var pair := Geometry2D.get_closest_points_between_segments(center - axis, center + axis, target.a, target.b)
				var reach := radius + (target.radius - target.a.distance_to(target.center))
				return pair[0].distance_squared_to(pair[1]) <= reach * reach
			_capsule.radius = target.radius - target.a.distance_to(target.center)
			_capsule.height = target.a.distance_to(target.b) + _capsule.radius * 2.0
			var xform := Transform2D((target.b - target.a).angle() - PI * 0.5, target.center)
			return bullet.collision_shape().collide(bullet.collision_transform(), _capsule, xform)
		_:
			return bullet.collision_shape().collide(bullet.collision_transform(), target.shape, target.transform)


## Runs the HitboxComponent damage pipeline with the shared proxy standing in
## for the bullet, then frees the bullet. Returns false when the hurtbox could
## not take the hit (the same early-outs HitboxComponent applies).
func _deliver_hit(bullet: FoundationBullet, point: Vector2, hurtbox: HurtboxComponent) -> bool:
	if hurtbox.is_invincible or not hurtbox.is_inside_tree() or not _proxy.is_inside_tree():
		return false
	_proxy.global_position = point
	_proxy.damage = bullet.damage
	_proxy._on_hurtbox_entered(hurtbox)
	bullet._on_hit(hurtbox)
	return true


# --- Rendering -------------------------------------------------------------

func _group_for(appearance: BulletAppearance) -> RenderGroup:
	var key := appearance.render_key()
	var group: RenderGroup = _groups.get(key)
	if group != null:
		return group
	group = RenderGroup.new()
	group.key = key
	group.appearance = appearance
	var multimesh := group.multimesh
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	if appearance.form == BulletAppearance.Form.TEXTURED:
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 2)
		multimesh.mesh = quad
		for layer_material in BATCH_RENDERER._make_texture_materials(appearance):
			var item := _make_item(group, layer_material)
			RenderingServer.canvas_item_add_multimesh(item, multimesh.get_rid(), appearance.texture.get_rid())
	else:
		multimesh.mesh = BATCH_RENDERER._make_bullet_mesh(appearance)
		var item := _make_item(group, _color_material)
		RenderingServer.canvas_item_add_multimesh(item, multimesh.get_rid())
	multimesh.instance_count = 64
	multimesh.visible_instance_count = 0
	_groups[key] = group
	return group


func _make_item(group: RenderGroup, draw_material: Material) -> RID:
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(item, _item_count())
	RenderingServer.canvas_item_set_default_texture_filter(item, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
	RenderingServer.canvas_item_set_material(item, draw_material.get_rid())
	group.items.append(item)
	group.materials.append(draw_material)
	return item


func _item_count() -> int:
	var count := 0
	for group: RenderGroup in _groups.values():
		count += group.items.size()
	return count


## Debug hitbox outlines for bullets with show_hitbox (lab H key).
func _draw() -> void:
	if _debug_count <= 0 and extra_debug_shapes.is_empty():
		return
	var inverse := global_transform.affine_inverse()
	for bullet in _bullets:
		if bullet == null or bullet._group == null or not bullet._active or not bullet.show_hitbox or not bullet.tangible:
			continue
		draw_set_transform_matrix(inverse * bullet.collision_transform())
		bullet.collision_shape().draw(get_canvas_item(), DEBUG_COLOR)
	for shape in extra_debug_shapes:
		if is_instance_valid(shape) and shape.is_inside_tree() and not shape.disabled and shape.shape != null:
			draw_set_transform_matrix(inverse * shape.global_transform)
			shape.shape.draw(get_canvas_item(), DEBUG_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Render groups keyed by appearance render key (tests / diagnostics).
func get_render_groups() -> Dictionary:
	return _groups
