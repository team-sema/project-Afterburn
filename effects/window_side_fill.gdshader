shader_type canvas_item;
render_mode unshaded;
uniform vec2 extent = vec2(100.0, 360.0);
uniform bool right_side = false;
uniform float elapsed = 0.0;
// source_color converts this sRGB palette to linear only when HDR 2D needs it.
uniform vec4 space_dark : source_color = vec4(0.009, 0.018, 0.034, 1.0);
uniform vec4 cloud_tint : source_color = vec4(0.025, 0.063, 0.088, 1.0);
uniform vec4 star_tint : source_color = vec4(0.18, 0.25, 0.30, 1.0);
uniform vec4 edge_tint : source_color = vec4(0.003, 0.007, 0.014, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Coordinates measured outwards from the cockpit keep resizing stable.
	float outward = right_side ? UV.x : 1.0 - UV.x;
	vec2 p = vec2(outward * extent.x, UV.y * extent.y);
	vec2 space = vec2(p.x + (right_side ? 271.0 : 0.0), p.y - elapsed * 12.0);
	float cloud = sin(space.x * 0.013 + sin(space.y * 0.011))
		* sin(space.y * 0.008 + space.x * 0.006) * 0.5 + 0.5;
	vec3 color = mix(space_dark.rgb, cloud_tint.rgb, cloud);
	vec2 cell = floor(space / 19.0);
	vec2 center = vec2(hash(cell + 7.0), hash(cell + 31.0)) * 0.7 + 0.15;
	float star = 1.0 - smoothstep(0.20, 0.85, length((fract(space / 19.0) - center) * 19.0));
	color += star_tint.rgb * star * step(0.65, hash(cell));
	float inner_fade = smoothstep(0.0, 28.0, p.x);
	float outer_fade = 1.0 - 0.55 * smoothstep(0.35, 1.0, outward);
	float vertical_fade = 0.65 + 0.35 * sin(UV.y * 3.14159265);
	color = mix(edge_tint.rgb, color, inner_fade * outer_fade * vertical_fade);
	COLOR = vec4(color, 1.0);
}
