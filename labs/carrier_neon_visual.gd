extends RefCounted
## Same mask/core/glow stack as Elite Fighter. No gameplay state.
static func make(texture: Texture2D, visual_scale: float, energy: Color) -> Node2D:
	var root := Node2D.new()
	for entry in [["WideGlow", 22.0, 0.22], ["TightGlow", 7.0, 0.55], ["Core", 0.0, 1.0]]:
		var sprite := Sprite2D.new()
		sprite.name = entry[0]
		sprite.texture = texture
		sprite.scale = Vector2.ONE * visual_scale
		if entry[1] > 0:
			var glow := ShaderMaterial.new()
			glow.shader = preload("res://effects/elite_glow.gdshader")
			glow.set_shader_parameter("radius", entry[1])
			glow.set_shader_parameter("padding", 24.0)
			sprite.material = glow
			sprite.self_modulate = Color(energy, entry[2])
		else:
			sprite.material = preload("res://effects/core_unshaded_material.tres")
			sprite.self_modulate = Color(1.0, 0.91, 0.95)
		root.add_child(sprite)
	return root
