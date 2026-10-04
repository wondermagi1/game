shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 12.0) = 5.0;

void fragment() {
	vec2 delta = UV - vec2(0.5);
	float distance_from_center = length(delta) * 2.0;
	float radius = 0.18 + progress * 0.88;
	float ring = exp(-pow((distance_from_center - radius) * 18.0, 2.0));
	vec2 direction = normalize(delta + vec2(0.0001));
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
	vec2 offset = direction * ring * strength * (1.0 - progress) * pixel_size;
	vec4 scene = texture(screen_texture, SCREEN_UV + offset);
	float mask = texture(TEXTURE, UV).a * ring * (1.0 - progress);
	COLOR = vec4(scene.rgb, mask * 0.82);
}
