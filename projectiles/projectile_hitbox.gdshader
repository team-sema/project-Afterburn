shader_type canvas_item;
render_mode unshaded;
varying float aspect;
varying float rectangle;
void vertex() {
	aspect = INSTANCE_CUSTOM.r;
	rectangle = INSTANCE_CUSTOM.g;
}
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, aspect);
	float distance_to_edge = length(vec2(p.x, max(abs(p.y) - (aspect - 1.0), 0.0))) - 1.0;
	if (rectangle > 0.5) {
		vec2 d = abs(p) - vec2(1.0, aspect);
		distance_to_edge = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	}
	float coverage = 1.0 - smoothstep(-fwidth(distance_to_edge), 0.0, distance_to_edge);
	COLOR = vec4(0.1, 1.0, 0.65, 0.65 * coverage);
}
