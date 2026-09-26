shader_type canvas_item;
render_mode blend_add, unshaded;

// Player laser body drawn on the laser GlowLine sprite. UV.x spans the full
// visual width; UV.y runs from the muzzle (0) to the playfield top (1).
// The script feeds beam_length and beam_time every physics frame so the
// energy streaks keep a constant pixel spacing and freeze on tree pause.

uniform vec4 glow_color : source_color = vec4(0.1, 0.75, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.85, 0.98, 1.0, 1.0);
uniform float beam_length = 240.0;
uniform float beam_time = 0.0;
// Radii are fractions of the half width (1.0 = sprite edge).
uniform float tight_radius = 0.14;
uniform float tight_strength = 0.6;
uniform float wide_radius = 0.55;
uniform float wide_strength = 0.12;
uniform float streak_spacing = 26.0;
uniform float streak_length = 10.0;
uniform float streak_speed = 420.0;
uniform float streak_strength = 0.7;
uniform float flicker_hz = 23.0;
uniform float flicker_amount = 0.08;
uniform float tail_fade = 10.0;

varying vec4 vertex_tint;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	// Preserve modulation (pulse alpha, overcharge tint) before fragment COLOR
	// is multiplied by the placeholder texture.
	vertex_tint = COLOR;
}

void fragment() {
	float wobble = 1.0 + flicker_amount * (
		0.6 * sin(beam_time * TAU * flicker_hz)
		+ 0.4 * sin(beam_time * TAU * flicker_hz * 1.61 + 1.3)
	);
	float d = abs(UV.x - 0.5) * 2.0 / wobble;
	float tight = exp(-pow(d / tight_radius, 2.0));
	float wide = exp(-pow(d / wide_radius, 2.0));

	float dist = UV.y * beam_length;
	float s = dist - beam_time * streak_speed;
	float cell = floor(s / streak_spacing);
	float local_s = s - cell * streak_spacing;
	float dash = smoothstep(0.0, 2.0, local_s) * (1.0 - smoothstep(streak_length * 0.3, streak_length, local_s));
	float cell_rand = hash(cell);
	dash *= step(0.25, cell_rand) * mix(0.45, 1.0, cell_rand);
	float streak = dash * exp(-pow(d / (tight_radius * 2.2), 2.0));

	float tail = smoothstep(0.0, tail_fade, beam_length - dist);
	float intensity = (wide * wide_strength + tight * tight_strength + streak * streak_strength) * tail;
	vec3 color = mix(glow_color.rgb, hot_color.rgb, clamp(tight * 0.8 + streak * 0.6, 0.0, 1.0));
	COLOR = vec4(color, clamp(intensity, 0.0, 1.0)) * vertex_tint;
}
