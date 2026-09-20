shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	// Taper both ends of each sampled blade segment to avoid a solid triangle.
	float taper = smoothstep(0.0,0.12,UV.x)*(1.0-smoothstep(0.93,1.0,UV.x));
	float ridge = exp(-pow((UV.x-0.85)*20.0,2.0));
	float filament = 0.65+0.35*sin(UV.x*90.0+UV.y*7.0);
	ALBEDO = mix(COLOR.rgb,vec3(1.0),ridge*0.6);
	EMISSION = COLOR.rgb*ridge*0.8;
	ALPHA = COLOR.a*taper*(0.40*filament+ridge*0.60);
}
