shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float radius = 7.0;
uniform float padding = 24.0;
uniform bool radial_halo = false;
varying vec4 vertex_tint;

void vertex() {
	// Preserve modulation before fragment COLOR is multiplied by the texture.
	vertex_tint = COLOR;
	if (!radial_halo) {
		VERTEX += (UV * 2.0 - 1.0) * padding;
	}
}

void fragment() {
	float alpha = 0.0;
	if (radial_halo) {
		float distance_from_center = length((UV - 0.5) * 2.0);
		alpha = pow(max(0.0, 1.0 - distance_from_center), 3.0);
	} else {
		vec2 source_uv = (UV - 0.5) * (vec2(1.0) + 2.0 * padding * TEXTURE_PIXEL_SIZE) + 0.5;
		float total_weight = 0.0;
		for (int y = -3; y <= 3; y++) {
			for (int x = -3; x <= 3; x++) {
				vec2 tap = vec2(float(x), float(y));
				float weight = exp(-dot(tap, tap) / 4.5);
				vec2 sample_uv = source_uv + tap * radius / 3.0 * TEXTURE_PIXEL_SIZE;
				if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThanEqual(sample_uv, vec2(1.0)))) {
					alpha += texture(TEXTURE, sample_uv).a * weight;
				}
				total_weight += weight;
			}
		}
		alpha /= total_weight;
	}
	COLOR = vec4(vertex_tint.rgb, alpha * vertex_tint.a);
}
