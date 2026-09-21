shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	// Taper both ends of each sampled blade segment to avoid a solid triangle.
	float taper = smoothstep(0.0,0.12,UV.x)*(1.0-smoothstep(0.93,1.0,UV.x));
	// The blade trail is a ribbon around the whole cutting edge. A tip-only
	// ridge reads like a glowing cursor and hides the actual swing arc.
	float ridge = exp(-pow((UV.x-0.50)*4.0,2.0));
	float filament = 0.72+0.28*sin(UV.x*90.0+UV.y*7.0);
	ALBEDO = mix(COLOR.rgb,vec3(1.0),ridge*0.28);
	EMISSION = COLOR.rgb*(0.85+ridge*1.25);
	ALPHA = COLOR.a*taper*(0.82*filament+ridge*0.55);
}
