shader_type canvas_item;
render_mode blend_add, unshaded;

// 年龄、特效密度、允许动态效果、技能亮度；不使用全局 TIME 或战斗随机数。
uniform vec4 glow_params = vec4(0.0, 1.0, 1.0, 1.0);

float soft_spot(vec2 p, vec2 spread) {
	vec2 q = p / spread;
	return exp(-dot(q, q) * 2.8);
}

void fragment() {
	// 单位是实体弹体直径。四边形覆盖 [-3,1.4] × [-1.4,1.4]。
	vec2 p = UV * vec2(4.4, 2.8) - vec2(3.0, 1.4);
	float age = glow_params.x;
	float quality = glow_params.y;
	float motion = glow_params.z;
	float power = glow_params.w * mix(0.7, 1.0, quality);
	float pulse = 1.0 + 0.07 * sin(age * 7.0) * motion;
	float radius = length(p);

	// 琥珀外晕、淡金边光；削弱圆心亮度，保留黑铁与金色刻纹。
	float halo = soft_spot(p, vec2(1.08)) * smoothstep(0.22, 0.56, radius);
	float rim_distance = (radius - 0.47) / 0.16;
	float rim = exp(-rim_distance * rim_distance);
	float rear = 1.0 - smoothstep(-0.60, -0.25, p.x);
	float tail = soft_spot(p + vec2(0.88, 0.0), vec2(1.20, 0.19)) * rear;
	float core = soft_spot(p + vec2(0.64, 0.0), vec2(0.55, 0.07)) * rear;
	float highlight = soft_spot(p - vec2(0.14, -0.18), vec2(0.16, 0.11));
	vec3 light = vec3(1.0, 0.48, 0.12) * (halo * 0.28 + tail * 0.48);
	light += vec3(1.0, 0.78, 0.35) * rim * 0.16;
	light += vec3(1.0, 0.92, 0.67) * (core * 0.30 + highlight * 0.32);
	light *= pulse;

	// 最多两个微小星屑，低档关闭，中档一个。柔光形状没有硬直线边缘。
	for (int i = 0; i < 2; i++) {
		float index = float(i);
		float enabled = step(0.5 + index * 0.3, quality);
		float phase = age * 9.0 - index * 2.4;
		vec2 center = vec2(-1.15 - index * 0.74, mix(-0.27, 0.24, index));
		center.y += sin(phase * 0.7) * 0.05 * motion;
		vec2 star = p - center;
		float glint = soft_spot(star, vec2(0.13, 0.035));
		glint += soft_spot(star, vec2(0.035, 0.15));
		glint += soft_spot(star, vec2(0.17)) * 0.22;
		float twinkle = mix(0.52, 0.35 + 0.45 * (0.5 + 0.5 * sin(phase)), motion);
		light += vec3(1.0, 0.86, 0.52) * glint * twinkle * enabled * 0.60;
	}

	// 平滑收边，保证放大与旋转时也不会显出方形边界。
	vec2 edge = smoothstep(vec2(0.0), vec2(0.06), UV) * (vec2(1.0) - smoothstep(vec2(0.94), vec2(1.0), UV));
	COLOR = vec4(light * power, edge.x * edge.y);
}
