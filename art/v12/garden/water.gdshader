shader_type canvas_item;
uniform float motion = 1.0;
void fragment() {
	vec2 drift = vec2(sin(UV.y*170.0+TIME*.65), cos(UV.x*135.0+TIME*.45))*.0007*motion;
	vec4 base = texture(TEXTURE,UV+drift);
	float light = pow(max(0.0,sin(UV.x*160.0+UV.y*110.0+TIME*.9*motion)),16.0);
	COLOR = vec4(base.rgb + vec3(.022,.033,.027)*light*motion,base.a);
}
