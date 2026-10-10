shader_type canvas_item;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float scan : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D lamp_mask : filter_linear, repeat_disable;
uniform vec4 lamp_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float lamp_blend : hint_range(0.0, 1.0) = 0.0;
uniform float lamp_brightness : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = texture(lamp_mask, UV).r;
	// Skip arithmetic entirely outside the mask and in the original amber state.
	if (mask > 0.0 && (lamp_blend > 0.0 || lamp_brightness != 1.0)) {
		// Preserve original highlights and shading while changing lamp hue.
		float low = min(tex.r, min(tex.g, tex.b));
		float high = max(tex.r, max(tex.g, tex.b));
		vec3 tinted = mix(vec3(low), vec3(high), lamp_color.rgb);
		vec3 lamp = mix(tex.rgb, tinted, lamp_blend) * lamp_brightness;
		tex.rgb = mix(tex.rgb, lamp, mask);
	}
	float light = mix(0.24, 1.0, power);
	float sweep = (scan < 0.99) ? max(0.0, 1.0 - abs(UV.y - scan) * 65.0) * 0.15 : 0.0;
	COLOR = vec4(tex.rgb * light + vec3(0.08, 0.55, 0.65) * sweep * tex.a, mix(tex.a, 1.0, step(0.9, tex.a)));
}
