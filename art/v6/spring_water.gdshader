shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float strength = 1.0;
void fragment() {
	vec2 q=(UV-vec2(0.5))*2.0;
	float edge=length(q);
	float waves=sin(UV.x*85.0+sin(UV.y*34.0+clock)*2.0+clock*1.2)*sin(UV.y*68.0-clock*.7);
	float caustic=pow(max(0.0,waves),5.0)*.16*strength;
	vec3 deep=mix(vec3(.15,.36,.38),vec3(.34,.62,.59),UV.y);
	float ring=pow(max(0.0,sin(edge*45.0-clock*1.5)),14.0)*.05*strength;
	COLOR=vec4(deep+caustic+ring,smoothstep(1.0,.94,edge)*.9);
}
