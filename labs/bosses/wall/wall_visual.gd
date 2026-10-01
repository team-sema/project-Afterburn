extends RefCounted
## Shared white-mask neon stack plus matching layered strokes for moving machinery.
const Shared = preload("res://labs/bosses/carrier/carrier_neon_visual.gd")
const STRUCTURE := Color(0.58, 0.36, 1.0)
const SIGNAL := Color(1.0, 0.16, 0.2)

static func make(texture: Texture2D, visual_scale: float, energy: Color, body_texture: Texture2D = null) -> Node2D:
	var visual := Shared.make(texture, visual_scale, energy)
	# Narrow enough to preserve the large frame's transparent cuts at 300px field width.
	visual.get_node("TightGlow").material.set_shader_parameter("radius", 4.0)
	visual.get_node("WideGlow").material.set_shader_parameter("radius", 18.0)
	if body_texture != null:
		var body := Sprite2D.new()
		body.name = "Body"
		body.texture = body_texture
		body.scale = Vector2.ONE * visual_scale
		body.material = preload("res://effects/core_unshaded_material.tres")
		visual.add_child(body)
		visual.move_child(body, 0)
	return visual

## Structural cores stay below active white targets. Power down dims every layer together.
static func structure(visual: Node2D, power: float, warning: float = 0.0) -> void:
	var body := visual.get_node_or_null("Body") as Sprite2D
	if body != null:
		# Keep alpha at one even after shutdown: a dead wall still occludes the stars.
		body.self_modulate = Color(0.065, 0.04, 0.12).lerp(Color(0.025, 0.018, 0.05), 1.0 - clampf(power, 0.0, 1.0))
	var tone := STRUCTURE.lerp(SIGNAL, warning)
	var level := lerpf(0.12, 1.0, clampf(power, 0.0, 1.0))
	visual.get_node("Core").self_modulate = Color(tone.lerp(Color.WHITE, 0.5) * (0.58 * level), 1.0)
	visual.get_node("TightGlow").self_modulate = Color(tone, (0.26 + warning * 0.18) * level)
	visual.get_node("WideGlow").self_modulate = Color(tone, 0.08 * level)

static func stroke(node: Node2D, points: PackedVector2Array, energy: Color, width: float = 1.0, level: float = 1.0) -> void:
	if points.size() < 2: return
	node.draw_polyline(points, Color(energy, 0.025 * level), width + 5.0, true)
	node.draw_polyline(points, Color(energy, 0.12 * level), width + 2.0, true)
	node.draw_polyline(points, Color(energy.lerp(Color.WHITE, 0.3) * level, 1.0), width, true)

static func line(node: Node2D, start: Vector2, end: Vector2, energy: Color, width: float = 1.0, level: float = 1.0) -> void:
	stroke(node, PackedVector2Array([start, end]), energy, width, level)
