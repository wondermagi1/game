shader_type canvas_item;
render_mode unshaded;
uniform float phase = 0.0;
uniform float strength = 0.1;
void fragment() {
	vec4 base = COLOR;
	float band = 1.0 - smoothstep(0.015, 0.12, abs(UV.x + UV.y * 0.4 - mod(phase * 0.32, 1.9)));
	COLOR = vec4(base.rgb + vec3(1.0, 0.86, 0.61) * band * strength * base.a, base.a);
}
