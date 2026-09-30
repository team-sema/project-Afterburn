shader_type canvas_item;
render_mode unshaded;

// Plasma singularity lens (plasma-bomb.md 특이점). Drawn on a quad whose
// inscribed circle is the lens; it re-reads the screen under it, twisting and
// bending it toward the core. Both warps are bell curves centred on the core
// that are gone well before the rim: a warp that only reaches zero at the rim
// shears hard in the outer band, which reads as a cut edge.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// 0 = no effect, 1 = full lens. Swallow kicks may push it slightly above 1.
uniform float strength = 0.0;
// Event horizon radius as a fraction of the lens radius.
uniform float horizon = 0.08;
// Outward look-up at the core, as a fraction of the lens radius. Kept below
// the point where the looked-up radius would stop growing with r (rings).
uniform float lens = 0.15;
// Twist at the core, in radians.
uniform float swirl = 1.3;
// Widths of the twist and look-up bells, as fractions of the lens radius.
uniform float swirl_width = 0.35;
uniform float lens_width = 0.3;
// Accretion streak phase (advanced on the gameplay clock).
uniform float spin = 0.0;
uniform vec4 ring_color : source_color = vec4(0.72, 0.38, 1.0, 1.0);
// Collapse wave: radius as a fraction of the lens radius, and its strength.
uniform float shock_radius = 0.0;
uniform float shock_strength = 0.0;

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d);
	if (r >= 1.0) {
		discard;
	}
	vec2 dir = r > 0.0001 ? d / r : vec2(0.0);
	float h = max(horizon, 0.001);
	// Guarantees exact identity at the rim; the bells are ~0 there already.
	float edge = 1.0 - smoothstep(0.75, 1.0, r);
	float core = exp(-pow(r / swirl_width, 2.0)) * edge;

	// Twist, strongest at the core.
	float angle = swirl * strength * core;
	vec2 twisted = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * d;
	// Light bent around the hole: show what lies further out.
	float push = lens * strength * exp(-pow(r / lens_width, 2.0)) * edge;
	vec2 source = twisted + (r > 0.0001 ? twisted / r : vec2(0.0)) * push;
	// Collapse wave shoves the screen outward in a thin band.
	float band = exp(-pow((r - shock_radius) / 0.09, 2.0)) * step(0.001, shock_strength);
	source += dir * band * shock_strength * 0.14;

	// Lens units -> screen UV (the quad is unrotated, so this is a per-axis scale).
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 offset = (source - d) * 0.5 * span;
	float split = 0.015 * strength * core;
	vec3 color;
	color.r = texture(screen_tex, SCREEN_UV + offset * (1.0 + split)).r;
	color.g = texture(screen_tex, SCREEN_UV + offset).g;
	color.b = texture(screen_tex, SCREEN_UV + offset * (1.0 - split)).b;

	float glow_strength = clamp(strength, 0.0, 1.0);
	float hole = 1.0 - smoothstep(h * 0.75, h * 1.1, r);
	color = mix(color, vec3(0.0), hole * glow_strength);
	float ring = exp(-pow((r - h * 1.45) / (h * 0.35), 2.0));
	float streak = 0.5 + 0.5 * sin(atan(d.y, d.x) * 3.0 + r * 18.0 - spin);
	float disk = exp(-pow((r - h * 2.6) / (h * 1.3), 2.0)) * streak;
	color += ring_color.rgb * (ring * 1.3 + disk * 0.3) * glow_strength;
	color += ring_color.rgb * band * shock_strength * 1.1;
	COLOR = vec4(color, 1.0);
}
