shader_type canvas_item;
render_mode unshaded;

// A distant broken orbital megastructure. No TIME: the world owns its clock.
uniform vec2 viewport_size = vec2(300.0, 360.0);
uniform float elapsed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float cloud(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.03) * 0.28 + noise(p * 4.17) * 0.17;
}

vec4 over(vec4 back, vec4 front) {
	float a = front.a + back.a * (1.0 - front.a);
	return vec4((front.rgb * front.a + back.rgb * back.a * (1.0 - front.a)) / max(a, 0.0001), a);
}

void fragment() {
	float unit = min(viewport_size.x, viewport_size.y);
	float aa = 1.1 / unit;
	vec2 screen = UV * viewport_size / unit;
	// In wide menus, lift the landmark clear of the central action list.
	float wide_layout = smoothstep(1.1, 1.6, viewport_size.x / viewport_size.y);
	vec2 center = vec2(0.64, 0.045 - wide_layout * 0.19) * viewport_size / unit;
	// Bounded, continuous drift: initially descends with the star flow, never wraps.
	center += vec2(sin(elapsed * 0.013) * 0.015, sin(elapsed * 6.2831853 / 180.0) * 0.06);
	vec2 p = screen - center;
	float tilt = -0.38;
	vec2 q = mat2(vec2(cos(tilt), -sin(tilt)), vec2(sin(tilt), cos(tilt))) * p;
	q /= vec2(0.84, 0.43);
	// Rotate in the orbital plane, not in screen space. The ellipse keeps its
	// perspective while the deck, breaches and local debris revolve together.
	float spin = mod(elapsed * 0.015, 6.2831853);
	q = mat2(vec2(cos(spin), -sin(spin)), vec2(sin(spin), cos(spin))) * q;
	float radius = length(q);
	float angle = mod(atan(q.y, q.x) + 6.2831853, 6.2831853);

	// Cool gas behind the ring, subdued in the lower central flight corridor.
	float clouds = cloud(screen * 3.0 + vec2(elapsed * 0.0015, 0.0));
	float haze = exp(-abs(radius - 1.03) * 3.0) * clouds;
	vec4 result = vec4(vec3(0.025, 0.12, 0.18), haze * 0.48);

	// A dark planet with a thin illuminated horizon behind the artificial ring.
	vec2 planet_p = p - vec2(0.10, -0.15);
	float planet_r = length(planet_p);
	float planet_size = 0.43;
	float planet_mask = 1.0 - smoothstep(planet_size - aa, planet_size + aa, planet_r);
	float limb = exp(-abs(planet_r - planet_size) * 95.0);
	float light_side = clamp(dot(normalize(planet_p + vec2(0.0001)), normalize(vec2(-0.7, -0.5))) * 0.5 + 0.5, 0.0, 1.0);
	float terrain = cloud(planet_p * 11.0);
	vec3 planet = mix(vec3(0.004, 0.012, 0.025), vec3(0.035, 0.11, 0.16), terrain * light_side);
	result = over(result, vec4(planet, planet_mask * 0.98));
	result = over(result, vec4(vec3(0.12, 0.38, 0.48), limb * light_side * 0.65));

	// Two torn sectors; their fracture shape stays fixed to the rotating deck.
	float torn = sin(radius * 160.0) * 0.013 + sin(radius * 71.0) * 0.019;
	float gap_a = smoothstep(0.99 + torn, 1.01 + torn, angle) * (1.0 - smoothstep(1.49 + torn, 1.51 + torn, angle));
	float gap_b = smoothstep(3.68 + torn, 3.70 + torn, angle) * (1.0 - smoothstep(3.87 + torn, 3.89 + torn, angle));
	float intact = 1.0 - max(gap_a, gap_b);
	float band = smoothstep(0.84 - aa, 0.84 + aa, radius) * (1.0 - smoothstep(1.12 - aa, 1.12 + aa, radius));
	float body = band * intact;
	float radial = clamp((radius - 0.84) / 0.28, 0.0, 1.0);
	float segment = angle * 36.0 / 6.2831853;
	float sector = floor(segment);
	float cell = fract(segment);
	float plate_variation = hash(vec2(sector, floor(radial * 4.0)));
	float lighting = 0.55 + 0.45 * sin(angle - 0.4);
	vec3 metal = mix(vec3(0.025, 0.065, 0.09), vec3(0.10, 0.23, 0.27), plate_variation) * lighting;
	// Raised outside armour and a dark recessed middle trench.
	metal *= mix(0.38, 1.0, smoothstep(0.12, 0.16, abs(radial - 0.48)));
	float seam = 1.0 - smoothstep(0.018, 0.035, min(cell, 1.0 - cell));
	metal *= 1.0 - seam * 0.85;
	float cross_brace = 1.0 - smoothstep(0.024, 0.05, abs(cell - radial));
	metal += vec3(0.035, 0.11, 0.13) * cross_brace;
	float rail = exp(-abs(radius - 0.858) * 330.0) + exp(-abs(radius - 1.092) * 330.0);
	metal += vec3(0.13, 0.42, 0.46) * rail * (0.5 + 0.5 * lighting);
	float outer_bevel = exp(-abs(radius - 1.115) * 220.0);
	metal += vec3(0.14, 0.25, 0.28) * outer_bevel;
	float cut_distance = min(min(abs(angle - 1.0 - torn), abs(angle - 1.5 - torn)), min(abs(angle - 3.69 - torn), abs(angle - 3.88 - torn)));
	float heat = exp(-cut_distance * 28.0) * (0.78 + 0.12 * sin(elapsed * 0.38));
	metal += vec3(1.35, 0.36, 0.065) * heat;
	result = over(result, vec4(metal, body));

	// The inner wall sits below the deck and lends thickness to the silhouette.
	float wall = smoothstep(0.79, 0.795, radius) * (1.0 - smoothstep(0.839, 0.843, radius)) * intact;
	float ribs = step(0.83, fract(segment * 3.0));
	vec3 wall_color = vec3(0.008, 0.025, 0.037) + vec3(0.025, 0.095, 0.105) * ribs;
	wall_color += vec3(0.5, 0.12, 0.018) * heat;
	result = over(result, vec4(wall_color, wall));
	float fracture_glow = exp(-cut_distance * 22.0) * exp(-abs(radius - 0.97) * 14.0);
	result = over(result, vec4(vec3(0.90, 0.24, 0.045), fracture_glow * 0.30));

	// Large drifting armour chunks remain local to the breach, never bright dots.
	for (int i = 0; i < 7; i++) {
		float index = float(i);
		float a = 1.07 + index * 0.055;
		float r = 0.90 + hash(vec2(index, 8.0)) * 0.25;
		vec2 debris_center = vec2(cos(a), sin(a)) * r;
		debris_center += vec2(sin(elapsed * 0.025 + index), cos(elapsed * 0.021 + index)) * 0.009;
		vec2 d = abs(q - debris_center);
		float size = 0.013 + hash(vec2(index, 2.0)) * 0.023;
		float block = max(d.x, max(d.y * 1.7, (d.x + d.y) * 0.8));
		float mask = 1.0 - smoothstep(size - aa, size + aa, block);
		vec3 chunk = mix(vec3(0.035, 0.075, 0.085), vec3(0.32, 0.12, 0.032), index / 9.0);
		result = over(result, vec4(chunk, mask));
	}
	// A slight value reduction keeps the landmark behind combat without washing it out.
	COLOR = vec4(result.rgb * 0.92, result.a);
}
