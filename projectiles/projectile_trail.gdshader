shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float clock_time = 0.0;
uniform vec2 sizes = vec2(0.8, 0.1);
uniform vec4 start_color : source_color = vec4(1.0);
uniform vec4 end_color : source_color = vec4(0.0);
void vertex() {
    float age = max(0.0, clock_time - INSTANCE_CUSTOM.z);
    float weight = clamp(age / INSTANCE_CUSTOM.w, 0.0, 1.0);
    VERTEX = VERTEX * mix(sizes.x, sizes.y, weight) + INSTANCE_CUSTOM.xy * age;
    COLOR *= mix(start_color, end_color, weight);
}
