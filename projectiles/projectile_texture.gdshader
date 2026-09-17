shader_type canvas_item;
render_mode blend_mix, unshaded;
uniform vec2 layer_size = vec2(6.0, 8.0);
uniform vec4 layer_color : source_color = vec4(1.0);
uniform float blur_radius = 0.0;
uniform float intensity = 1.0;
varying vec4 instance_tint;
void vertex() {
    VERTEX *= layer_size * 0.5;
    instance_tint = COLOR * INSTANCE_CUSTOM * layer_color;
}
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (blur_radius > 0.0) {
        vec2 o = TEXTURE_PIXEL_SIZE * blur_radius;
        float a = tex.a * 0.20;
        a += texture(TEXTURE, UV + vec2(o.x, 0.0)).a * 0.12;
        a += texture(TEXTURE, UV - vec2(o.x, 0.0)).a * 0.12;
        a += texture(TEXTURE, UV + vec2(0.0, o.y)).a * 0.12;
        a += texture(TEXTURE, UV - vec2(0.0, o.y)).a * 0.12;
        a += texture(TEXTURE, UV + o).a * 0.08;
        a += texture(TEXTURE, UV - o).a * 0.08;
        a += texture(TEXTURE, UV + vec2(o.x, -o.y)).a * 0.08;
        a += texture(TEXTURE, UV + vec2(-o.x, o.y)).a * 0.08;
        tex = vec4(vec3(intensity), a);
    }
    COLOR = tex * instance_tint;
}
