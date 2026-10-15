shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	float vein = abs(sin(p.x * 1.7 + sin(p.y * .6) * 2.0));
	float frost = smoothstep(.94, 1.0, vein) * .22;
	float ripple = sin(p.y * 1.3 + p.x * .7 - TIME * .35) * .018;
	ALBEDO = mix(vec3(.20,.39,.46), vec3(.59,.76,.78), frost + .15) + ripple;
	ROUGHNESS = .29 + frost;
	METALLIC = .12;
	SPECULAR = .5;
}
