shader_type spatial;
render_mode cull_disabled;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	VERTEX.x += sin(TIME * 1.4 + world.x * .9 + world.z * .6) * max(0.0,VERTEX.y) * .17;
}
void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = .95; }
