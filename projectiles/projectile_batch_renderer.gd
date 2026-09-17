extends Node2D
## One renderer per projectile parent. Simulation and physics remain on projectiles.

const DEBUG_SHADER = preload("res://projectiles/projectile_hitbox.gdshader")
var projectiles: Array[Node2D] = []
var extra_debug_shapes: Array[CollisionShape2D] = []
var _batches: Dictionary = {}
var _laser_meshes: Array[ArrayMesh] = []
var _commands: Array = []
var _debug: MultiMeshInstance2D
var _debug_mesh := MultiMesh.new()
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _draw_items: Array[RID] = []
var _textures: Dictionary = {}
var _texture_materials: Dictionary = {}
static var _additive_texture_shader: Shader

static func register(projectile: Node2D) -> Node2D:
	var parent := projectile.get_parent()
	var renderer := parent.get_node_or_null("ProjectileBatchRenderer")
	if renderer == null and parent.has_meta("projectile_renderer"):
		renderer = parent.get_meta("projectile_renderer")
	if renderer == null:
		renderer = load("res://projectiles/projectile_batch_renderer.gd").new()
		renderer.name = "ProjectileBatchRenderer"
		# Registration can happen while the parent is adding its children.
		parent.add_child.call_deferred(renderer)
		parent.set_meta("projectile_renderer", renderer)
	renderer.projectiles.append(projectile)
	return renderer

func _ready() -> void:
	var color_material := ShaderMaterial.new()
	color_material.shader = preload("res://projectiles/projectile_color.gdshader")
	material = color_material
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_debug_mesh.transform_format = MultiMesh.TRANSFORM_2D
	_debug_mesh.use_custom_data = true
	_debug_mesh.mesh = quad
	_debug = MultiMeshInstance2D.new()
	_debug.multimesh = _debug_mesh
	var shader_material := ShaderMaterial.new()
	shader_material.shader = DEBUG_SHADER
	_debug.material = shader_material
	_debug.z_index = 1
	add_child(_debug)

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	projectiles = projectiles.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())
	_vertices.clear()
	_colors.clear()
	_indices.clear()
	_commands.clear()
	var laser_run := 0
	var previous_key := ""
	var run := 0
	var members_in_run: Array = []
	var inverse := global_transform.affine_inverse()
	var groups: Dictionary = {}
	var debug_shapes: Array[CollisionShape2D] = []
	for shape in extra_debug_shapes:
		if is_instance_valid(shape) and shape.is_visible_in_tree() and not shape.disabled:
			debug_shapes.append(shape)
	for projectile in projectiles:
		if not projectile.is_visible_in_tree():
			continue
		if projectile is FoundationBullet:
			if not _vertices.is_empty():
				_flush_lasers(laser_run)
				laser_run += 1
			var appearance_key: String = projectile._render_key
			if appearance_key != previous_key:
				run += 1
				members_in_run = []
				var key := str(run, ":", appearance_key)
				groups[key] = members_in_run
				_commands.append(key)
			previous_key = appearance_key
			members_in_run.append(projectile)
		elif projectile is CurvedLaser and projectile.age > 0.001:
			previous_key = ""
			_append_laser(projectile)
		if projectile.show_hitbox:
			for child in projectile._hitbox.get_children():
				if child is CollisionShape2D and not child.disabled:
					debug_shapes.append(child)
	if not _vertices.is_empty():
		_flush_lasers(laser_run)
	for key in _batches.keys():
		if not groups.has(key):
			_batches.erase(key)
			_textures.erase(key)
			_texture_materials.erase(key)
	for key in groups:
		var members: Array = groups[key]
		if not _batches.has(key):
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_2D
			batch.use_colors = true
			batch.use_custom_data = true
			var appearance: BulletAppearance = members[0].appearance
			if appearance.form == BulletAppearance.Form.TEXTURED:
				var quad := QuadMesh.new()
				quad.size = Vector2(2, 2)
				batch.mesh = quad
				_textures[key] = appearance.texture
				_texture_materials[key] = _make_texture_materials(appearance)
			else:
				batch.mesh = _make_bullet_mesh(appearance)
			_batches[key] = batch
		var batch: MultiMesh = _batches[key]
		if batch.instance_count < members.size():
			batch.instance_count = maxi(members.size(), batch.instance_count * 2)
		batch.visible_instance_count = members.size()
		for i in members.size():
			batch.set_instance_transform_2d(i, (inverse * members[i].global_transform).scaled_local(Vector2.ONE * members[i].visual_scale))
			var modulation: Color = members[i].modulate * members[i].self_modulate
			modulation.a *= members[i].render_opacity
			batch.set_instance_color(i, modulation)
			batch.set_instance_custom_data(i, members[i].render_tint)
	if _debug_mesh.instance_count < debug_shapes.size():
		_debug_mesh.instance_count = maxi(debug_shapes.size(), _debug_mesh.instance_count * 2)
	_debug_mesh.visible_instance_count = debug_shapes.size()
	for i in debug_shapes.size():
		var collision := debug_shapes[i]
		var rectangle := collision.shape is RectangleShape2D
		var radius: float = collision.shape.size.x * 0.5 if rectangle else collision.shape.radius
		var half_height: float = collision.shape.height * 0.5 if collision.shape is CapsuleShape2D else radius
		if rectangle: half_height = collision.shape.size.y * 0.5
		var pose := inverse * collision.global_transform
		_debug_mesh.set_instance_transform_2d(i, pose.scaled_local(Vector2(radius, half_height)))
		_debug_mesh.set_instance_custom_data(i, Color(half_height / radius, 1 if rectangle else 0, 0, 0))
	queue_redraw()

