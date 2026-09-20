shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	float h = 1.0 - UV.y;
	float n = noise(vec2(UV.x * 5.0, h * 5.0 - TIME * 3.0));
	float n2 = noise(vec2(UV.x * 11.0, h * 9.0 - TIME * 5.0));
	float width = (1.0 - h) * 0.34 + 0.01;
	float center = 0.5 + sin(h * 7.0 - TIME * 3.5) * h * 0.10;
	float body = 1.0 - smoothstep(width * 0.25, width, abs(UV.x - center) + (n - 0.5) * 0.11);
	float alpha = body * smoothstep(0.0, 0.14, h) * (1.0 - smoothstep(0.62, 1.0, h + n2 * 0.14));
	vec3 color = mix(vec3(1.0, 0.10, 0.012), vec3(1.0, 0.64, 0.16), body * (1.0 - h));
	ALBEDO = color * 2.4;
	ALPHA = alpha * 0.88;
}
