shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.5,0.9,0.8,1.0);
uniform float strength = 0.0;
uniform float element = 0.0;
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float r = length(p);
	float a = atan(p.y,p.x)+TIME*(0.55+element*0.1);
	float arc = (1.0-smoothstep(0.015,0.045,abs(r-0.75)))*smoothstep(-0.35,-0.1,sin(a*3.0));
	float spokes = (1.0-smoothstep(0.04,0.12,abs(sin(a*(3.0+element)))))*smoothstep(0.45,0.58,r)*(1.0-smoothstep(0.78,0.85,r));
	float inner = (1.0-smoothstep(0.012,0.035,abs(r-0.48)))*0.45;
	ALBEDO = tint.rgb;
	ALPHA = clamp((arc+spokes+inner)*strength,0.0,0.75);
}