func _draw() -> void:
	var index := 0
	for command in _commands:
		if command is String:
			if _textures.has(command):
				for layer_material in _texture_materials[command]:
					var item := _draw_item(index, layer_material)
					RenderingServer.canvas_item_add_multimesh(item, _batches[command].get_rid(), _textures[command].get_rid())
					index += 1
			else:
				RenderingServer.canvas_item_add_multimesh(_draw_item(index, material), _batches[command].get_rid())
				index += 1
		else:
			RenderingServer.canvas_item_add_mesh(_draw_item(index, material), command.get_rid())
			index += 1
	for unused in range(index, _draw_items.size()):
		RenderingServer.canvas_item_clear(_draw_items[unused])

func _draw_item(index: int, draw_material: Material) -> RID:
	if index == _draw_items.size():
		var item := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, get_canvas_item())
		RenderingServer.canvas_item_set_draw_index(item, index)
		RenderingServer.canvas_item_set_default_texture_filter(item, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
		_draw_items.append(item)
	var item := _draw_items[index]
	RenderingServer.canvas_item_clear(item)
	RenderingServer.canvas_item_set_material(item, draw_material.get_rid())
	return item

func _exit_tree() -> void:
	for item in _draw_items: RenderingServer.free_rid(item)
	_draw_items.clear()

static func _make_texture_materials(appearance: BulletAppearance) -> Array[ShaderMaterial]:
	var shader := preload("res://projectiles/projectile_texture.gdshader")
	if _additive_texture_shader == null:
		_additive_texture_shader = Shader.new()
		_additive_texture_shader.code = shader.code.replace("blend_mix", "blend_add")
	var result: Array[ShaderMaterial] = []
	for i in 3:
		var mat := ShaderMaterial.new()
		mat.shader = _additive_texture_shader if i < 2 else shader
		mat.set_shader_parameter("layer_size", [appearance.wide_size, appearance.tight_size, appearance.core_size][i])
		mat.set_shader_parameter("layer_color", [appearance.wide_color, appearance.tight_color, appearance.core_color][i])
		mat.set_shader_parameter("blur_radius", [9.0, 2.5, 0.0][i])
		mat.set_shader_parameter("intensity", [0.8, 1.15, 1.0][i])
		result.append(mat)
	return result

func _flush_lasers(index: int) -> void:
	if _laser_meshes.size() <= index:
		_laser_meshes.append(ArrayMesh.new())
	var mesh := _laser_meshes[index]
	mesh.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var metadata := PackedVector2Array()
	metadata.resize(_vertices.size())
	metadata.fill(Vector2(-1, -1))
	arrays[Mesh.ARRAY_TEX_UV] = metadata
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_commands.append(mesh)
	_vertices.clear()
	_colors.clear()
	_indices.clear()

func _append_laser(laser: CurvedLaser) -> void:
	var pose := global_transform.affine_inverse()
	var widths := [2.6, 1.5, 1.0]
	var colors := [Color(1, 0.4, 0.03, 0.12), Color(1, 0.75, 0.12, 0.55), Color(1, 0.98, 0.66)]
	for layer in 3:
		var base := _vertices.size()
		for i in laser._body.size():
			var offset: Vector2 = laser._ribbon_offsets[i] * laser.core_width * laser.visual_scale * widths[layer]
			_vertices.append(pose * (laser._body[i] + offset))
			_vertices.append(pose * (laser._body[i] - offset))
			var color: Color = colors[layer] * laser.modulate * laser.self_modulate * laser.render_tint
			color.a *= laser.render_opacity
			_colors.append(color)
			_colors.append(color)
		for i in laser.SEGMENTS:
			var start := base + i * 2
			_indices.append_array(PackedInt32Array([start, start + 1, start + 2, start + 1, start + 3, start + 2]))

func _make_bullet_mesh(appearance: BulletAppearance) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var metadata := PackedVector2Array()
	var scales := [1.65, 1.2, 1.0]
	var shades := [Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.45), Color.WHITE]
	var count := 64 if appearance.form == BulletAppearance.Form.ROUND else 24
	for layer in 3:
		var uv := Vector2(0.75, 1) if layer == 2 else Vector2.ZERO
		var base := vertices.size()
		vertices.append(Vector2.ZERO)
		colors.append(shades[layer])
		metadata.append(uv)
		var size := appearance.core_size * 0.5 * float(scales[layer])
		if appearance.form == BulletAppearance.Form.ROUND:
			size.y = size.x
		for i in count:
			var angle := TAU * i / count
			vertices.append(Vector2(sin(angle), cos(angle)) * size)
			colors.append(shades[layer])
			metadata.append(uv)
		for i in count:
			indices.append_array(PackedInt32Array([base, base + 1 + i, base + 1 + (i + 1) % count]))
		# A transparent fringe retains the round core's antialiased edge.
		if appearance.form == BulletAppearance.Form.ROUND:
			for i in count:
				var angle := TAU * i / count
				vertices.append(Vector2(sin(angle), cos(angle)) * (size + Vector2.ONE))
				colors.append(Color(shades[layer], 0))
				metadata.append(uv)
			for i in count:
				var a := base + 1 + i
				var b := base + 1 + (i + 1) % count
				indices.append_array(PackedInt32Array([a, a + count, b, b, a + count, b + count]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = metadata
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
