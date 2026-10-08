shader_type canvas_item;
uniform float phase = 0.0;
uniform float wind_strength = 1.0;
void vertex() {
	// Tiny crown-only sway; the roots and trunk contact remain stationary.
	VERTEX.x += sin(TIME * 0.85 + phase + UV.y * 2.0) * pow(1.0-UV.y, 2.0) * 1.4 * wind_strength;
}
