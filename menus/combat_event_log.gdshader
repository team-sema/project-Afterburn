shader_type canvas_item;
render_mode blend_premul_alpha;
uniform float scan_age = 1.0;
uniform float curvature = 0.035;
uniform float arc = 0.045;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 curved = p * (1.0 + curvature * dot(p, p));
	curved.y -= arc * p.x * p.x;
	vec2 uv = curved * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 ink = texture(TEXTURE, uv);
		vec2 spread = TEXTURE_PIXEL_SIZE * 2.0;
		float halo = (texture(TEXTURE, uv + vec2(spread.x, 0.0)).a
			+ texture(TEXTURE, uv - vec2(spread.x, 0.0)).a
			+ texture(TEXTURE, uv + vec2(0.0, spread.y)).a
			+ texture(TEXTURE, uv - vec2(0.0, spread.y)).a) * 0.045;
		halo *= 1.0 - ink.a;
		float sweep = 0.0;
		if (scan_age < 0.45) {
			float head = mix(-0.12, 1.12, scan_age / 0.45);
			sweep = max(0.0, 1.0 - abs(UV.x - head) / 0.12) * 0.3;
		}
		// The viewport stores premultiplied ink; preserve its transparent backdrop.
		COLOR = vec4(ink.rgb * (1.0 + sweep) + vec3(0.3, 0.85, 0.9) * halo,
			min(1.0, ink.a + halo));
	}
}
