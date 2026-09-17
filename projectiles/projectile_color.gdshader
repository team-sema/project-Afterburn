shader_type canvas_item;
render_mode unshaded;
void vertex() {
	// UV encodes layer lightening and whether tint alpha applies. Laser UV is -1.
	if (UV.x >= 0.0) {
		COLOR.rgb *= mix(INSTANCE_CUSTOM.rgb, vec3(1.0), UV.x);
		COLOR.a *= mix(1.0, INSTANCE_CUSTOM.a, UV.y);
	}
}
void fragment() {
	// Geometry is untextured; UV carries metadata, not texture coordinates.
	COLOR = COLOR;
}
