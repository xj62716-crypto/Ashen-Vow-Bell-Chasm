shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0,0.65,0.25,1.0);
uniform float strength = 1.0;
uniform float ring = 0.0;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float glow = pow(max(0.0,1.0-r),3.0);
	float halo = exp(-pow((r-0.70)*26.0,2.0)) * (1.0-smoothstep(0.9,1.0,r));
	ALBEDO = tint.rgb;
	ALPHA = mix(glow,halo,ring) * tint.a * strength;
}
