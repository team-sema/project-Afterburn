shader_type canvas_item;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float scan : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float light = mix(0.24, 1.0, power);
	float sweep = (scan < 0.99) ? max(0.0, 1.0 - abs(UV.y - scan) * 65.0) * 0.15 : 0.0;
	COLOR = vec4(tex.rgb * light + vec3(0.08, 0.55, 0.65) * sweep * tex.a, mix(tex.a, 1.0, step(0.9, tex.a)));
}
