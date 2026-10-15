shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float anchor = UV.y * UV.y;
	VERTEX.z += sin(UV.y * 5.0 + TIME * 1.7) * .16 * anchor;
	VERTEX.x += sin(UV.y * 3.0 + TIME * 1.1) * .045 * anchor;
}
void fragment() {
	float border = step(UV.x,.065) + step(.935,UV.x) + step(.955,UV.y);
	float crest = 1.0 - step(.035, abs(abs(UV.x-.5) + abs(UV.y-.32)*.7 - .16));
	ALBEDO = mix(vec3(.24,.43,.5),vec3(.83,.73,.5),clamp(border+crest,0.0,1.0));
	ROUGHNESS = 1.0;
}
