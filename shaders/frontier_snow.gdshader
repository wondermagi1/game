shader_type spatial;
// Quiet, broad cloud shadows preserve the uncluttered combat surface.
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float cloud = sin(p.x * .071 + TIME * .018) * sin(p.y * .052 + TIME * .013);
	float grain = fract(sin(dot(floor(p * 32.0), vec2(12.9898,78.233))) * 43758.5453);
	ALBEDO = COLOR.rgb * (.965 + cloud * .032 + grain * .025);
	ROUGHNESS = .9;
	SPECULAR = .25;
}
