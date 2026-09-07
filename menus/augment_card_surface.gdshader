shader_type canvas_item;
render_mode unshaded;

uniform vec4 metal : source_color = vec4(0.72, 0.83, 0.9, 1.0);
uniform float spectrum_amount : hint_range(0.0, 1.0) = 0.0;
uniform float ray_strength : hint_range(0.0, 2.0) = 0.0;
uniform float ray_speed : hint_range(-3.0, 3.0) = 0.5;
uniform float focus_ring_strength : hint_range(0.0, 2.0) = 0.0;
uniform float base_glow : hint_range(0.0, 1.0) = 0.18;
uniform float base_reflection : hint_range(0.0, 2.0) = 0.12;
uniform float motion = 0.0;
uniform float emphasis = 0.0;
uniform float activation = 0.0;
uniform vec2 surface_size = vec2(172.0, 204.0);
uniform vec2 card_size = vec2(156.0, 188.0);
uniform vec2 surface_offset = vec2(-8.0, -8.0);
uniform vec2 orb_center = vec2(78.0, 51.0);
uniform float halo_radius : hint_range(1.0, 60.0) = 28.0;
uniform float corner_cut : hint_range(0.0, 30.0) = 10.0;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;
uniform float reflection_strength : hint_range(0.0, 3.0) = 1.0;
uniform float spectrum_speed : hint_range(0.0, 0.5) = 0.055;
uniform float halo_strength : hint_range(0.0, 3.0) = 0.09;
uniform float mist_strength : hint_range(0.0, 3.0) = 0.0;

float bevel(vec2 p, vec2 half_size, float cut) {
	vec2 q = abs(p);
	return max(max(q.x - half_size.x, q.y - half_size.y), (q.x + q.y - half_size.x - half_size.y + cut) * 0.7071);
}

vec3 spectrum(float phase) {
	return 0.66 + 0.34 * cos(6.28318 * (phase + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec4 modulation = COLOR;
	vec2 p = UV * surface_size + surface_offset - card_size * 0.5;
	float edge = bevel(p, card_size * 0.5 - vec2(1.0), corner_cut);
	vec3 tint = mix(metal.rgb, spectrum(p.y * 0.003 + p.x * 0.004 + motion * spectrum_speed), spectrum_amount);
	float glow = exp(-max(edge, 0.0) * 0.5) * (base_glow + emphasis * 0.2) * glow_strength;
	vec3 rgb = tint;
	float alpha = glow;
	if (edge < 0.0) {
		alpha = 1.0;
		float depth = -edge;
		float top_light = clamp(0.6 - p.y * 0.004 - p.x * 0.002, 0.2, 1.0);
		rgb = tint * (0.22 + 0.55 * top_light);
		if (depth < 1.1) { rgb = mix(tint, vec3(1.0), 0.6) * (0.65 + top_light * 0.35); }
		else if (depth < 3.8) {
			float facets = 0.5 + 0.5 * sin(p.x * 0.065 + p.y * 0.041);
			rgb = tint * (0.35 + 0.55 * facets + 0.25 * top_light);
		}
		else if (depth < 5.0) { rgb = tint * 0.17; }
		else if (depth < 5.8) { rgb = tint * 0.56; }
		else {
			float wash = exp(-length((p - vec2(0.0, -47.0)) / vec2(65.0, 55.0)));
			rgb = vec3(0.019, 0.032, 0.052) + tint * wash * 0.065;
			vec2 orb = p - (orb_center - card_size * 0.5);
			float radius = length(orb);
			float angle = atan(orb.y, orb.x);
			float halo = exp(-abs(radius - halo_radius) * 0.34);
			float rays = pow(max(0.0, sin(angle * 6.0 + motion * ray_speed + radius * 0.06)), 10.0);
			rgb += tint * halo * halo_strength;
			float focus_ring = exp(-abs(radius - (halo_radius + (1.0 - activation) * 16.0)) * 0.75);
			rgb += tint * focus_ring * activation * focus_ring_strength;
			rgb += spectrum(angle * 0.16 + motion * 0.04) * rays * exp(-radius * 0.044) * ray_strength;
			float mist = sin(p.x * 0.035 + p.y * 0.042 + motion * 0.6) * sin(p.x * 0.027 - p.y * 0.031 - motion * 0.4);
			rgb += tint * max(mist, 0.0) * 0.025 * mist_strength;
		}
		float sweep = pow(max(0.0, cos(p.y * 0.019 + p.x * 0.014 - motion * 1.2)), 32.0);
		rgb += vec3(0.8, 0.93, 1.0) * sweep * (base_reflection + emphasis * 0.35) * (1.0 - step(5.8, depth)) * reflection_strength;
	}
	COLOR = vec4(rgb, alpha * (1.0 - smoothstep(5.0, 8.0, edge))) * modulation;
}
