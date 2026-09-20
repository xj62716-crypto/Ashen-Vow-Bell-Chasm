shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color=vec4(.18,.65,.65,1.0);
uniform float warning=0.0;
void fragment(){
	vec2 grid=abs(fract(UV*vec2(7.0,5.0))-.5);
	float seam=smoothstep(.43,.49,max(grid.x,grid.y));
	float pulse=.5+.5*sin(TIME*3.0+UV.y*12.0);
	ALBEDO=tint.rgb*.22+vec3(.025,.045,.05);
	ROUGHNESS=.48;
	METALLIC=.3;
	EMISSION=mix(tint.rgb,vec3(1.0,.3,.08),warning)*seam*(.6+pulse*.6);
}
