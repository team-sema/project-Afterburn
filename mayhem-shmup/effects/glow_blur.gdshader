shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float blur_radius : hint_range(0.0, 64.0) = 4.0;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 offset = TEXTURE_PIXEL_SIZE * blur_radius;
	float alpha = texture(TEXTURE, UV).a * 0.20;
	alpha += texture(TEXTURE, UV + vec2(offset.x, 0.0)).a * 0.12;
	alpha += texture(TEXTURE, UV - vec2(offset.x, 0.0)).a * 0.12;
	alpha += texture(TEXTURE, UV + vec2(0.0, offset.y)).a * 0.12;
	alpha += texture(TEXTURE, UV - vec2(0.0, offset.y)).a * 0.12;
	alpha += texture(TEXTURE, UV + offset).a * 0.08;
	alpha += texture(TEXTURE, UV - offset).a * 0.08;
	alpha += texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a * 0.08;
	alpha += texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a * 0.08;
	COLOR = vec4(tint.rgb * intensity, alpha * tint.a);
}
